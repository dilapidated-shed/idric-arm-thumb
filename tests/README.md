# ARM/Thumb backend tests

The backend test suite is layered so failures point at the contract that broke.

- `make source-test` — typecheck the backend and verify source-ABI rejection diagnostics.
- `make lowering-test` — compile real `.idric` fixtures and inspect required Thumb/VFP lowering.
- `make assembly-test` — assemble Android-target ELF32 ARM objects and inspect ABI attributes, symbols, and undefined references.
- `make semantic-test` — link generated assembly into a no-libc ARM executable and execute it under QEMU with exact Float32 bit checks.
- `make determinism-test` — compile the same fixture twice and require byte-identical emitted assembly.
- `make test` / `make verify` — run the complete suite.

`tests/source/` contains acceptance-boundary fixtures. `tests/arm/backend_selftest.S` is the runtime oracle for generated code. Each semantic failure exits with a distinct nonzero code so the failing primitive or ABI case is identifiable.

Exact Float32 checks currently include ordinary arithmetic, signed zero, exact fractional/negative results, buffer loads, identity/unused arguments, and the four-register one-word softfp argument boundary. NaN payload behavior is intentionally not asserted until that bit-level contract is specified.


## E3M2 observational residue measurements

`make e3m2-observe` executes E3M2 arithmetic in the generated Thumb program and
prints the reference value, observed E3M2 value, and numerical residue
(`observed - reference`). The numerical residue is deliberately not a pass/fail
criterion.

The cases include add/subtract/multiply/divide, square, cube, square root, the recovered 14-by-26 Dakota sweep measurement-model Jacobian, a planar rotation using
the same steering-ratio angle as the caster work, and the two-position caster
multiplier. The runner only fails if the program cannot execute or does not emit
the expected number of observation payloads.


The Jacobian observation deliberately quantizes all 364 named partial
derivatives before executing a 14-by-26 matrix-vector product. At the current
E3M2 scale, 278 of the 364 matrix entries become zero; that loss is reported as
part of the measurement rather than treated as a test failure.
