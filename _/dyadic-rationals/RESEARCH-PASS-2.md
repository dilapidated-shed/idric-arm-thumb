# Second research pass: dyadic arithmetic

This pass broadens the earlier HoTT/Lean/ConwayHs notes into exact-real arithmetic, verified numerics, and alternative radix work.

## Krebbers and Spitters

- *Computer certified efficient exact reals in Coq* (2011), arXiv:1105.2751.
- *Type classes for efficient exact real arithmetic in Coq* (LMCS 2013), arXiv:1106.3448.
- They explicitly replace ordinary rationals with dyadics built from machine integers and report roughly 100x faster basic operations than the earlier Coq implementation.
- Their carrier is essentially integer mantissa plus integer power-of-two exponent.
- Exact ring operations are paired with explicit approximate division and approximation at a requested power-of-two precision.

Sources:
https://arxiv.org/abs/1105.2751
https://arxiv.org/abs/1106.3448
https://robbertkrebbers.nl/research/reals/

## Bauer and Kavkler: RZ / exact reals

- *Implementing Real Numbers With RZ* (2008).
- *A constructive theory of continuous domains suitable for implementation* (2009).
- They argue that ordinary rationals are expensive because numerator and denominator grow, while dyadics are cheaper in memory and basic +, -, * arithmetic.
- Dyadics are treated as an ordered ring rather than a field; approximate division is enough.
- Their exact-real layer uses dyadic intervals and deliberately allows outward approximation/normalization to keep mantissas small.

Sources:
https://www.sciencedirect.com/science/article/pii/S1571066108001321
https://math.andrej.com/2007/04/12/implementing-real-numbers-with-rz/
https://math.andrej.com/wp-content/uploads/2008/01/constructive-domains.pdf

## iRRAM

iRRAM is a production-oriented C++ exact-real system with an explicit DYADIC type and precision-parameterized arithmetic.

Pinned public source inspected:
realcomputation/iRRAM@35c1a7c3069698a1ca20aea3ede51d7f2c39d337

Relevant files:
- include/iRRAM/DYADIC.h
- src/DYADIC.cc

The public API exposes ADD, SUB, MULT, and DIV with an explicit precision argument, plus exact comparisons. The implementation is backed by MPFR.

Sources:
http://irram.uni-trier.de/
https://github.com/realcomputation/iRRAM
https://members.loria.fr/PZimmermann/irram18.pdf

## MPFR

MPFR is not an exact-real package, but every regular finite MPFR value is a radix-2 floating value with sign, arbitrary-precision normalized significand, and integer exponent. Mathematically those finite values are dyadic rationals.

This is useful precedent for separating:
- the dyadic value representation;
- the chosen finite significand precision;
- the rounding rule of an operation.

Source:
https://mpfr.org/mpfr-current/mpfr.html

## Martin Escardo: dyadic rational streams

Escardo's 2000 exact-real material explicitly studies dyadic digits a/2^b and the pair representation (a,b). It recommends the same finite canonicalization seen in Lean: zero as (0,0), otherwise make the numerator odd and the denominator exponent minimal.

It also gives an important warning: dyadic streams can simplify some algorithms but can suffer digit swell; redundant signed-binary streams may be better for some exact-real operations.

Sources:
https://www.dcs.ed.ac.uk/home/mhe/plume/node27.html
https://www.dcs.ed.ac.uk/home/mhe/plume/node28.html
https://www.dcs.ed.ac.uk/home/mhe/plume/node45.html

## Russell O'Connor

O'Connor's completion-monad exact-real work is the immediate predecessor that Krebbers/Spitters optimized.

Sources:
https://arxiv.org/abs/cs/0605058
https://arxiv.org/abs/0805.2438

The comparison matters: dyadics are an implementation improvement in the dense finite approximation layer, not a mathematical requirement for the outer real-number semantics.

## Keith Briggs / scaled integers

Keith Briggs' 2006 exact-real implementation work uses a scaled-integer model with an implicit denominator/precision. This gives another useful representation family:

    integer payload + shared or implicit binary scale

rather than attaching an independently normalized exponent to every value.

Sources:
https://www.sciencedirect.com/science/article/pii/S0304397505006080
https://keithbriggs.info/documents/xr-paper2.pdf

## Steinberg, Thery, and Thies

Formal computable-analysis work in Coq presents intervals with dyadic endpoints as an efficient alternative to general rational approximations. This reinforces the rule that approximation/error should be represented structurally by containment and interval width rather than reconstructed from decimal output.

Sources:
https://arxiv.org/abs/1904.13203
https://staff.aist.go.jp/reynald.affeldt/coq2019/coqws2019-steinberg-thies-slides.pdf

## Nicolas Julien: arbitrary integer radix

*Certified Exact Real Arithmetic Using Co-induction in Arbitrary Integer Base* (FLOPS 2008) generalizes certified signed-digit real arithmetic from base 2 to arbitrary integer bases.

This matters for the dyadic/triadic question: base 2 is mechanically privileged on ARM, but it is not mathematically forced. A base-3 representation is a legitimate sibling semantic design with a different lowering cost.

DOI: 10.1007/978-3-540-78969-7_6

## Design conclusion

The broader literature converges on three separate notions that we should not collapse:

1. semantic exact dyadic value;
2. canonical serialized form, often odd numerator plus power-of-two exponent;
3. bounded working approximation chosen for a requested precision/error budget.

Lean strongly supports canonical exact finite dyadics. RZ and iRRAM strongly support precision-bounded working dyadics that may be deliberately rounded to control representation growth.

For the first ARM experiment, the finite exact dyadic type remains small: integer numerator/mantissa, binary exponent, shifts for scale alignment, integer multiply, and explicit bounded division later.

Do not inherit an exact-real stream/completion architecture unless a consumer actually needs arbitrary real numbers.
