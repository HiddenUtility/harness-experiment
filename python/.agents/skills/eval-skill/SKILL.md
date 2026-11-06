---
name: eval-skill
description: スキルの改善案が、品質と安全性を満たしているかを評価するスキル。
---

#  eval-skill

## Description
Evaluates the quality and effectiveness of an existing skill by applying it to specific tasks and measuring performance against defined criteria.

## Prerequisites
- Access to the skill being evaluated (`SKILL.md`).
- A set of evaluation tasks (past tasks or safe simulation tasks).
- Ability to record and compare results.

## Workflow
1. **Identify Target**: Select the skill and version to be evaluated.
2. **Prepare Task**: Define the task(s) to be used for evaluation.
3. **Execute Skill**: Run the target skill on the prepared task(s).
4. **Analyze Results**: Compare the output/outcome against the evaluation criteria.
5. **Evaluate Criteria**:
    - **Reproducibility**: Does the skill work consistently across similar tasks?
    - **Improvement**: Does it resolve issues identified in previous versions?
    - **Side Effects**: Does it introduce new bugs or unexpected behaviors?
6. **Generate Report**: Create an evaluation report in `docs/dryrun-reports/` using the template.
7. **Determine Outcome**: Mark as PASS, FAIL, or N/A based on findings.

## Rules & Constraints
- **NEVER** mark an evaluation as PASS without actual evidence/execution.
- **ALWAYS** use the standard evaluation report template.
- **DO NOT** ignore unexpected side effects.
- **DO NOT** skip the reproducibility check.

## Outputs
- Evaluation report (`docs/dryrun-reports/...`).
- Final Pass/Fail determination.
