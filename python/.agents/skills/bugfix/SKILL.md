---
name: bugfix
description: 不具合を再現するテストを先に書き、最小修正でグリーンに戻すワークフロー。python + pytest 前提。
---

# bugfix

## Description
Standardizes the process of identifying, reproducing, and fixing bugs to ensure high quality and prevent regressions.

## Prerequisites
- Access to bug reports/issues.
- Environment with `pytest` and `ruff` configured.
- Ability to create and run tests.

## Workflow
1. **Analyze Bug Report**: Organize symptoms, reproduction steps, expected results, and actual results.
2. **Investigate**: Locate relevant code and specification/documentation.
3. **Confirm Specification**: Clarify the intended behavior to avoid guesswork.
4. **Formulate Hypothesis**: Propose a likely cause for the bug.
5. **Create Reproduction Test**: Write a `pytest` test case that reproduces the bug.
6. **Verify Failure**: Confirm that the test fails as expected.
7. **Implement Fix**: Apply the minimal necessary code changes.
8. **Verify Fix**: Run the reproduction test and ensure it passes.
9. **Run Quality Guard**: Execute `python scripts/quality_guard.py` to ensure no regressions or linting issues.
10. **Document**: Record the investigation, fix, and verification results.
11. **Trigger Retro**: Execute the `retro` skill to reflect on the process.

## Rules & Constraints
- **NO** fixing without a reproduction test.
- **NO** fixing based on assumptions; always confirm the specification.
- **NO** unrelated refactoring during bug fixing.
- **NO** excessive changes; keep the fix minimal and focused.
- **NO** marking as complete without running tests and quality guard.
- **NO** ignoring quality guard failures.

## Outputs
- Bug fix implementation (code changes).
- Reproduction test case.
- Documentation of the fix.
- Triggering of the `retro` skill.
