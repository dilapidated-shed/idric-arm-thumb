#!/usr/bin/env python3
import argparse
import math
from fractions import Fraction
import struct
import subprocess
import sys


FORMATS = ["Float16", "E4M3", "E5M2", "E3M2", "E5M3"]
CASES_PER_FORMAT = 24
BYTES_PER_CASE = 2
DOMAIN_SENTINEL = 0xFFFF

DAKOTA_JV_REFERENCE = [
    0.5451388472381876,0.5927113334029114,0.4895670078008919,
    0.5289665323810473,0.45372048698916667,0.4731549501099014,
    0.42261242702714896,-0.15357695334574295,-0.08165240496535331,
    -0.05029350042927705,0.018128930745486826,-0.0026210159607702455,
    0.058420594931340275,-0.046822717143564785,
]

DAKOTA_ROW_NAMES = [
    "driver.camber[0]","driver.camber[1]","driver.camber[2]","driver.camber[3]",
    "driver.camber[4]","driver.camber[5]","driver.camber[6]",
    "passenger.camber[0]","passenger.camber[1]","passenger.camber[2]",
    "passenger.camber[3]","passenger.camber[4]","passenger.camber[5]",
    "passenger.camber[6]",
]


def decode_ieee_like(payload: int, exponent_bits: int, mantissa_bits: int,
                     bias: int, kind: str) -> float:
    sign_shift = exponent_bits + mantissa_bits
    negative = bool(payload & (1 << sign_shift))
    code = payload & ((1 << sign_shift) - 1)
    exponent_mask = (1 << exponent_bits) - 1
    mantissa_mask = (1 << mantissa_bits) - 1
    exponent = (code >> mantissa_bits) & exponent_mask
    mantissa = code & mantissa_mask

    if kind == "E4M3" and code == 0x7F:
        return math.nan
    if kind == "E5M2":
        if code == 0x7C:
            return -math.inf if negative else math.inf
        if code in {0x7D, 0x7E, 0x7F}:
            return math.nan

    if exponent == 0:
        value = math.ldexp(mantissa / (1 << mantissa_bits), 1 - bias)
    else:
        value = math.ldexp(1.0 + mantissa / (1 << mantissa_bits), exponent - bias)
    return -value if negative else value


def decode(name: str, payload: int) -> float:
    if name == "Float16":
        return struct.unpack("<e", payload.to_bytes(2, "little"))[0]
    if name == "E4M3":
        return decode_ieee_like(payload & 0xFF, 4, 3, 7, name)
    if name == "E5M2":
        return decode_ieee_like(payload & 0xFF, 5, 2, 15, name)
    if name == "E3M2":
        return decode_ieee_like(payload & 0x3F, 3, 2, 3, name)
    if name == "E5M3":
        bits = ((payload & 0xFF) << 20) + 0x38080000
        return struct.unpack("<f", struct.pack("<I", bits))[0]
    raise ValueError(name)


def dyadic(value: float) -> str:
    fraction = Fraction(value).limit_denominator(16)
    if float(fraction) != value:
        return f"{value:.6f}"
    if fraction.denominator == 1:
        return str(fraction.numerator)
    return f"{fraction.numerator}/{fraction.denominator}"


def reference_text(value: float) -> str:
    fraction = Fraction(value).limit_denominator(16)
    if abs(float(fraction) - value) < 1e-12:
        if fraction.denominator == 1:
            return str(fraction.numerator)
        return f"{fraction.numerator}/{fraction.denominator}"
    return f"{value:.6f}"


def cases() -> list[tuple[str, float]]:
    theta = math.radians(360.0 / 17.4)
    caster_multiplier = 1.0 / (2.0 * math.sin(theta))
    x = 3.0
    y = 4.0
    return [
        ("add 1.5 + 0.5", 1.5 + 0.5),
        ("subtract 1.5 - 0.5", 1.5 - 0.5),
        ("multiply 1.5 * 0.5", 1.5 * 0.5),
        ("divide 1.5 / 0.5", 1.5 / 0.5),
        ("power 1.5^2", 1.5 ** 2),
        ("power 1.5^3", 1.5 ** 3),
        ("sqrt 2", math.sqrt(2.0)),
    ] + [
        ("Jv " + name, value)
        for name, value in zip(DAKOTA_ROW_NAMES, DAKOTA_JV_REFERENCE)
    ] + [
        ("rotate (3,4) x", math.cos(theta) * x - math.sin(theta) * y),
        ("rotate (3,4) y", math.sin(theta) * x + math.cos(theta) * y),
        ("caster from 4-degree swing", 4.0 * caster_multiplier),
    ]


def observe(name: str, payloads: list[int]) -> None:
    theta = math.radians(360.0 / 17.4)
    caster_multiplier = 1.0 / (2.0 * math.sin(theta))
    print(f"{name} observational measurements: ARM Thumb-2")
    print(f"theta={math.degrees(theta):.9f} deg  "
          f"sin={math.sin(theta):.9f}  cos={math.cos(theta):.9f}  "
          f"caster_multiplier={caster_multiplier:.9f}")
    print("All five formats receive the same source numerical inputs before quantization.")
    print("The numeric residue is observed - reference; it is reported, not graded.")
    print()
    print(f"{'case':31} {'payload':>8} {'reference':>12} {'observed':>12} {'residue':>12}")
    for (label, reference), payload in zip(cases(), payloads):
        if payload == DOMAIN_SENTINEL:
            print(f"{label:31} {'--':>8} {reference_text(reference):>12} "
                  f"{'domain':>12} {'domain':>12}")
            continue
        observed = decode(name, payload)
        residue = observed - reference
        digits = 4 if name == "Float16" else 2
        print(f"{label:31} 0x{payload:0{digits}x} {reference_text(reference):>12} "
              f"{dyadic(observed):>12} {reference_text(residue):>12}")

    print()
    print("Shared Dakota fixture:")
    print("  the established E3M2 Jacobian/direction payloads are decoded once;")
    print("  those numerical values are then encoded independently in every format")
    print("  before every multiply/add is executed and requantized in that format.")
    print("  rotation inputs are the same for all formats: cos=7/8, sin=3/8, vector=[3,4].")
    print("  caster multiplier input is the same for all formats: 3/2.")
    if name == "E5M3":
        print("  E5M3 is unsigned positive-normal storage; zero/negative Jacobian inputs")
        print("  are reported as domain rather than silently omitted or assigned fake encodings.")
        print("  E5M3 arithmetic here is test-only: storage decode -> Float32 op -> storage encode.")
    print()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("qemu_arm")
    parser.add_argument("executable")
    parser.add_argument("--format", choices=FORMATS)
    args = parser.parse_args()

    run = subprocess.run(
        [args.qemu_arm, "-cpu", "cortex-a9", args.executable],
        capture_output=True, check=False
    )
    if run.returncode != 0:
        sys.stderr.write(run.stderr.decode("utf-8", "replace"))
        raise SystemExit(f"observer executable exited {run.returncode}")

    expected = len(FORMATS) * CASES_PER_FORMAT * BYTES_PER_CASE
    if len(run.stdout) != expected:
        raise SystemExit(f"observer emitted {len(run.stdout)} bytes, expected {expected}")

    blocks: dict[str, list[int]] = {}
    block_size = CASES_PER_FORMAT * BYTES_PER_CASE
    for index, name in enumerate(FORMATS):
        block = run.stdout[index * block_size:(index + 1) * block_size]
        blocks[name] = [
            int.from_bytes(block[offset:offset + 2], "little")
            for offset in range(0, block_size, 2)
        ]

    selected = FORMATS if args.format is None else [args.format]
    for name in selected:
        observe(name, blocks[name])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
