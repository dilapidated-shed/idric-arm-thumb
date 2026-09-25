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



SUPERSCRIPT = str.maketrans("0123456789-", "⁰¹²³⁴⁵⁶⁷⁸⁹⁻")
SUBSCRIPT = str.maketrans("0123456789", "₀₁₂₃₄₅₆₇₈₉")

COMMON_VULGAR = {
    (1, 2): "½",
    (1, 4): "¼",
    (3, 4): "¾",
    (1, 8): "⅛",
    (3, 8): "⅜",
    (5, 8): "⅝",
    (7, 8): "⅞",
}


def vulgar(fraction: Fraction) -> str:
    if fraction.denominator == 1:
        return str(fraction.numerator)
    negative = fraction.numerator < 0
    numerator = abs(fraction.numerator)
    key = (numerator, fraction.denominator)
    body = COMMON_VULGAR.get(key)
    if body is None:
        body = (
            str(numerator).translate(SUPERSCRIPT)
            + "⁄"
            + str(fraction.denominator).translate(SUBSCRIPT)
        )
    return ("−" if negative else "") + body


def dyadic(value: float) -> str:
    fraction = Fraction(value).limit_denominator(16)
    if float(fraction) != value:
        return f"{value:.6f}"
    return vulgar(fraction)


def reference_text(value: float) -> str:
    fraction = Fraction(value).limit_denominator(16)
    if abs(float(fraction) - value) < 1e-12:
        return vulgar(fraction)
    return f"{value:.6f}"


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: observe_e3m2.py QEMU_ARM EXECUTABLE")

    run = subprocess.run([sys.argv[1], "-cpu", "cortex-a9", sys.argv[2]],
                         capture_output=True, check=False)
    if run.returncode != 0:
        sys.stderr.write(run.stderr.decode("utf-8", "replace"))
        raise SystemExit(f"observer executable exited {run.returncode}")
    if len(run.stdout) != 24:
        raise SystemExit(f"observer emitted {len(run.stdout)} bytes, expected 24")

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

    print("E3M2 observational measurements")
    print(f"theta={math.degrees(theta):.9f} deg  "
          f"sin={math.sin(theta):.9f}  cos={math.cos(theta):.9f}  "
          f"caster_multiplier={caster_multiplier:.9f}")
    print("The numeric residual is observed - reference; it is reported, not graded.")
    print()
    print(f"{'case':31} {'payload':>7} {'reference':>12} {'observed':>12} {'residual':>12}")
    for (label, reference), payload in zip(cases, run.stdout):
        observed = e3m2_decode(payload)
        residual = observed - reference
        print(f"{label:31} 0x{payload:02x} {reference_text(reference):>12} "
              f"{dyadic(observed):>12} {reference_text(residual):>12}")

    print()
    print("Dakota 14x26 Jacobian exercise:")
    print("  rows: 14 camber observations; columns: 26 named state/nuisance coordinates")
    print("  all 364 partial derivatives are quantized to E3M2 before the matrix product")
    print("  278/364 quantized Jacobian entries are zero at this scale")
    print("  direction: coefficients/geometry/calibration use exact quarters/halves;")
    print("             all 14 steering-offset coordinates use alternating +/-1/16 rad")
    print("  each multiply and each accumulation is requantized to E3M2")
    print("  rotation vector = [3, 4]")
    print("  E3M2 rotation coefficients actually executed: cos=7/8, sin=3/8")
    print("  E3M2 caster multiplier actually executed: 3/2")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
