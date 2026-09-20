#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

mkdir -p "$work/src/Backend/DEX" "$work/.github/workflows"
cat >"$work/backend.ipkg" <<'PACKAGE'
package idric_dex
executable = idric-dex
PACKAGE
cat >"$work/wegert-dex.ipkg" <<'PACKAGE'
package wegert_dex
modules = Backend.DEX.EncodeNativeActivity
PACKAGE
cat >"$work/Makefile" <<'MAKE'
all:
	@:
MAKE
cat >"$work/src/Backend/DEX/Main.idr" <<'IDRIC'
module Backend.DEX.Main
import Backend.DEX.Codegen
IDRIC
cat >"$work/.github/workflows/dex-verify.yml" <<'WORKFLOW'
name: DEX
WORKFLOW

git -C "$work" init -q
git -C "$work" add .

DEX_REPO_ROOT="$work" "$repo_root/tests/dex/branch-separation.sh" >/dev/null

cat >"$work/src/Backend/DEX/Hidden.idr" <<'IDRIC'
module Backend.DEX.Hidden
import Backend.ARMThumb.Codegen
IDRIC
git -C "$work" add src/Backend/DEX/Hidden.idr

if DEX_REPO_ROOT="$work" "$repo_root/tests/dex/branch-separation.sh" \
    >"$work/out" 2>"$work/err"; then
  printf 'branch-separation self-test accepted an ARM/Thumb import\n' >&2
  exit 1
fi
grep -F 'DEX source imports an ARM/Thumb implementation layer' \
  "$work/err" >/dev/null

printf 'DEX branch separation self-test PASS\n'
