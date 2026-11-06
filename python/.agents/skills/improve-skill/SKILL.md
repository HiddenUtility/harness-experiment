---
name: improve-skill
description: 振り返り (retro) の Try をもとに、既存スキルを改善するスキル。
---

# improve-skill

## Description
Creates improvement proposals for existing skills based on retrospective findings (Try items) and validates them through evaluation.

## Prerequisites
- The latest retrospective report (`docs/retrospectives/...`).
- The target skill definition (`SKILL.md`).
- Access to the `eval-skill` tool.

## Workflow
1. **Read Retrospective**: Load the most recent retrospective file.
2. **Identify Targets**: Extract 'Try' items that target specific skills.
3. **Analyze Current Skill**: Read the target skill's `SKILL.md`.
4. **Verify Consistency**: Ensure the proposed improvement aligns with existing project rules.
5. **Draft Improvement**: Create a concrete improvement plan.
6. **Generate Diff**: Prepare a clear diff (before/after) of the proposed change.
7. **Evaluate Improvement**: Execute the `eval-skill` to validate the new version of the skill.
8. **Decision**:
    - If **PASS**: Create a Pull Request for the improvement.
    - If **FAIL**: Refine the plan or document the failure and stop.

## Rules & Constraints
- **DO NOT** overwrite existing skills blindly; always use a diff/PR approach.
- **DO NOT** generalize specific task nuances into broad, invalid rules.
- **DO NOT** introduce duplicate rules.
- **ENSURE** improvements are specific, actionable, and reproducible.
- **ENSURE** important constraints and prohibitions are placed prominently in the updated skill.
- **NEVER** skip the evaluation step.

## Outputs
- Improvement proposal (diff).
- Triggering of `eval-skill`.
- Pull Request (if PASS).
