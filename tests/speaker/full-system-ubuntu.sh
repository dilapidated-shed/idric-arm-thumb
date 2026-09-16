#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)

UBUNTU_SUITE=${UBUNTU_SUITE:-noble}
UBUNTU_MIRROR=${UBUNTU_MIRROR:-http://ports.ubuntu.com/ubuntu-ports}
QEMU_SYSTEM_ARM=${QEMU_SYSTEM_ARM:-qemu-system-arm}
ARM_CLANG=${ARM_CLANG:-clang}
ARM_EXEC_TARGET=${ARM_EXEC_TARGET:-armv7a-linux-gnueabihf}

work=${WORK_DIR:-"$repo_root/build/full-system-arm-speaker"}
rootfs="$work/rootfs"
disk="$work/ubuntu-armhf.raw"
serial="$work/serial.log"
audio="$work/tone.wav"
program="$work/speaker-tone.armv7-thumb2"
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
    "$script_dir/speaker_tone.S" -o "$program"

sudo debootstrap \
    --foreign \
    --arch=armhf \
    --variant=minbase \
    --include=linux-image-generic,kmod,busybox \
    "$UBUNTU_SUITE" "$rootfs" "$UBUNTU_MIRROR"

sudo install -m 0755 "$qemu_arm_static" "$rootfs/usr/bin/$(basename "$qemu_arm_static")"

if [ -d /proc/sys/fs/binfmt_misc ]; then
    sudo update-binfmts --enable qemu-arm 2>/dev/null || true
fi

if ! sudo chroot "$rootfs" /debootstrap/debootstrap --second-stage; then
    printf '%s\n' 'FAIL: Ubuntu armhf second-stage bootstrap did not execute; qemu-arm binfmt must be active' >&2
    exit 1
fi

sudo install -m 0755 "$program" "$rootfs/usr/local/bin/speaker-tone"

kernel_release=$(sudo sh -c "ls -1 '$rootfs/lib/modules' | sort | tail -n 1")
[ -n "$kernel_release" ] || {
    printf '%s\n' 'FAIL: Ubuntu armhf rootfs has no installed kernel modules' >&2
    exit 1
}

modules_file="$rootfs/etc/initramfs-tools/modules"
require_boot_module() {
    module=$1
    config=$2
    if sudo find "$rootfs/lib/modules/$kernel_release" -type f -name "$module.ko*" -print -quit | grep -q .; then
        printf '%s\n' "$module" | sudo tee -a "$modules_file" >/dev/null
    elif sudo grep -q "^$config=y$" "$rootfs/boot/config-$kernel_release" 2>/dev/null; then
        :
    else
        printf 'FAIL: guest kernel lacks required boot storage support: %s / %s\n' "$module" "$config" >&2
        exit 1
    fi
}

# vexpress-a9 has no IDE/SCSI/PCI root-storage path: QEMU exposes a PL181 SD
# controller, so its host, MMC core, and block layer must be usable before the
# root filesystem can mount.
require_boot_module armmmci CONFIG_MMC_ARMMMCI
require_boot_module mmc_core CONFIG_MMC
require_boot_module mmc_block CONFIG_MMC_BLOCK
sudo chroot "$rootfs" /usr/sbin/update-initramfs -u -k "$kernel_release"

sudo tee "$rootfs/usr/local/sbin/device-action-init" >/dev/null <<'GUEST_INIT'
#!/bin/busybox sh

exec </dev/console >/dev/console 2>&1

/bin/busybox mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
/bin/busybox mount -t proc proc /proc 2>/dev/null || true
/bin/busybox mount -t sysfs sysfs /sys 2>/dev/null || true

/sbin/modprobe snd-aaci 2>/dev/null || /sbin/modprobe snd_aaci 2>/dev/null || true
/sbin/modprobe snd-pcm-oss 2>/dev/null || /sbin/modprobe snd_pcm_oss 2>/dev/null || true

i=0
while [ ! -e /dev/dsp ] && [ "$i" -lt 20 ]; do
    /bin/busybox sleep 1
    i=$((i + 1))
done

if [ ! -e /dev/dsp ]; then
    echo 'AUDIO_DEVICE_PRESENT=0'
    echo 'PROGRAM_STATUS=125'
    cat /proc/asound/cards 2>/dev/null || true
    /bin/busybox poweroff -f
    /bin/busybox sleep 5
    exit 125
fi

echo 'AUDIO_DEVICE_PRESENT=1'
echo 'SPEAKER_TONE_RUNNING=1'
/usr/local/bin/speaker-tone
status=$?
echo "PROGRAM_STATUS=$status"
cat /proc/asound/cards 2>/dev/null || true
/bin/busybox sleep 1
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

rm -f "$serial" "$audio"

"$QEMU_SYSTEM_ARM" \
    -machine vexpress-a9,audiodev=audio0 \
    -cpu cortex-a9 \
    -m 512M \
    -kernel "$kernel" \
    -dtb "$dtb" \
    -initrd "$initrd" \
    -append 'console=ttyAMA0,115200 root=/dev/mmcblk0 rw rootwait init=/usr/local/sbin/device-action-init panic=-1' \
    -drive "file=$disk,format=raw,if=sd" \
    -display none \
    -serial "file:$serial" \
    -audiodev "wav,id=audio0,path=$audio" \
    -no-reboot &
qemu_pid=$!

cleanup_qemu() {
    if kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
    fi
}
trap cleanup_qemu EXIT HUP INT TERM

i=0
while [ "$i" -lt 210 ]; do
    if [ -f "$serial" ] && grep -q 'PROGRAM_STATUS=' "$serial"; then
        break
    fi
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        break
    fi
    sleep 1
    i=$((i + 1))
done

if ! [ -f "$serial" ] || ! grep -q 'SPEAKER_TONE_RUNNING=1' "$serial"; then
    cat "$serial" 2>/dev/null || true
    printf '%s\n' 'FAIL: ARM guest never reached speaker-tone execution' >&2
    exit 1
fi

i=0
while kill -0 "$qemu_pid" 2>/dev/null && [ "$i" -lt 30 ]; do
    sleep 1
    i=$((i + 1))
done
cleanup_qemu
trap - EXIT HUP INT TERM

cat "$serial"
grep -q 'AUDIO_DEVICE_PRESENT=1' "$serial"
grep -q 'PROGRAM_STATUS=0' "$serial"

python3 - "$audio" <<'PY'
import array
import sys
import wave

path = sys.argv[1]
with wave.open(path, "rb") as wav:
    channels = wav.getnchannels()
    width = wav.getsampwidth()
    rate = wav.getframerate()
    frames = wav.readframes(wav.getnframes())

if width != 2:
    raise SystemExit(f"FAIL: expected QEMU WAV s16 samples, got width={width}")
if channels < 1:
    raise SystemExit("FAIL: WAV has no channels")

samples = array.array("h")
samples.frombytes(frames)
if sys.byteorder != "little":
    samples.byteswap()
mono = samples[0::channels]
if not mono:
    raise SystemExit("FAIL: WAV contains no samples")

peak = max(abs(value) for value in mono)
if peak < 2000:
    raise SystemExit(f"FAIL: captured audio peak is too small: {peak}")
threshold = max(1000, peak // 8)
active_indices = [i for i, value in enumerate(mono) if abs(value) >= threshold]
if not active_indices:
    raise SystemExit("FAIL: no active captured audio")

# Ignore isolated QEMU/device startup and shutdown clicks. Build clusters of
# threshold-crossing samples, allowing up to 20 ms between active samples, and
# analyze the cluster containing the most actual active samples.
max_gap = max(1, rate // 50)
clusters = []
start = previous = active_indices[0]
active_count = 1
for index in active_indices[1:]:
    if index - previous > max_gap:
        clusters.append((active_count, start, previous + 1))
        start = index
        active_count = 1
    else:
        active_count += 1
    previous = index
clusters.append((active_count, start, previous + 1))
active_count, start, stop = max(clusters)
active = mono[start:stop]
duration = len(active) / rate
if not 0.18 <= duration <= 0.40:
    raise SystemExit(f"FAIL: dominant tone duration {duration:.6f}s is outside expected range")

mean = sum(active) / len(active)
signs = [1 if value >= mean else -1 for value in active]
crossings = sum(a != b for a, b in zip(signs, signs[1:]))
frequency = crossings * rate / (2 * len(active))
print(f"captured_rate={rate} channels={channels} peak={peak}")
print(f"dominant_active_samples={active_count}")
print(f"dominant_duration_seconds={duration:.6f}")
print(f"estimated_frequency_hz={frequency:.3f}")
if not 350 <= frequency <= 450:
    raise SystemExit("FAIL: captured tone frequency is outside the 400 Hz fixture window")
PY

printf '%s\n' \
    'PASS: native ARMv7/Thumb-2 ELF executed through an Ubuntu armhf guest audio device' \
    'PASS: guest exposed /dev/dsp through the Linux audio stack' \
    'PASS: QEMU WAV capture contains the expected bounded ~400 Hz tone'
