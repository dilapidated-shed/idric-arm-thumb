# Agent instructions

Apply the shared evidence and acceptance guardrails in
`isomorphisms/ai-ci/AGENTS.md`.

## Keep the current DEX line independent

Despite the historical repository name, current `main` owns the direct DEX
backend. The ARM/Thumb development line is separate history. Do not route DEX
lowering, encoding, packaging, or acceptance through ARM/Thumb implementation
layers merely because this repository once carried ARM work.

ARM/QEMU acceptance is not DEX/ART acceptance. DEX/ART, JNI launchers, and
application-specific Android adapters must also remain distinct layers:
application adapters may consume direct DEX output without defining the generic
DEX compiler interface.

Run `tests/dex/branch-separation.sh` for source, package, Makefile, or workflow
changes. It rejects tracked ARM implementation paths, ARM/Thumb imports or build
dependencies anywhere in the DEX sources, ARM development ancestry, and leakage
of application adapters into the generic DEX package.

## Prove the DEX backend being claimed

A DEX backend claim must bind the exact Idriç/compiler contract to the exact
backend head and inspect or execute the DEX artifact required by the task.

Generated C, RefC, an ARM artifact, a JNI shell, or a handwritten Smali
equivalent may be useful as an oracle or bootstrap, but it is not
compiler-generated direct DEX evidence when the direct DEX path is the claim.
Host parsing/validation, Android emulator execution, and physical phone/tablet
execution remain separate evidence classes.

Temporary application harnesses must remain replaceable and must not define the
generic backend interface merely because they were the first executable path.

## Human phone acceptance

When asking the human to run a terminal block on a phone and paste the result
back, follow the shared ai-ci color convention: make section headings and
PASS/FAIL/action markers visually distinct with ANSI color when supported, while
keeping machine-readable receipt lines plain and never relying on color alone.
