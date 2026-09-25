# Idriç ARM/Thumb backend

Direct ARMv7 Thumb-2/VFP backend for Idriç, without routing numerical leaves through C.

## Development lines

`native-arm` is the active native ARM/Thumb development line. It reconciles the former `arm-thumb-test-suite` and `branching-dispatch-fixtures` descendants.

`main` intentionally remains the separate direct-DEX line. Advancing native ARM/Thumb does not require merging this line into DEX.

The active numerical slice remains a closure-free Float32 C ABI, but it now also admits **internal polar `Complex64` values**: two Float32 words `(magnitude, phase)`. Complex64 is deliberately not exported across the C ABI yet; exported arguments and results remain the already-qualified one-word forms.

```text
.idric source
  -> current Idriç parser/typechecker/erasure
  -> Compiler.ANF
  -> validated runtime-free leaf IR
  -> deterministic Thumb-2/VFP .S
  -> ELF32 ARM object
```

The proof fixture is `examples/Affine.idric`:

```idris
%export "arm-thumb:evaluate_affine"
evaluate_affine : Float32 -> Float32 -> Float32 -> Float32
evaluate_affine a x b =
  float32_add (float32_multiply a x) b
```

The backend is pinned to Idriç commit:

```text
081b9cde0591154839fb5d80d76e5570e0436300
```

That compiler deliberately remains implemented on the current Idris 2 internals, so this backend uses its existing `Compiler.ANF` custom-codegen seam instead of creating a second competing Idriç IR.

## Target ABI

- Android `armeabi-v7a`
- ARMv7-A, Thumb-2
- VFPv3-D16 scalar Float32 arithmetic
- softfp C boundary: up to four Float32 words enter through `r0`-`r3`; the Float32 result leaves as raw bits in `r0`
- 8-byte-aligned stack frame
- no heap, GC, closures, or Idris runtime in the emitted numerical leaf
- internal `Complex64` is two Float32 stack words in polar order: magnitude, phase

## Build and verify

Build the pinned Idriç compiler and install its compiler API/libraries, then run:

```sh
make verify IDRIC=/path/to/Idric/build/exec/idris2
```

`make verify` checks the compiler revision, typechecks and builds the custom driver, compiles the real `.idric` affine fixture through `--cg arm-thumb`, requires `vmul.f32` and `vadd.f32` in the generated assembly, assembles it with Clang for `armv7a-linux-androideabi21`, and checks that the result is an ELF32 ARM object.

GitHub Actions performs that path from a clean checkout by bootstrapping the exact pinned Idriç revision first.

## Current boundary

Accepted now:

- one exported runtime-free function at a time or multiple independent exports
- zero to four explicit `Float32` arguments
- `Float32` result
- local copies
- Float32 add/subtract/multiply/divide/negate/abs/sqrt
- caller-owned Float32 buffer loads
- internal polar `Complex64`
- Float32 -> Complex64 lift: negative finite reals become `(|x|, pi)`, nonnegative finite reals become `(x, 0)`
- explicit polar construction
- Complex64 magnitude/phase extraction
- Complex64 multiply/divide/conjugate

Rejected now:

- Complex64 as an exported C argument or result
- complex addition/subtraction (needs a deliberate trig/libm or alternate lowering)
- Complex32 arithmetic
- Float64/Complex128 as a prerequisite for this ARMv7 path
- branches and comparisons
- recursion or general calls
- constructors, closures, allocation, strings, IO, JNI, or Android lifecycle code

The older `idris-arm-backend` remains useful reference code for the broader arithmetic/buffer subset. This repository is the Idriç-specific line and advances only when the current Idriç compiler accepts and verifies the slice.

## Next slice

After this affine path is green: bring back the remaining proven Float32 operations and caller-owned `Float32Buffer` loads, then add comparisons and a constrained tail loop for Horner evaluation.


## Why Complex64, not Float64

On this ARMv7/VFPv3-D16 target the existing arithmetic path is native Float32.

The naming is therefore:

```text
Float32 + Float32 polar pair -> Complex64
Float16 + Float16 polar pair -> Complex32
```

Complex64 is the first arithmetic complex type because it uses the already-qualified Float32 operations. Complex32 remains a useful later storage format, but binary16 arithmetic should promote to Float32 rather than pretending this VFPv3-D16 target has native Float16 arithmetic.

The Pauli renderer is the immediate consumer motivating this slice.
