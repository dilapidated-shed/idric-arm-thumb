#!/usr/bin/env python3
import math
from fractions import Fraction
import subprocess
import sys


def e3m2_decode(payload: int) -> float:
    payload &= 0x3F
    sign = -1.0 if payload & 0x20 else 1.0
    code = payload & 0x1F
    exponent = code >> 2
    mantissa = code & 0x03
    if exponent == 0:
        value = math.ldexp(mantissa / 4.0, -2)
    else:
        value = math.ldexp(1.0 + mantissa / 4.0, exponent - 3)
    return sign * value



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


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: observe_e3m2.py QEMU_ARM EXECUTABLE")

    run = subprocess.run([sys.argv[1], "-cpu", "cortex-a9", sys.argv[2]],
                         capture_output=True, check=False)
    if run.returncode != 0:
        sys.stderr.write(run.stderr.decode("utf-8", "replace"))
        raise SystemExit(f"observer executable exited {run.returncode}")
    if len(run.stdout) != 12:
        raise SystemExit(f"observer emitted {len(run.stdout)} bytes, expected 12")

    theta = math.radians(360.0 / 17.4)
    caster_multiplier = 1.0 / (2.0 * math.sin(theta))

    front = 1.0
    rear = -0.5
    jacobian_camber = -1.3 * front + -0.7 * rear
    jacobian_caster = -1.0 * front + 1.0 * rear

    x = 3.0
    y = 4.0
    rotated_x = math.cos(theta) * x - math.sin(theta) * y
    rotated_y = math.sin(theta) * x + math.cos(theta) * y

    cases = [
        ("add 1.5 + 0.5", 1.5 + 0.5),
        ("subtract 1.5 - 0.5", 1.5 - 0.5),
        ("multiply 1.5 * 0.5", 1.5 * 0.5),
        ("divide 1.5 / 0.5", 1.5 / 0.5),
        ("power 1.5^2", 1.5 ** 2),
        ("power 1.5^3", 1.5 ** 3),
        ("sqrt 2", math.sqrt(2.0)),
        ("Jacobian delta camber", jacobian_camber),
        ("Jacobian delta caster", jacobian_caster),
        ("rotate (3,4) x", rotated_x),
        ("rotate (3,4) y", rotated_y),
        ("caster from 4-degree swing", 4.0 * caster_multiplier),
    ]

    print("E3M2 observational measurements")
    print(f"theta={math.degrees(theta):.9f} deg  "
          f"sin={math.sin(theta):.9f}  cos={math.cos(theta):.9f}  "
          f"caster_multiplier={caster_multiplier:.9f}")
    print("The numeric residue is observed - reference; it is reported, not graded.")
    print()
    print(f"{'case':31} {'payload':>7} {'reference':>12} {'observed':>12} {'residue':>12}")
    for (label, reference), payload in zip(cases, run.stdout):
        observed = e3m2_decode(payload)
        residue = observed - reference
        print(f"{label:31} 0x{payload:02x} {reference_text(reference):>12} "
              f"{dyadic(observed):>12} {reference_text(residue):>12}")

    print()
    print("Physical inputs before E3M2 quantization:")
    print("  adjustment Jacobian = [[-1.3, -0.7], [-1, 1]], vector = [1, -0.5]")
    print("  rotation vector = [3, 4]")
    print("  E3M2 rotation coefficients actually executed: cos=7/8, sin=3/8")
    print("  E3M2 caster multiplier actually executed: 3/2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
