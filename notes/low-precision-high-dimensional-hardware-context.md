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
