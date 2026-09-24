# Machine convolution type

Status: exploratory note. This is not yet a compiler ABI or storage-format commitment.

## Idea

Treat convolution as a first-class machine/compiler type rather than starting from
"ternary digits packed into binary."

The motivating exact kernel is

```text
[1, 1, 1]
```

with the recurrence

```text
next[i] = prev[i - 1] + prev[i] + prev[i + 1]
```

starting from the impulse `[1]`.

The first rows are

```text
1
1 1 1
1 2 3 2 1
1 3 6 7 6 3 1
1 4 10 16 19 16 10 4 1
```

These are coefficients of `(x^-1 + 1 + x)^n`, equivalently shifted
coefficients of `(1 + x + x^2)^n`.  The row sum is exactly `3^n`.

So an exact probability row can be represented as

```text
integer coefficients + step n
```

with denominator `3^n` implicit.  No floating-point representation is needed.

## Why make it a type?

The type should describe the mathematical operation and its invariants, not one
permanent bit layout.

Possible information carried by the type:

- coefficient domain;
- fixed kernel;
- support/radius;
- convolution step/count;
- exact overflow bound or widening rule;
- symmetry, when proven;
- normalization base, here `3`.

A sketch, not syntax:

```text
MachineConvolution coefficient kernel step
```

For the trinomial/Gaussian experiment, `kernel = [1,1,1]`.  A compiler can
then lower the same type to scalar integer code, SIMD, a special accelerator,
or some future redundant arithmetic representation without changing its
mathematical meaning.

## This is operation-centered, not ternary storage

Balanced ternary storage asks how to encode digits in `{-1,0,+1}`.

This experiment asks how to retain and execute the exact convolution generated
by those three choices.  Repeated addition produces a discrete bell-shaped
distribution automatically.  The machine object is the convolution state, not
a packed ternary numeral.

That distinction matters: packing density is secondary.  We can deliberately
use wider temporary states, delayed normalization, or redundant arithmetic if
they make the operation cheaper.

## Invariants for a first acceptance slice

For step `n`:

1. support is `[-n,n]`;
2. coefficients are nonnegative integers;
3. the row is symmetric;
4. the coefficient sum is exactly `3^n`;
5. one step is exactly convolution by `[1,1,1]`;
6. no Float16/32/64 is used in the exact path;
7. overflow is explicit: widen, reject, or use an arbitrary-precision reference.

Acceptance should compare emitted target code against an exact reference for a
small sequence of rows and inspect the generated machine instructions.

## Prior art / novelty caution

None of the individual pieces is new:

- trinomial coefficients and the three-parent Pascal-style recurrence are old;
- DSP and ML implementations perform convolution constantly;
- SIMD and convolution accelerators specialize the operation;
- redundant signed-digit arithmetic has been used to reduce carry propagation;
- recent accelerator work has even combined redundant signed-digit arithmetic
  with convolution windows.

The exploratory point here is narrower: make an exact convolution object with
its algebraic invariants a first-class compiler/machine type, then let each
backend choose the representation and lowering.  Do not claim novelty without
a dedicated literature search.

Related directions to inspect:

- central/trinomial coefficients and `(1+x+x^2)^n`;
- Avizienis-style redundant signed-digit arithmetic;
- carry-save / borrow-save intermediate forms;
- SIMD FIR/direct-convolution kernels;
- systolic/tensor convolution hardware;
- block-valued compiler IRs.

## First question

Does preserving convolution as a typed operation expose optimizations that are
lost when the frontend immediately expands it into unrelated scalar adds,
loads, and stores?

That is the experiment.


## ARMv7-A Thumb-2 notes

The current native ARM line targets ARMv7-A Thumb-2 with VFPv3-D16.  The first
implementation should therefore be ordinary exact integer loads/adds/stores
and must not assume NEON unless the concrete target and backend contract add it.

The ISA tells us the architectural behavior of integer addition and flags; it
does not tell us the exact gate-level carry-prefix topology of the physical
core.  Core-specific circuit claims belong in a separate microarchitecture
note and need evidence for the actual CPU, not merely "ARMv7-A".

Useful experiments:

- scalar three-neighbor recurrence with 32-bit and 64-bit coefficients;
- explicit widening before overflow;
- block several outputs to reuse loaded neighbors;
- compare immediate normalization against delayed/redundant accumulation;
- inspect whether a carry-saving representation wins after instruction count,
  register pressure, and memory traffic are included.


## Concrete Thumb-2 arithmetic consequences

For this backend, avoid generic discussion of "a CPU multiplier" when the
instruction-level question can be stated exactly.

The portable contract is ARMv7-A AArch32/T32 (Thumb-2).  Useful integer
instructions include:

- `ADDS` / `ADC`: canonical multiword addition with APSR carry propagation;
- `SUBS` / `SBC`: canonical multiword subtraction/borrow;
- `RSB`: cheap integer negation/reverse subtraction;
- `MUL` / `MLA` / `MLS`: 32-bit product and fused integer
  multiply-add/subtract forms;
- `SMULL` / `UMULL`: 32 x 32 -> 64-bit product;
- `SMLAL` / `UMLAL`: 32 x 32 product accumulated into a 64-bit pair;
- `SMLAD`, `SMUAD`, related packed-halfword DSP operations where the
  architecture/profile and exact operand layout make them legal and useful;
- `SXTB/SXTH/UXTB/UXTH` and the add variants for unpacking deliberately small
  coefficient lanes.

Do not make `SDIV`/`UDIV` part of the ARMv7-A baseline: integer divide is
optional in ARMv7-A.  Constant powers of three should first be considered as
compile-time strength reductions, reciprocal/table schemes, or representation
changes rather than assuming a divide instruction.

For balanced ternary specifically, multiplication by a single digit does not
need `MUL`: multiplying by `-1, 0, +1` is sign/select logic.  The expensive
part is accumulation and eventual normalization.

For chunked radix-`3^k` arithmetic, the backend should compare at least these
forms:

1. canonical chunks with an `ADDS/ADC` carry chain;
2. a wider accumulator that admits several chunk sums before normalization;
3. redundant signed-digit/chunk accumulators with a final canonicalization;
4. for multiplication, `UMULL/SMULL` plus `UMLAL/SMLAL` accumulation rather
   than materializing every shifted partial product separately.

"Shifted partial products", "compressor tree", and "carry-save stages" are
hardware-design descriptions unless we deliberately expose an equivalent
redundant representation in software.  The Thumb backend cannot command the
core's internal compressor tree.  It can, however, arrange the instruction
stream so the core sees fewer architecturally serialized carry dependencies.

A useful acceptance comparison is therefore not "did we emit a compressor
tree?" but:

```text
canonical carry chain
vs
widened/delayed-normalization accumulator
vs
redundant accumulator + one final normalization
```

Measure instruction count, true register dependencies, register pressure,
loads/stores, and cycles on the physical phone.

## Physical-phone microarchitecture

The MIRO A1 is sold as using an SC9863-family SoC with Cortex-A55 cores.  Treat
that as a hardware hypothesis to verify from the device itself before making a
hard backend contract.

Cortex-A55 is an in-order superscalar Armv8.2-A core and supports AArch32 at
EL0.  That makes independent accumulators especially worth testing: on an
in-order superscalar machine, one long dependency chain can inhibit overlap
that independent chains might expose.

Even here, do not invent gate-level details.  Public Arm architectural and
Cortex-A55 material gives instruction behavior and high-level pipeline facts;
it does not document the exact transistor/gate topology of the integer adder or
its carry-prefix network.  If exact adder topology matters, it must come from a
specific disclosed implementation or measurement, not from the label
"ARMv7-A", "Thumb-2", or "Cortex-A55".

The backend should continue emitting only the chosen ARMv7-A Thumb-2 subset
unless a separate target explicitly opts into later Armv8/A55 instructions.
The fact that the physical phone may have newer hardware is not permission to
silently widen the compiler target.
