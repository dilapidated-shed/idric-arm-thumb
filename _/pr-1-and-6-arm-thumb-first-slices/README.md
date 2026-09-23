# PR #1 + PR #6 archive — first ARM/Thumb slices

This directory preserves the combined native ARM/Thumb line represented by:

- PR #1 — **Verify Idriç runtime-free ARM Thumb numerical backend slice**
- PR #6 — **Bootstrap first executable PrintASCII ARM/Thumb program**

PR #6 was merged into the branch that PR #1 points at. The resulting exact head is `7bc8d71e76d2b75028f923dc7655ab245d4d0cf8`, and that is also the current `arm-thumb-test-suite` branch. In other words, the two pieces are already one historical code state.

This archive is reference material under the top-level `_/` directory. It is not the active DEX `main` line and should not be merged wholesale into DEX.

Files:

- `PURPOSE.md` — what #1 and #6 were trying to prove.
- `CONTEXT.md` — why the branch exists separately from DEX and how #6 became part of #1.
- `STATUS-2026-09-23.md` — current topology and the remaining reconciliation problem.
- `ORIGINAL-PRS.md` — original PR descriptions and metadata.
- `COMMITS.md` — all commits reachable through the PR #1 history recorded by GitHub.
- `code/` — the complete file snapshot at exact head `7bc8d71e76d2b75028f923dc7655ab245d4d0cf8`.

Do not treat code under this directory as current implementation merely because it is preserved.
