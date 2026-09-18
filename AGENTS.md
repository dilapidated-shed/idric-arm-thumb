# Agent instructions

Apply the shared evidence and acceptance guardrails in
`isomorphisms/ai-ci/AGENTS.md`.

## Keep this repository ARM/Thumb-specific

This repository owns the ARM/Thumb backend. Do not stack DEX/ART, JNI launcher,
or application-specific Android work onto an ARM/Thumb branch merely because an
existing ARM branch already has useful CI or compiler plumbing.

ARM/QEMU acceptance is not DEX/ART acceptance, and a DEX branch inheriting ARM
history does not make the two backends one architecture. Put a distinct backend
on its own repository/branch boundary unless the current architecture explicitly
integrates them.

## Prove the native backend being claimed

An ARM/Thumb backend claim must bind the exact Idriç/compiler contract to the
exact backend head and inspect or execute the ARM/Thumb artifact required by the
task.

Generated C, RefC, a host implementation, a JNI shell, a simulator for another
ISA, or a handwritten equivalent may be useful as an oracle or bootstrap, but
it is not native ARM/Thumb backend evidence when the native path is the claim.

Temporary application harnesses must remain replaceable and must not define the
generic backend interface merely because they were the first executable path.

## Human phone acceptance

When asking the human to run a terminal block on a phone and paste the result
back, follow the shared ai-ci color convention: make section headings and
PASS/FAIL/action markers visually distinct with ANSI color when supported, while
keeping machine-readable receipt lines plain and never relying on color alone.


## Typecheck compiler-facing changes before push

For any change that touches `src/Backend/DEX/*.idr`, `backend.ipkg`, or other
compiler-facing DEX code, run the repository preflight against the declared
current Idriç checkout before pushing the branch:

```sh
make preflight IDRIC=/path/to/idris2 IDRIC_REPO=/path/to/Idric
```

Do not use pull-request CI as the first typecheck. A failing package typecheck or
driver build means the branch is not ready to push or advance. Record the exact
backend and Idriç SHAs with any acceptance claim.

The preflight proves only that the backend package typechecks and its driver
builds. It does not establish DEX generation, parser validation, ART execution,
emulator acceptance, or physical-device acceptance.
