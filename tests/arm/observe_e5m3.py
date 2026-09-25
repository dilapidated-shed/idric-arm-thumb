#!/usr/bin/env python3
import math
from fractions import Fraction
import struct
import subprocess
import sys


def short_number(value: float) -> str:
    fraction = Fraction(value).limit_denominator(256)
    if float(fraction) == value:
        if fraction.denominator == 1:
            return str(fraction.numerator)
        return f"{fraction.numerator}/{fraction.denominator}"
    return f"{value:.6f}"


def reference_text(value: float) -> str:
    fraction = Fraction(value).limit_denominator(256)
    if abs(float(fraction) - value) < 1e-12:
        if fraction.denominator == 1:
            return str(fraction.numerator)
        return f"{fraction.numerator}/{fraction.denominator}"
    return f"{value:.6f}"


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: observe_e5m3.py QEMU_ARM EXECUTABLE")

    run = subprocess.run([sys.argv[1], "-cpu", "cortex-a9", sys.argv[2]],
                         capture_output=True, check=False)
    if run.returncode != 0:
        sys.stderr.write(run.stderr.decode("utf-8", "replace"))
        raise SystemExit(f"observer executable exited {run.returncode}")
    if len(run.stdout) != 96:
        raise SystemExit(f"observer emitted {len(run.stdout)} bytes, expected 96")

    observed_values = struct.unpack("<24f", run.stdout)

    theta = math.radians(360.0 / 17.4)
    caster_multiplier = 1.0 / (2.0 * math.sin(theta))

    jacobian_rows = [
        ("driver.camber[0]", 0.5451388472381876),
        ("driver.camber[1]", 0.5927113334029114),
        ("driver.camber[2]", 0.4895670078008919),
        ("driver.camber[3]", 0.5289665323810473),
        ("driver.camber[4]", 0.45372048698916667),
        ("driver.camber[5]", 0.4731549501099014),
        ("driver.camber[6]", 0.42261242702714896),
        ("passenger.camber[0]", -0.15357695334574295),
        ("passenger.camber[1]", -0.08165240496535331),
        ("passenger.camber[2]", -0.05029350042927705),
        ("passenger.camber[3]", 0.018128930745486826),
        ("passenger.camber[4]", -0.0026210159607702455),
        ("passenger.camber[5]", 0.058420594931340275),
        ("passenger.camber[6]", -0.046822717143564785),
    ]

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
    ] + [("Jv " + name, value) for name, value in jacobian_rows] + [
        ("rotate (3,4) x", rotated_x),
        ("rotate (3,4) y", rotated_y),
        ("caster from 4-degree swing", 4.0 * caster_multiplier),
    ]

    print("E5M3 storage observations")
    print(f"theta={math.degrees(theta):.9f} deg  "
          f"sin={math.sin(theta):.9f}  cos={math.cos(theta):.9f}  "
          f"caster_multiplier={caster_multiplier:.9f}")
    print("The numeric residual is observed - reference; it is reported, not graded.")
    print()
    print(f"{'case':31} {'reference':>12} {'observed':>12} {'residual':>12}")
    for (label, reference), observed in zip(cases, observed_values):
        residual = observed - reference
        print(f"{label:31} {reference_text(reference):>12} "
              f"{short_number(observed):>12} {reference_text(residual):>12}")

    print()
    print("E5M3 storage contract exercised:")
    print("  arithmetic: E5M3 inputs -> Float32 operation -> E5M3 storage -> Float32 observation")
    print("  Jacobian: nonzero magnitudes are E5M3; signs and structural zeros are separate metadata")
    print("  Jacobian multiply/accumulate remains Float32; signed Jv outputs are not forced into unsigned E5M3")
    print("  rotation and caster use the same physical inputs as the E3M2 observations")
    print("  no native E5M3 arithmetic contract is introduced")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
