# Fetch batching and memory timing for high-dimensional model work

Recorded 2026-09-24.

## Purpose

Preserve the design questions from the ARM Thumb/NEON discussion without
prematurely optimizing one kernel. The current phone-facing implementation is
the concrete reference, but the representation should keep semantic choices
separate from machine-specific lowering.

## Start from a batch, not one lookup

Do not force the prototype into:

```text
coordinate -> fetch -> compare -> repeat
```

Prefer this provisional shape:

```text
many requested coordinates
    -> organize requests
    -> fetch useful chunks
    -> do all useful work while each chunk is available
    -> return only the information actually needed
```

Keep three sizes distinct:

1. **request batch** -- logical coordinates/operations waiting;
2. **memory block** -- nearby data worth fetching or retaining together;
3. **register batch** -- data consumed by the current scalar/NEON operation.

A request batch may be hundreds or thousands of coordinates while one NEON
operation handles only the current 64 or 128 bits.

## The useful operation is still intentionally unresolved

Possible requests include sign, rough binary magnitude, exponent/scale class,
fuller low-precision comparison, or coordinate pairs used in rotations. The
returned result may be much smaller than the fetched representation.

Do not assume a conventional full vector multiply is the primitive merely
because a high-level language makes it easy to write. The filesystem/block
interface should make factorized operations routine.

## Holding data does not consume one cycle per cycle

Separate **retention** from **latency**.

A value can remain in a register or cache for many core cycles. It occupies
finite storage, but software does not pay another cycle merely because the bits
continue to be there.

Time is paid when work must happen: lookup, translation, transfer, replacement,
dependency resolution, or satisfying a miss from another level.

Keep these separate:

- **capacity** -- bytes that can remain resident;
- **transfer width** -- bits/bytes crossing one path at once;
- **latency** -- time before one requested result is usable;
- **throughput** -- requests/bytes accepted or completed per unit time;
- **occupancy** -- finite queue/cache/register space consumed while waiting.

## There is not one global software-visible clock

Do not model the memory system as every stage advancing once per CPU clock.
Core, cache/interconnect, memory controller, and DRAM can have different clocks
and timing rules, with queues/buffers between them.

A statement such as "four-cycle load latency" is conditional on a particular
microarchitectural path and clock domain. DRAM timing can be more naturally
expressed in its own command timings or elapsed nanoseconds and only then
translated approximately into core cycles.

The silicon is still tightly timed. Setup/hold, voltage, temperature, frequency,
characterization, and production testing establish real physical margins.
Software-visible latency varies because requests take different paths and wait
behind different work.

## "Farther away" means hierarchy/state, not pointer magnitude

Useful distance includes:

- register-resident;
- L1 hit;
- lower-cache hit;
- DRAM;
- storage-backed chunk/page;
- translation state;
- controller/bank/row state;
- queueing behind other requests;
- useful data already staged by an earlier fetch.

Numeric address distance by itself is not the relevant metric.

## Batch with a deadline

A provisional scheduling rule worth measuring:

```text
flush when full
OR
flush when the oldest request has waited long enough
```

A 63/64-full batch might reasonably wait a few cycles for the final request if
that materially improves downstream work. It should not wait hundreds or
thousands of cycles merely to reach a round number.

Keep multiple independent block batches in flight when possible so one slow
request does not stall unrelated ready work. The maximum batch size and timeout
are empirical parameters, not language semantics.

## Throughput may matter more than one-request latency

Candidate objectives include:

- useful comparisons/transformations per second;
- bytes moved per useful result;
- blocks fetched per useful result;
- fraction of each fetched block actually used;
- energy per useful result;
- dimensionality that can be represented/executed;
- sufficient precision for the actual decision;
- tail latency only where the application needs it.

As dimensionality can be worth more than unnecessary precision, slightly higher
single-request latency can be worth accepting for much better aggregate
throughput or a substantially larger executable model.

## Thumb/NEON is downstream of staging

For the current AArch32/Thumb-facing line:

- scalar integer work is naturally 32-bit;
- NEON exposes 64-bit D and 128-bit Q registers;
- vector lane interpretations commonly include 16x8, 8x16, 4x32, and 2x64;
- logical request batches can be much larger than one Q register.

NEON is useful after data has been staged into a regular form for masks, shifts,
comparisons, permutations, low-precision arithmetic, or rotation-like work. Do
not treat it as a general arbitrary-address gather mechanism.

It is reasonable to prototype the representation as bit transformations before
trying to fill every vector lane efficiently.

## Eight billion values imply staging

At one byte per value, eight billion values require about 8 GB of payload.
A 32-bit process cannot expose that as one ordinary flat user virtual-address
range. Some block/window/file-backed/staged representation is therefore already
part of the problem before arithmetic optimization begins.

## Phone hardware facts: known versus unknown

UNISOC documents SC9863A as an eight-core Cortex-A55 SoC supporting LPDDR3 and
LPDDR4/4X memory at 933 MHz. The public product page does not establish this
MIRO A1's exact DRAM bus width or channel topology.

Arm documents Cortex-A55 as configurable rather than one fixed cache machine.
Published ranges include 8-64 KB L1 instruction/data caches, 64-256 KB private
L2, and optional shared L3. Do not substitute a convenient generic A55
configuration for measurements from the actual phone.

Sources:

- https://www.unisoc.com/en/product/SmartPhone/9863A
- https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/Cortex-A%20R%20M%20datasheets/Arm%20Cortex-A%20Comparison%20Table_v4.pdf
- https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/arm-cortex-a55-efficient-performance-from-edge-to-cloud

## What the container can and cannot establish

Use emulation/container work for instruction correctness, encoding, generated
instruction inspection, and coarse instruction-count reasoning.

Do not use it as the timing model for the phone's cache hierarchy, prefetching,
memory controller, queue depths, outstanding loads, translation behavior,
frequency control, or real latency distribution.

## Physical-phone measurement plan

Measure at least:

1. repeated hot reads from a tiny working set;
2. increasing working-set sizes to expose cache-capacity transitions;
3. sequential, strided, and randomized address patterns;
4. dependent pointer-chasing to suppress memory-level parallelism and expose
   load latency;
5. independent loads to expose achievable memory-level parallelism/throughput;
6. batches of 1, 2, 4, 8, 16, 32, 64, then larger logical batches;
7. partial-batch timeout policies;
8. repeated runs and distributions, not one elapsed-time number.

Useful outputs:

```text
working-set size -> dependent-load latency distribution
batch size        -> useful fetches per second
access pattern    -> bytes moved per useful result
batch age         -> throughput/latency tradeoff
```

This should provide enough physical evidence for software design without
turning the project into bench-level silicon characterization.

## Stop condition

The number of knobs is itself a project risk. Before further micro-optimization,
require a concrete end-to-end operation that produces a useful result. Record
alternatives and measurements, but prefer a working factorized model operation
over indefinitely tuning register width, batch size, cache behavior, or memory
scheduling before the useful operation is known.
