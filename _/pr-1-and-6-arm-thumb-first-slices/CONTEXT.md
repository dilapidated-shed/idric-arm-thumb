# Historical context

PR #1 opened on 2026-08-26 against an early `main` and accumulated the first native ARM/Thumb backend implementation and verification suite.

The branch reached a useful checkpoint at commit `ff8fa96ec7c5ecf89baa0a1e9796585bf47081db`, **“docs: describe ARM Thumb backend test suite.”**

From there, PR #6 added the character/UTF-8 specification fixtures and the first executable `PrintASCII` bootstrap path. PR #6 eventually merged into `arm-thumb-test-suite` at commit `7bc8d71e76d2b75028f923dc7655ab245d4d0cf8`. PR #1's head is that exact same commit, so PR #1 already contains PR #6.

Later, the repository acquired a distinct direct-DEX line. Current `main` belongs to that sibling backend line rather than being the natural target for old ARM/Thumb work. This is why a normal merge of PR #1 into current `main` is the wrong operation even though the native branch itself remains valuable.

There is a second native branch, `branching-dispatch-fixtures`, which also descends from the ARM test-suite era but developed independently. From the `ff8fa96…` checkpoint:

- `arm-thumb-test-suite` is 19 commits ahead and 0 behind that checkpoint;
- `branching-dispatch-fixtures` is 66 commits ahead and 0 behind that checkpoint.

The latter carries branching fixtures plus framebuffer, speaker, and GPIO oracle work. The former carries the PrintASCII/character line represented by #1 + #6.

No top-level comments or inline review threads were present on PR #1 or PR #6 when this archive was made, so the context is carried by the PR descriptions, commit history, code comments, and tests.
