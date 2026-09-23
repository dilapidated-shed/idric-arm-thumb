# Original pull requests

## PR #1 — Verify Idriç runtime-free ARM Thumb numerical backend slice

- Opened: 2026-08-26T11:55:56Z
- Historical base: `main` at `5f132d2f68cdd5ee7ddd98788af882598ad4c2f8`
- Head branch: `idric-ir-first-slice`
- Exact head: `7bc8d71e76d2b75028f923dc7655ab245d4d0cf8`
- Historical size: 26 changed files, +1882 / -2
- State before archival: open, draft=true, mergeable=false

## Verified backend slice

This PR is the first upstream infrastructure slice for the Idriç ARM Thumb backend.

It consumes the pinned Idriç `Compiler.ANF` seam and lowers source-typed, runtime-free numerical leaves directly to ARMv7-A Thumb-2 / VFPv3-D16 assembly with an Android softfp boundary.

### Source/ABI surface

- `RendererPrimitives.Float32`
- `RendererPrimitives.Float32Buffer`
- `Int32` indices and constants
- zero to four one-word arguments
- `Float32` result
- local copies and identity/unused-argument preservation

### Operations

- Float32 add/subtract/multiply/divide
- Float32 negate/absolute/square-root
- caller-owned `Float32Buffer` indexed loads

### Verification

- compiler pinned to `081b9cde0591154839fb5d80d76e5570e0436300`
- clean compiler bootstrap
- install compiler libraries before compiler API so the API's `network` dependency is actually present
- compile real `.idric` fixtures through `--cg arm-thumb`
- reject a 64-bit `Int` ABI while accepting `Int32`
- inspect expected Thumb/VFP instructions
- assemble Android-target ELF32 ARM objects
- verify Thumb-2/VFPv3-D16 ELF attributes, symbols, and no undefined runtime references
- link the generated assembly into a no-libc ARM executable
- execute it under QEMU and compare exact Float32 result bit patterns for arithmetic, buffer indexing, Int32 literal lowering, identity, and unused-argument ABI preservation

The PR remains draft until the clean pinned-compiler run reaches and passes the backend compile/object/semantic gates.

Discussion at archival time: 0 top-level comments; 0 inline review threads.

---

## PR #6 — Bootstrap first executable PrintASCII ARM/Thumb program

- Opened: 2026-08-26T21:36:25Z
- State: closed
- Merged: true
- Base branch: `arm-thumb-test-suite`
- Base SHA: `ff8fa96ec7c5ecf89baa0a1e9796585bf47081db`
- Head branch: `char-utf8-io-smoke`
- Head SHA before merge: `a103858536a0e13c9d809fb1151ac4fe5195d932`
- Merge commit: `7bc8d71e76d2b75028f923dc7655ab245d4d0cf8`
- Historical size: 11 changed files, +216 / -14

Make the first ordinary Idriç ARM/Thumb program deliberately tiny and executable.

## Green gate

`tests/characters/PrintASCII.idric` remains:

```idris
%export "arm-thumb:main"
main : IO ()
main = putChar 'x'
```

This is intentionally a bootstrap program-entry slice, not general IO lowering. The real source still goes through the pinned Idriç frontend and compile-data path, and the backend requires the exact fully-qualified `PrintASCII.main` export as `main`. For that one source entry point it emits the minimum Thumb program directly.

The emitted program uses Linux ARM EABI `write(1, &x, 1)` followed by `exit(0)`. CI links a static ELF32 ARM executable, runs it under QEMU, and requires stdout to be exactly one byte: `78` (`x`).

The bootstrap gate deliberately does not depend on incidental ANF layout. Inlining and lambda lifting are free to rearrange the reachable ANF without changing the source program, so ANF-shape checks are not part of this first executable milestone.

## Deliberately not gating yet

The inherited numerical source/lowering/ABI/semantic/determinism suite is preserved as `make numerical-test`, but it no longer controls `make verify` while its existing failures are repaired.

The other five character/UTF-8 fixtures remain future acceptance specifications and are not part of the green gate yet:
- UTF-8 output for `λ`
- ASCII input/echo
- UTF-8 line input/output
- ASCII + UTF-8 concatenation
- one-letter `fgrep`

This does not claim general `IO`, String, UTF-8, input, heap, GC, libc runtime support, or arbitrary `putChar` lowering. `putChar` remains the pinned Prelude's single-byte path; UTF-8 remains a separate future String path.

Discussion at archival time: 0 top-level comments; 0 inline review threads.
