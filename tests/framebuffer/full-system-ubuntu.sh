#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)

UBUNTU_SUITE=${UBUNTU_SUITE:-noble}
UBUNTU_MIRROR=${UBUNTU_MIRROR:-http://ports.ubuntu.com/ubuntu-ports}
QEMU_SYSTEM_ARM=${QEMU_SYSTEM_ARM:-qemu-system-arm}
ARM_CLANG=${ARM_CLANG:-clang}
ARM_EXEC_TARGET=${ARM_EXEC_TARGET:-armv7a-linux-gnueabihf}

work=${WORK_DIR:-"$repo_root/build/full-system-arm-red"}
rootfs="$work/rootfs"
disk="$work/ubuntu-armhf.raw"
serial="$work/serial.log"
monitor="${TMPDIR:-/tmp}/idric-arm-red-$$.sock"
screen="$work/red.ppm"
program="$work/linux-fbdev-red.armv7-thumb2"
kernel="$work/vmlinuz"
initrd="$work/initrd.img"
dtb="$work/vexpress-v2p-ca9.dtb"

rm -rf "$work"
mkdir -p "$work"

for command in debootstrap mkfs.ext4 python3 "$QEMU_SYSTEM_ARM" "$ARM_CLANG"; do
    command -v "$command" >/dev/null 2>&1 || {
        printf 'FAIL: required command not found: %s\n' "$command" >&2
        exit 1
    }
done

qemu_arm_static=$(command -v qemu-arm-static 2>/dev/null || command -v qemu-armhf-static 2>/dev/null || true)
[ -n "$qemu_arm_static" ] || {
    printf '%s\n' 'FAIL: qemu-arm-static or qemu-armhf-static is required for Ubuntu armhf bootstrap' >&2
    exit 1
}

"$ARM_CLANG" --target="$ARM_EXEC_TARGET" -fuse-ld=lld -nostdlib -static \
    -march=armv7-a -mthumb \
    -Wl,-e,_start -Wl,--no-dynamic-linker \
    "$script_dir/linux_fbdev_red.S" -o "$program"

sudo debootstrap \
    --foreign \
    --arch=armhf \
    --variant=minbase \
    --components=main,universe \
    --include=linux-image-generic,kmod,busybox-static,initramfs-tools \
    "$UBUNTU_SUITE" "$rootfs" "$UBUNTU_MIRROR"

sudo install -m 0755 "$qemu_arm_static" "$rootfs/usr/bin/$(basename "$qemu_arm_static")"

if [ -d /proc/sys/fs/binfmt_misc ]; then
    sudo update-binfmts --enable qemu-arm 2>/dev/null || true
fi

if ! sudo chroot "$rootfs" /debootstrap/debootstrap --second-stage; then
    printf '%s\n' 'FAIL: Ubuntu armhf second-stage bootstrap did not execute; qemu-arm binfmt must be active' >&2
    exit 1
fi

sudo install -m 0755 "$program" "$rootfs/usr/local/bin/screen-red"

# QEMU vexpress-a9 exposes its only block storage through the PL181 SD
# controller. Generic distro initramfs generation does not necessarily include
# that board-specific host driver when built off-machine. Force the host, MMC
# core, and block layer into the guest initramfs before booting it.
kernel_release=$(sudo sh -c "ls -1 '$rootfs/lib/modules' | sort | tail -n 1")
[ -n "$kernel_release" ] || {
    printf '%s\n' 'FAIL: Ubuntu armhf rootfs has no installed kernel modules' >&2
    exit 1
}

modules_file="$rootfs/etc/initramfs-tools/modules"
for module in armmmci mmc_core mmc_block; do
    if sudo find "$rootfs/lib/modules/$kernel_release" -type f -name "$module.ko*" -print -quit | grep -q .; then
        printf '%s\n' "$module" | sudo tee -a "$modules_file" >/dev/null
    elif sudo grep -Eq "^CONFIG_$(printf '%s' "$module" | tr '[:lower:]' '[:upper:]')=y$" "$rootfs/boot/config-$kernel_release" 2>/dev/null; then
        :
    elif [ "$module" = armmmci ] && sudo grep -q '^CONFIG_MMC_ARMMMCI=y$' "$rootfs/boot/config-$kernel_release" 2>/dev/null; then
        :
    elif [ "$module" = mmc_core ] && sudo grep -q '^CONFIG_MMC=y$' "$rootfs/boot/config-$kernel_release" 2>/dev/null; then
        :
    elif [ "$module" = mmc_block ] && sudo grep -q '^CONFIG_MMC_BLOCK=y$' "$rootfs/boot/config-$kernel_release" 2>/dev/null; then
        :
    else
        printf 'FAIL: guest kernel lacks required vexpress storage module or built-in support: %s\n' "$module" >&2
        exit 1
    fi
done

sudo chroot "$rootfs" /usr/sbin/update-initramfs -u -k "$kernel_release"

sudo tee "$rootfs/usr/local/sbin/device-action-init" >/dev/null <<'GUEST_INIT'
#!/bin/busybox sh

exec </dev/console >/dev/console 2>&1

/bin/busybox mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
/bin/busybox mount -t proc proc /proc 2>/dev/null || true
/bin/busybox mount -t sysfs sysfs /sys 2>/dev/null || true

for module in pl111 pl111_drm amba-clcd drm_kms_helper; do
    /sbin/modprobe "$module" 2>/dev/null || true
done

i=0
while [ ! -e /dev/fb0 ] && [ "$i" -lt 20 ]; do
    /bin/busybox sleep 1
    i=$((i + 1))
done

if [ ! -e /dev/fb0 ]; then
    echo 'FBDEV_PRESENT=0'
    echo 'PROGRAM_STATUS=125'
    /bin/busybox poweroff -f
    /bin/busybox sleep 5
    exit 125
fi

echo 'FBDEV_PRESENT=1'
echo 'SCREEN_RED_RUNNING=1'
/usr/local/bin/screen-red
status=$?
echo "PROGRAM_STATUS=$status"
/bin/busybox sync
/bin/busybox poweroff -f
/bin/busybox sleep 5
exit "$status"
GUEST_INIT
sudo chmod 0755 "$rootfs/usr/local/sbin/device-action-init"

kernel_source=$(sudo find "$rootfs/boot" -maxdepth 1 -type f -name 'vmlinuz-*' | sort | tail -n 1)
initrd_source=$(sudo find "$rootfs/boot" -maxdepth 1 -type f -name 'initrd.img-*' | sort | tail -n 1)
dtb_source=$(sudo find "$rootfs" -type f -name 'vexpress-v2p-ca9.dtb' | sort | head -n 1)

[ -n "$kernel_source" ] && [ -n "$initrd_source" ] && [ -n "$dtb_source" ] || {
    printf '%s\n' 'FAIL: Ubuntu armhf rootfs did not provide the generic kernel/initrd/vexpress-a9 DTB tuple' >&2
    exit 1
}

sudo cp "$kernel_source" "$kernel"
sudo cp "$initrd_source" "$initrd"
sudo cp "$dtb_source" "$dtb"
sudo chown "$(id -u):$(id -g)" "$kernel" "$initrd" "$dtb"

truncate -s 1G "$disk"
sudo mkfs.ext4 -q -d "$rootfs" "$disk"
sudo chown "$(id -u):$(id -g)" "$disk"

rm -f "$serial" "$monitor" "$screen"

"$QEMU_SYSTEM_ARM" \
    -machine vexpress-a9 \
    -cpu cortex-a9 \
    -m 512M \
    -kernel "$kernel" \
    -dtb "$dtb" \
    -initrd "$initrd" \
    -append 'console=ttyAMA0,115200 root=/dev/mmcblk0 rw rootwait init=/usr/local/sbin/device-action-init panic=-1' \
    -drive "file=$disk,format=raw,if=sd" \
    -display none \
    -serial "file:$serial" \
    -monitor "unix:$monitor,server=on,wait=off" \
    -no-reboot &
qemu_pid=$!

cleanup_qemu() {
    if kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
    fi
    rm -f "$monitor"
}
trap cleanup_qemu EXIT HUP INT TERM

i=0
while [ "$i" -lt 180 ]; do
    if [ -f "$serial" ] && grep -q 'SCREEN_RED_RUNNING=1' "$serial"; then
        break
    fi
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        break
    fi
    sleep 1
    i=$((i + 1))
done

if ! [ -f "$serial" ] || ! grep -q 'SCREEN_RED_RUNNING=1' "$serial"; then
    cat "$serial" 2>/dev/null || true
    printf '%s\n' 'FAIL: ARM guest never reached red-screen execution' >&2
    exit 1
fi

sleep 1

python3 - "$monitor" "$screen" <<'PY'
import socket
import sys
import time

monitor, output = sys.argv[1:]
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
for _ in range(50):
    try:
        sock.connect(monitor)
        break
    except (FileNotFoundError, ConnectionRefusedError):
        time.sleep(0.1)
else:
    raise SystemExit("FAIL: QEMU monitor socket was unavailable")

sock.settimeout(2)
try:
    sock.recv(65536)
except TimeoutError:
    pass
sock.sendall(("screendump " + output + "\n").encode())
time.sleep(0.5)
try:
    sock.recv(65536)
except TimeoutError:
    pass
sock.close()
PY

i=0
while kill -0 "$qemu_pid" 2>/dev/null && [ "$i" -lt 30 ]; do
    sleep 1
    i=$((i + 1))
done
cleanup_qemu
trap - EXIT HUP INT TERM

cat "$serial"

grep -q 'FBDEV_PRESENT=1' "$serial"
grep -q 'PROGRAM_STATUS=0' "$serial"

python3 - "$screen" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
data = path.read_bytes()
if not data.startswith(b"P6"):
    raise SystemExit("FAIL: QEMU screendump is not binary PPM")

pos = 2
tokens = []
while len(tokens) < 3:
    while pos < len(data) and data[pos] in b" \t\r\n":
        pos += 1
    if pos < len(data) and data[pos] == ord("#"):
        pos = data.index(b"\n", pos) + 1
        continue
    end = pos
    while end < len(data) and data[end] not in b" \t\r\n":
        end += 1
    tokens.append(data[pos:end])
    pos = end

width, height, maximum = map(int, tokens)
while pos < len(data) and data[pos] in b" \t\r\n":
    pos += 1
pixels = data[pos:]
if maximum != 255 or len(pixels) != width * height * 3:
    raise SystemExit("FAIL: unexpected PPM geometry or sample depth")

red = 0
count = width * height
for i in range(0, len(pixels), 3):
    r, g, b = pixels[i:i + 3]
    if r >= 224 and g <= 32 and b <= 32:
        red += 1

ratio = red / count
print(f"presented_red_pixels={red}/{count} ({ratio:.6f})")
if ratio < 0.98:
    raise SystemExit("FAIL: captured ARM guest display is not overwhelmingly red")
PY

printf '%s\n' \
    'PASS: native ARMv7/Thumb-2 ELF executed inside a full-system Ubuntu armhf guest' \
    'PASS: guest used /dev/fb0 and returned status 0' \
    'PASS: QEMU presented-output capture is overwhelmingly red'
