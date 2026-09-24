# Cortex-A55 low-precision floating point: ISA versus datapath

This note is a side investigation on `notes/cortex-a55-carry-path`. It preserves
the separate dyadic-rational research; the question here is narrower: how much
of the desired deliberately-low-precision arithmetic is already present in the
Arm ISA and Cortex-A55 hardware, and what would a still coarser primitive mean?

## First correction: Armv7-A FP16 is not native FP16 arithmetic

The current backend target documented in this repository is Armv7-A Thumb-2
with VFPv3-D16 Float32 arithmetic.

On Armv7-A, the optional `fp16` VFP/NEON extension provides half-precision
storage/conversion operations. It does not provide the later full set of
half-precision arithmetic operations. Arm's own compiler documentation describes
`__fp16` in this regime as a storage type whose C/C++ arithmetic is promoted
to `float`.

Full IEEE binary16 *data processing* was added by Armv8.2-A. Arm states that
the addition applies to both AArch32 and AArch64 and to scalar FP and Advanced
SIMD. Cortex-A55 implements Armv8.2-A and IEEE FP16.

Therefore the comparison relevant to this branch is:

```text
Armv7-A T32/VFP:
    binary16 storage/conversion
    arithmetic normally in binary32

Armv8.2-A T32 on Cortex-A55:
    native binary16 scalar arithmetic
    native binary16 Advanced SIMD arithmetic

Cortex-A55 microarchitecture:
    particular execution resources, pipeline, latency, throughput,
    forwarding, divide/sqrt iteration, and lane packing
```

Do not call the Armv8.2-A instructions "Armv7-A FP16 arithmetic".

## Architecture versus microarchitecture

The ISA specifies the software-visible contract: instruction encodings,
operations, binary16 representation, rounding/special-value behavior, registers,
and architectural state.

It does not require a particular adder, multiplier, normalization network,
pipeline depth, number of execution units, or divide algorithm. Another CPU can
implement the same T32/AArch32 instruction with different latency, throughput,
area, power, and internal width.

Public Arm material does not expose a gate-level Cortex-A55 FP16 schematic.
The strongest public circuit-adjacent evidence used here is the Cortex-A55
Software Optimization Guide: datapath/resource structure plus measured/declared
instruction timing. Do not turn those timing facts into an invented transistor
diagram.

## What Cortex-A55 actually chose

Arm's Cortex-A55 Software Optimization Guide describes:

- an 8-stage integer pipeline;
- a 10-stage FP/Advanced-SIMD path;
- FP/NEON operands read in `f1` and normally completing in `f5`;
- an FP/NEON register file feeding an ALU path and a MAC + DIV/SQRT path;
- in-order issue, with some long FP/NEON operations allowed to complete/retire
  out of order.

The scalar FP timing table gives the following useful contrast:

| operation | latency | throughput |
| --- | ---: | ---: |
| add/sub | 4 cycles | 2 instructions/cycle |
| multiply | 4 | 2/cycle |
| fused multiply-add | 4 | 2/cycle |
| half divide | 8 | 1 per 5 cycles |
| single divide | 13 | 1 per 10 |
| double divide | 22 | 1 per 19 |
| half sqrt | 8 | 1 per 5 |
| single sqrt | 12 | 1 per 9 |
| double sqrt | 22 | 1 per 19 |

The same guide reports the common FP/Advanced-SIMD timings and notes that a
denormal input adds a cycle to divide/sqrt hazard and latency.

For Advanced SIMD FP arithmetic, the A55 can issue two 64-bit forms per cycle.
A 128-bit Q-form occupies the available throughput so only one Q-form issues per
cycle. With eight binary16 lanes in 128 bits, that is the advertised eight
16-bit floating-point lane operations per cycle.

This is already a concrete circuit-level tradeoff:

- common add/multiply/FMA keep a fixed four-cycle scalar latency across widths;
- narrower data buys lane density/parallelism rather than a shorter scalar
  add/multiply latency;
- divide/sqrt do exploit precision: half is materially shorter/less blocking
  than single, which is materially shorter than double;
- 128-bit SIMD is implemented over resources that can also sustain two 64-bit
  operations, rather than requiring every instruction to have an independent
  full-width datapath.

## Could different tradeoffs be made?

Yes, while preserving the same architectural FP16 results.

Examples to investigate rather than assume:

1. **More or fewer FP execution resources.**
   A design could spend area/power on additional FP pipes, or keep one narrower
   pipe and accept lower throughput.

2. **Physical datapath width versus lane count.**
   A design could build a full 128-bit path, paired 64-bit paths, or smaller
   time-multiplexed paths. The ISA does not dictate this.

3. **Divide/sqrt implementation.**
   Iterative, reciprocal-estimate/refinement, radix choice, early termination,
   and dedicated versus shared hardware trade latency, area, and power. The A55
   timing already shows precision-sensitive behavior here.

4. **Subnormal handling.**
   IEEE behavior costs state/control and sometimes cycles. Armv8.2-A FP16 also
   provides `FZ16` control for flushing half-precision denormals to zero.
   A deliberately coarser non-IEEE primitive could choose simpler semantics.

5. **Fused versus separately rounded operations.**
   A55 has a four-cycle fused FMA path. A new primitive must decide whether
   `a*b+c` rounds once, rounds after multiply and again after add, or widens
   internally and rounds only at an explicit boundary.

These questions are more useful than designing a dyadic ALU from scratch.

## Second question: an 8-bit floating primitive

There is no need to invent the first candidate formats. The Open Compute Project
OFP8 specification and Arm's later A-profile FP8 architecture use two existing
8-bit encodings:

- **E4M3**: sign 1, exponent 4, trailing significand 3;
- **E5M2**: sign 1, exponent 5, trailing significand 2.

Arm added architectural FP8 support in its 2023 A-profile extensions, including
Advanced SIMD/Neon, but Cortex-A55 predates that support. An A55 implementation
would therefore be a software lowering/emulation, not native FP8 hardware.

E5M2 is especially useful as a first contrast with binary16 because it keeps a
5-bit exponent and removes most of binary16's significand bits. E4M3 spends one
more bit on significand precision and one fewer on exponent range. These are
existing, documented range-versus-resolution choices rather than arbitrary new
encodings.

OFP8 itself specifies interchange/conversion, not arithmetic semantics, so a
language primitive still has to choose its arithmetic contract.

## Why a coarse primitive can be semantically useful

The purpose here is not to claim that an 8-bit float encodes survey uncertainty,
model error, measurement disturbance, or any other epistemic error source.

The purpose is to stop ordinary numeric representation from silently creating
fine distinctions that the input never supported.

A useful invariant would be:

```text
a value of coarse type cannot acquire additional represented significant bits
without an explicit widening operation
```

That makes precision an explicit program event instead of an accidental
consequence of the machine's default Float32/Float64 type.

There is an important design choice:

- **round every primitive operation back to FP8**: strongest reminder, but adds
  arithmetic quantization at every step;
- **store/return FP8 but widen intermediate arithmetic to FP16**: cheaper and
  numerically better on A55, but only preserves the epistemic reminder if the
  type system and output boundary prevent widened intermediates from being
  mistaken for more informative observations;
- **explicit wide accumulator type**: coarse inputs stay coarse, but aggregation
  may intentionally gain numerical resolution when the statistical model
  justifies it.

The last option is likely the cleanest architecture to investigate because it
does not equate "source has few meaningful bits" with "every intermediate must
throw bits away".

## Proposed experiment on this branch

Before implementing a new format:

1. Add an Armv8.2-A T32/AArch32 FP16 fixture beside the current Armv7-A
   Float32/VFP fixture.
2. Compile add, multiply, FMA, divide, and conversion forms and record the exact
   encodings/instructions.
3. Bind those instructions to the Cortex-A55 timing/resource tables above.
4. Implement two tiny software oracles for E4M3 and E5M2 conversion/rounding.
5. Compare three arithmetic policies on the same simple kernels:
   - FP8 round after every operation;
   - FP8 values with FP16 intermediates and FP8 results;
   - FP8 inputs with an explicitly wider accumulator.
6. Only then decide whether Idriç needs one coarse primitive, both standard FP8
   encodings, or a different format.

## Sources

- Arm, *Armv8-A architecture evolution*, half-precision data processing:
  https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/armv8-a-architecture-evolution
- Arm, *Cortex-A55 Software Optimization Guide*, ARM-EPM-128372 v3.0:
  https://documentation-service.arm.com/static/5f1fe66bbb903e39c84d7d75
- Arm, *Cortex-A55: Efficient performance from edge to cloud*:
  https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-cortex-a55-efficient-performance-from-edge-to-cloud
- Arm, *A-profile architecture developments 2023*, FP8:
  https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-a-profile-architecture-developments-2023
- Open Compute Project, *OCP 8-bit Floating Point Specification (OFP8)*:
  https://www.opencompute.org/documents/ocp-8-bit-floating-point-specification-ofp8-revision-1-0-2023-12-01-pdf-1
