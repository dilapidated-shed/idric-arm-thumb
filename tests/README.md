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


## Narrow-float observational residue measurements

`make low-precision-observe` executes the same numerical suite for Float16,
E4M3, E5M2, E3M2, and E5M3. It prints the reference value, observed value,
and numerical residue (`observed - reference`) for arithmetic, powers, square
root, the 14-by-26 Dakota Jacobian-vector product, planar rotation, and caster.
Residue is reported rather than graded.

The established E3M2 Jacobian/direction fixture defines the shared numerical
inputs: those payloads are decoded once and the resulting values are re-encoded
independently in each destination format. E5M3 remains an unsigned
positive-normal storage format. Its positive-domain cases use test-only
decode/Float32-operation/encode wrappers; Jacobian cases requiring zero or
negative values are reported explicitly as outside the format domain.

`make e3m2-observe` remains as a filtered view of the same executable.
