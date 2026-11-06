---
name: retro
description: 業務スキル実行後の振り返りを行い、KPTを記録するスキル。
---



# retro

## Description
Conducts a retrospective (KPT) after the execution of a business skill to continuously improve processes and skills.

## Prerequisites
- Execution logs, test results, and quality guard results from the completed task.
- Access to the retrospective template.

## Workflow
1. **Collect Data**: Gather all relevant data from the recent task execution (logs, test results, quality guard output, token usage, etc.).
2. **Analyze**: Conduct a KPT analysis.
    - **Keep**: What went well? What should we continue?
    - **Problem**: What went wrong? What was inefficient?
    - **Try**: What concrete improvements can we make?
3. **Detail 'Try'**: For each 'Try', specify:
    - Target Skill
    - Problem encountered
    - Root cause
    - Proposed improvement
    - Expected effect
4. **Record KPT**: Create a new file in `docs/retrospectives/` using the template.
5. **Trigger Improvement**: Execute the `improve-skill` skill.

## Rules & Constraints
- **FACT-BASED**: Distinguish between observed facts and guesses.
- **COMPLETE**: Ensure all metrics (time, tokens, etc.) are recorded if available.
- **ACTIONABLE**: 'Try' items must be specific and actionable.
- **NO** skipping the improvement trigger.

## Outputs
- KPT retrospective report (`docs/retrospectives/...`).
- Triggering of the `improve-skill` skill.
