# KPT (Keep, Problem, Try)

**Date:** 2026-11-06
**Task/Skill:** bugfix

## Keep
- Rapidly creating a reproduction test in `tests/` directory.
- Using `scripts/quality_guard.sh` to ensure no regressions in linting or formatting.

## Problem
- The test name `test_calculate_sum_adds_correctly` was descriptive of the *intention*, but didn't explicitly state the *expected value* in a way that makes failure logs even more obvious at a glance.

## Try
- **Target Skill:** docs/skills/bugfix.md
- **Problem:** Test names could be more descriptive regarding specific expected values.
- **Cause:** Current skill doesn't mandate a specific naming convention for test assertions.
- **Proposed Improvement:** Add a rule to `bugfix.md` that test names must follow a pattern like `test_[function]_[expected_outcome]`.
- **Expected Effect:** Failure logs will be immediately more readable.

## Metrics
- **Implementation Time:** 5m
- **Test Result:** PASS
- **Quality Guard Result:** PASS
- **Token Consumption:** ~500 tokens
- **Estimated Cost:** $0.01
