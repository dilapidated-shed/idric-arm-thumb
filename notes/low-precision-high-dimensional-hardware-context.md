# Hardware context for low-precision high-dimensional comparisons

Verified/recorded 2026-09-24.

## Scope

This note is **not** a commitment to any one processor architecture.

The working problem is broader:

> low-precision, high-dimensional comparison and pairwise transformation, with
> enough semantic information retained to choose different lowerings on
> different machines.

The point of listing hardware is to keep memory movement, register width,
available arithmetic, and deployment constraints concrete while we explore the
operations. A server CPU, a hosted CI VM, and a cheap phone are evidence about
different parts of the problem; none defines the language.

## Concrete machines and memory systems

| environment | execution-visible compute | memory system known from current evidence | useful for | do **not** infer |
| --- | --- | --- | --- | --- |
| current ChatGPT container | KVM guest; `AMD EPYC 9V74 80-Core Processor` model string; 5 vCPUs exposed; AVX2, F16C, AVX-512, AVX-512 BF16/VNNI visible | guest has about 5.8 GiB RAM; physical DRAM type, channel count, DIMM placement, and host NUMA topology are not exposed reliably to the guest | x86-64 instruction experiments, vectorized comparison/mixing prototypes, cache/access-pattern microbenchmarks inside the VM | that the guest has any particular number of physical memory channels, or that the exposed CPU model is a stable deployment contract |
| GitHub standard public Linux x64 runner | 4 x64 vCPUs in a fresh VM | 16 GB RAM, 14 GB SSD; GitHub does not promise the underlying CPU model or physical DRAM/channel topology | repeatable CI and portability checks across a hosted x64 environment | physical DDR generation/channel count, NUMA layout, or a stable microarchitecture |
| GitHub standard public Linux arm64 runner | 4 arm64 vCPUs in a fresh VM | 16 GB RAM, 14 GB SSD; underlying physical memory topology is not part of the runner contract | arm64 CI and cross-architecture acceptance | that it represents the phone SoC, Cortex-A55, or a particular server Arm CPU |
| AMD EPYC 9555 physical-server reference | 64 cores / 128 threads, 256 MB L3, PCIe 5.0 | **12 DDR5 channels**, up to DDR5-6400, **614 GB/s per-socket memory bandwidth** | a concrete conventional data-center CPU for thinking about many memory channels, bandwidth, cache-line traffic, paired/gathered operands, and large-model storage | that the project is an EPYC project, or that virtual runners expose this topology |
| NVIDIA Grace CPU / GH200 reference | 72 Arm Neoverse V2 cores per Grace CPU | server-class **LPDDR5X**; Grace C1 configurations up to 512 GB/s CPU-memory bandwidth; GH200 CPU memory up to about 500 GB/s; CPU/GPU connected by NVLink-C2C | a useful contrast with conventional multi-channel DDR5: bandwidth/energy/capacity can be organized differently, especially near accelerators | that "server memory" always means DIMM-attached DDR channels |
| inexpensive phone/tablet deployment targets | MIRO A1 / PowerVR phone; Allwinner A333 / Mali-G57 tablet | exact DRAM generation, channel topology, and sustainable bandwidth have **not** yet been established from device evidence | the deployment constraint that matters for actual on-device inference/rendering; measure real kernels here | data-center assumptions, native FP8 support, or memory bandwidth not actually measured on the devices |

## Why the memory system belongs in this investigation

For a very large representation, the arithmetic operator may be cheaper than
locating and moving its operands.

An 8-billion-value weight array is approximately:

| stored format | payload for 8 billion values |
| --- | ---: |
| 8 bits/value | 8 GB |
| 16 bits/value | 16 GB |
| 32 bits/value | 32 GB |

That makes questions such as these first-class:

- Where are the two coordinates/weights that need to interact?
- Can they be fetched together or in a predictable stream?
- Are we comparing whole values, only signs, only exponent/scale classes, or a
  finer significand relation?
- Can a pairwise transform reuse values already in registers/cache?
- Is the operation bandwidth-bound before its arithmetic cost matters?
- Does the deployment backend widen compact storage values for computation, or
  operate directly on a low-precision representation?

## Working conceptual boundary

The branch/research line should remain about **low-precision high-dimensional
comparisons and transformations**, not about a particular CPU.

Possible investigations include, without committing to a primitive set:

- sign-only questions;
- equality/ordering by rough binary scale or exponent class;
- full magnitude comparison;
- locating and loading coordinate pairs;
- squared-distance comparisons that avoid square root when only ordering is
  needed;
- scale normalization versus exact Euclidean normalization;
- pairwise dimension mixing / Givens-like rotations;
- compact learned weights stored in FP8-like encodings but widened differently
  on ARM CPU, PowerVR, Mali, x86-64, or later accelerator backends.

The semantic question should stay above the lowering question. A cheap exponent
comparison may implement "same rough scale" on one format; that does not require
the user-facing concept to be "compare exponent bits."


## Embedded scalar follower targets

The scalar arithmetic and the backend scaffolding should be treated as two
different questions.

Once a format's value semantics are fixed, its basic scalar implementation is
mostly shifts, masks, integer add/subtract, comparisons, and branches. That
makes the arithmetic portable across many small ISAs. It does **not** mean the
backend scaffolding, ABI choices, multi-byte operations, or acceptance coverage
are equally mature on those targets.

The existing `isomorphisms/idric-embedded` target branches give us concrete
follower directions:

| target family | embedded branch | note for low-precision scalar work |
| --- | --- | --- |
| RP2040 / Cortex-M0+ Thumb | `rp2040` | Closest follower to the ARM Thumb reference work. Reuse semantics, but keep the RP2040 backend contract separate. |
| ESP RISC-V / ESP Xtensa | `esp` | Both are plausible scalar targets, but RISC-V and Xtensa are different lowerings. Pin the actual chip/ISA before making instruction-level claims. |
| MSP430 / MSP430X | `msp430` | A 16-bit working value is a natural fit for values wider than one byte, including 9-bit E5M3. |
| AVR / ATmega | `atmega` | 8-bit scalar storage is natural for the 8-bit formats; 9-bit E5M3 needs a wider or multi-byte working representation. |
| AVR / ATtiny | `attiny` | Same width issue as ATmega, with tighter machine constraints making the lowering more revealing. |
| CH552 / 8051 | `ch552` | Scalar arithmetic remains feasible, but multi-byte work and backend plumbing are more tedious. Treat this as a constrained-case test, not a claim of equal maturity. |
| Game Boy SM83 | `game-boy` | Another useful constrained 8-bit case. Keep semantics common while allowing very different register/memory lowering. |
| TriCore / AURIX | `tricore-aurix` | Plausible follower once the exact TriCore generation/subtarget is pinned; do not write lowering assumptions against an unspecified AURIX core. |

These branches should remain architecture-specific evidence. Portability of the
arithmetic is not a reason to collapse their distinct backend work.

### Keep three widths separate

For these scalar formats, do not silently identify:

1. **logical payload width** -- the bits required by the format itself;
2. **storage width** -- how the value is laid out in memory or an ABI slot; and
3. **working width** -- the integer/register width used while decoding,
   normalizing, comparing, or doing arithmetic.

For the current six-format line, the nominal payload widths are:

| format | nominal payload width |
| --- | ---: |
| E3M2 | 6 bits |
| E4M3 | 8 bits |
| E5M2 | 8 bits |
| E5M3 | 9 bits |
| Bits8 | 8 bits |
| Float16 | 16 bits |

Those widths do not by themselves choose packing or ABI layout. In particular,
E5M3 crossing the one-byte boundary is exactly the sort of case that should make
the backend's widening and multi-byte policy explicit rather than hidden inside
generic scalar code.

### Follower acceptance

A follower backend should prove the shared semantics before it is called an
implementation. At minimum, keep acceptance around:

- encode/decode round trips and the format's special-value policy;
- comparison and sign/scale behavior;
- conversion to and from the backend's chosen working representation;
- arithmetic against the same reference semantics used by ARM Thumb;
- byte order and multi-byte behavior where storage or working values cross an
  8-bit boundary.

The ARM Thumb implementation remains the reference line. The embedded targets
are followers used to discover where the allegedly portable scalar semantics
still leak assumptions about register width, carry/borrow, normalization,
packing, or ABI shape.

## Sources

- AMD EPYC 9555 product page: 12 DDR5 channels, up to 6400 MT/s, 614 GB/s per
  socket:
  https://www.amd.com/en/products/processors/server/epyc/9005-series/amd-epyc-9555.html
- GitHub-hosted runners reference: standard public Linux x64/arm64 runners are
  4-vCPU, 16-GB VMs; private standard Linux runners are 2-vCPU, 8-GB VMs:
  https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- NVIDIA Grace Performance Tuning Guide: 72 Neoverse V2 cores, server-class
  LPDDR5X, Grace C1 and GH200 memory-bandwidth figures:
  https://docs.nvidia.com/dccpu/grace-perf-tuning-guide/

The current-container row is a direct observation from `lscpu` / `free` in
the active KVM guest, not a claim about the hidden physical host.


## Small rotations: plan the planes, keep antisymmetry structural

For a small rotation in an active coordinate plane \((i,j)\), the register
work can use the first-order update

\[
x_i' \approx x_i - \theta x_j, \qquad
x_j' \approx x_j + \theta x_i.
\]

The higher-level planning/type layer should decide which coordinate planes are
active and communicate one signed small rotation amount per plane. The backend
should not materialize a dense high-dimensional rotation matrix when only a few
planes need to move.

For a complex representation of a selected 2-plane, antisymmetry is already
structural:

\[
z = x_i + i x_j, \qquad
z' = e^{i\theta} z \approx (1 + i\theta)z.
\]

In polar form this is simply

\[
(r,\phi) \mapsto (r,\phi + \theta).
\]

Therefore do **not** separately encode equal-and-opposite coefficients such as
\((-2,+2)\) for the two directions of one plane. Encode the plane plus one
signed rotation amount; the opposite coupling is implied by the complex
structure. Sparse signed amounts such as \(-2,-1,+1\) can belong to distinct
active planes or planned rotation contributions, but each individual rotation
plane retains this antisymmetric pairing.

The linearized update is intentionally first-order. Norm error is second-order
in the small angle, so repeated composition needs its own policy; that should
not be confused with the representation of one small planned rotation.
