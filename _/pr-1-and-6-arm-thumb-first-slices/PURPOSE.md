# Purpose

## PR #1

PR #1 established the first verified Idriç → ARMv7-A Thumb-2 numerical backend slice. The intended boundary was deliberately small and explicit:

- consume checked Idriç through the compiler ANF seam;
- represent `Float32`, `Float32Buffer`, and `Int32` without widening the source ABI;
- lower runtime-free numerical leaves directly to Thumb-2 / VFPv3-D16 assembly;
- support Float32 add, subtract, multiply, divide, negate, absolute value, square root, and indexed Float32-buffer loads;
- preserve argument and result ABI rules, including rejection of inappropriate 64-bit `Int` use;
- assemble the output as real ARM objects;
- link a no-libc ARM executable;
- execute the generated result under QEMU and compare exact Float32 bit patterns;
- keep the backend dependency boundary at the compiler API rather than reaching into arbitrary compiler internals.

The work also grew a layered test suite around source acceptance, lowering, assembly/object properties, semantics, and determinism.

## PR #6

PR #6 deliberately chose a much smaller first ordinary executable Idriç program:

`PrintASCII.main = putChar 'x'`

The point was to establish one source-level program that:

1. passed through the pinned Idriç frontend;
2. selected the ARM/Thumb backend;
3. produced a static ELF32 ARM executable;
4. executed under QEMU;
5. emitted exactly one byte, `0x78`.

It was explicitly a bootstrap entrypoint slice, not a claim of general IO lowering. The broader character/UTF-8 fixtures were preserved as future specifications.

## Combined intent

Together, #1 and #6 were trying to move the native ARM line from:

**typed numerical leaf lowering → verified machine code → one unquestionably executable source program**

without pretending that this already provided general IO, strings, Unicode, heap/GC, libc integration, Android application delivery, or the later DEX backend.
