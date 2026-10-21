# Evidence for the nine revised checklist dimensions

Prepared and sources checked on 2026-10-21, Asia/Seoul.

This draft explains the 24 checklist items in dimensions 1 through 6 and 8 through 10 of the [assessment rubric](../Sources/VibemetricCore/Resources/rubric.md). Testing & Evals is outside this revision. The rubric contains the operational recognition, nonmatch, unknown-evidence, and counting definitions used by the assessor. This document records their origin, research support, and limits.

The items reconstruct behavior described in the earlier rubric and the project's Deep Dive HABIT and SETUP material. They do not turn every habit or setup into a separate score. The public baseline is [rubric revision 9e23408](https://github.com/vibemetric-app/vibemetric/blob/9e23408680d40eaac6dde0f6d8bd3f74a5919578/Sources/VibemetricCore/Resources/rubric.md). Internal Deep Dive material supplied design context; the public research below supplies independently inspectable support. Neither origin makes the checklist a validated measure of personal ability.

## What the checklist measures

Each item names an action that can be changed separately. File ownership, installations, document length, tool names, worker counts, and AI completion claims do not establish that action. An adopted procedure can qualify through AI execution, but an autonomous AI decision does not establish the person's own judgment.

| Dimension | Items | Behavior retained from the earlier material |
| --- | --- | --- |
| Planning & Specs | 3 | Communicate the outcome and completion check; resolve material open choices; communicate known preservation constraints. |
| Context Engineering | 2 | Apply needed project source information; update guidance affected by project changes. |
| Memory & Knowledge | 3 | Save reusable information with scope; correct or retire wrong entries; confirm accurate later reuse without restatement. |
| Tool Integration | 3 | Use connected tools in real work; save and reuse repeated procedures; update and use procedures after interface changes. |
| Task Mapping | 2 | Assign necessary parts before execution; pass actual outputs onward and combine the deliverable. |
| Feedback Loops | 3 | Act on failure and examine the changed result; handle blockers; change and exercise prevention for a recurring cause. |
| Human Steering | 2 | Examine evidence before choosing an approach or scope; communicate an observed difference and intended correction, then follow application. |
| Security | 3 | Enforce needed access limits; protect secret handling; check changed security boundaries and classify findings accurately. |
| Efficiency & Cost | 3 | Choose resources for required quality; count whole-workload resources and outcomes; apply comparable results to later choices. |

Outcome definition and completion-check definition are one Planning item because they are parts of the same execution handoff. Multiple-client context consistency is a condition of information delivery, not a separate item that penalizes single-client users. A saved procedure can qualify when explicitly named; automatic discovery is not required. Single-agent sequential work can satisfy Task Mapping. Distribution of a tool to other people is not a prerequisite for an individual's work practice.

## Recognition and numerical rules

The rubric gives each item its own relevant-task denominator. Establish the opportunity before searching for positive examples. For example, a known recurring procedure with an observed failure to save or reuse it remains in Tool Integration's denominator; selecting only tasks that already use saved skills would inflate the rate.

For the nine revised dimensions, keep four observation classes:

| Class | Required evidence | Treatment |
| --- | --- | --- |
| Matching | The item's action and required application are connected in the record. | Include in the numerator and observed denominator. |
| Observed nonmatching | A contrary action or omission is established by a sufficiently complete relevant record. | Include only in the observed denominator. |
| Unknown | The opportunity exists, but the needed request, action, application, or follow-up is inaccessible or incomplete. | Exclude from the observed rate and report as unknown. |
| Excluded | No relevant opportunity exists, such as no changed memory or no later reuse opportunity. | Report separately with the reason. |

For example, six matching tasks, two observed nonmatching tasks, and two unknown tasks yield:

- Observed rate = 6 / 8 = 75%.
- Evidence coverage = 8 / 10 = 80%.

That is not evidence that the practice occurred in 75% of all work. Neither rate exists when its denominator is zero. Unknown evidence must not become a failure or a successful assumption.

One requested deliverable or change is one task. Retries, child sessions, and repeated log entries do not create extra tasks. Within a task, any confirmed violation makes that item's task nonmatching; otherwise missing required evidence makes it unknown; all observed opportunities satisfying the definition make it matching. This aggregation rule is provisional. Preserve raw opportunity counts so a later reviewer can inspect it. For recurring-cause groups and resource-comparison sets, identify the member tasks and count the group once.

### Provisional choices

No source reviewed below validates any of these as a mastery boundary:

| Operating choice | Status and limitation |
| --- | --- |
| Do is Met at 50% of judgeable tasks, with at least two matching tasks. | Provisional. The threshold and two-match minimum are not measured skill boundaries. |
| Avoid is Met when the behavior occurs in at most 10% of judgeable tasks. | Provisional legacy rule. It does not imply a validated 90% positive-behavior cutoff. The nine revised dimensions use Do items. |
| At least two judgeable tasks are needed for an item status. | Provisional evidence floor, not a statistically sufficient sample size. |
| Equal item weights and score = 10 × Met / (Met + Not met), rounded half up. | Provisional scoring design. Two-item dimensions have coarser steps than three-item dimensions. |
| The 0–5, 6–7, and 8–10 bands. | Existing presentation bands, not calibrated levels of personal skill. |
| An observed violation takes precedence within a multi-opportunity task. | Provisional aggregation to prevent repeated messages from inflating the rate. Its effects need validation. |
| Feedback Loops item 3, executable prevention of a recurring cause. | Conditional candidate. Its separate quantitative effect is unconfirmed; recurrence and subsequent operation must be observed. |

Keep unknown and not-applicable items out of both counts in the score formula. If no item can be judged, the dimension is Not assessable. A Met status describes behavior under these operating rules. It does not establish that the person learned, that an artifact is safe, or that future work will succeed.

## Ownership of overlapping evidence

One exchange can show several distinct actions. Supplying a preservation constraint and enforcing a restricted database role are different actions. Renaming one correction as context, memory, and skill maintenance does not create three actions.

| Action | Scoring owner | Boundary |
| --- | --- | --- |
| Communicate outcome, choices, and known preservation requirements before execution | Planning | The actual check is Testing; effective access controls are Security. |
| Supply or correct project operating guidance | Context Engineering | A preference or past decision retained for later conversations is Memory; an executable tool procedure is Tool Integration. |
| Save, correct, or later apply scoped information | Memory & Knowledge | A maintenance event has one primary owner even if several file copies change. |
| Execute connected service work or maintain a reusable execution procedure | Tool Integration | The task dependency arrangement is Task Mapping; automatic E2E remains Testing. |
| Assign work units, pass artifacts, and combine them | Task Mapping | A later result-driven change of approach or assignment is Feedback Loops. |
| Take the next action based on a failure or blocker | Feedback Loops | A verification run alone supplies no additional match. Human domain judgment is Human Steering. |
| Make a human approach decision or communicate a correction | Human Steering | Do not score the same correction under both Human Steering items without distinct actions. Completion acceptance belongs to Testing; resource choices belong to Efficiency. |
| Enforce permissions, protect secrets, or check product security boundaries | Security | Secret scanning supports secret handling only. A discovered vulnerability can coexist with a matching checking action. |
| Choose, measure, and revise model or effort allocation | Efficiency & Cost | Do not count the same choice again as Human Steering. |

Testing & Evals is maintained separately. It owns evidence-based human completion acceptance, execution without a task-specific verification request, and AI-output evaluation. Correction, rechecking after failure, retry or stop rules, escalation, and recurring-cause prevention belong to Feedback Loops. A verification run can supply a result to that loop, but its execution alone must not earn or lose points twice.

An observed valid-secret exposure remains a nonmatch for that event after cleanup or rotation. Record recovery separately. The current-practice rule can recognize a later evidenced replacement practice without deleting the incident from the history. No research-derived safety score cap or additional hard stop is introduced here.

## Research support and limits

The summaries below report selected findings, not universal effects. None directly establishes that performing these 24 actions causes long-term improvement in a person's vibe-coding skill. Numerical findings retain the source's population, denominator, version, and comparison. Participant counts are not minimum sample sizes for this checklist.

### Planning, context, and memory

1. [Intent-misalignment study, v2](https://arxiv.org/html/2605.29442v2), 2026-08-31. Observational evidence from 20,574 sessions across 1,639 repositories includes 16,118 validated misalignment episodes. Among those episodes, 15.36% receive the underspecified-instruction cause label, 36.49% the instruction-following-failure cause label, and 38.33% the constraint-violation symptom label. Labels can overlap. These are not failure probabilities across all tasks. The findings support looking for missing requirements and preserved constraints, while showing that agents can also ignore stated instructions. They do not assign every misalignment to the user or measure this checklist's effect.

2. [Ambig-SWE, v3](https://arxiv.org/html/2502.13069v3), 2026-02-21. The benchmark hides information from SWE-bench Verified tasks and compares conditions that can query a proxy with access to the original information. It reports up to 74% relative improvement in resolution rate. This is not 74 percentage points. The benchmark has 500 tasks; the Sonnet 4 hidden-information condition uses 100. This supports recovery of material missing information in those conditions, not more questions for every request or a measured effect on human expertise.

3. [Effective context engineering](https://www.anthropic.com/research/effective-context-engineering-for-ai-agents), Anthropic, 2025-09-29. Vendor practice guidance describes relevant context, retrieval routes, and external notes. It supports examining what information reaches execution. It does not provide a universal optimal file length, file count, or effect size for guidance maintenance.

4. [AGENTS.md evaluation, v3](https://arxiv.org/html/2602.11988v3), 2026-09-29. The study compares four model/agent setups on 300 SWE-bench Lite tasks and 138 CTXbench tasks across 12 repositories. Generated context files did not produce statistically significant success differences in the reported comparisons, with p = 0.87 and p = 0.37, while average inference costs increased by 20% and 23%. The developer-file comparison against no file was also not significant, p = 0.21. This does not prove that guidance never helps. It argues against awarding points merely for file presence.

5. [LongMemEval, v2](https://arxiv.org/html/2410.10813v2), 2025-03-04. The full benchmark has 500 questions. A commercial-service pilot conducted in 2024-08 used 97 questions: full-history GPT-4o scored 91.84%, while ChatGPT memory scored 57.73%. These historical results distinguish retention from correct later use; they are not 2026 product performance or a coding-skill measure. The benchmark also tests updating remembered information.

6. [Mem0, v1](https://arxiv.org/html/2504.19413v1), 2025-04-28. This vendor benchmark uses ten long LoCoMo conversations. Its overall LLM-judge scores are approximately 67% for Mem0 and 73% for full-history input, while memory-based operation uses fewer tokens and less latency. The result supports measuring accuracy and resource tradeoffs rather than assuming memory is always better. It does not isolate a person's saving, scoping, or correction habits as a causal intervention.

### Tools, task mapping, and feedback

7. [SkillsBench, v4](https://arxiv.org/html/2602.12670v4), 2026-06-14. Across 87 tasks, 18 model/harness configurations, and three trials per task per condition, the reported average rises from 33.9% to 50.5% with curated skills. The 16 software-engineering tasks rise from 37.6% to 49.2%; 13 of 87 tasks worsen. This supports judging procedures by actual task results. It does not show that creating or installing a skill file improves human ability, or that automatic invocation is required.

8. [Writing tools for agents](https://www.anthropic.com/research/writing-tools-for-agents), Anthropic, 2025-09-11. Vendor guidance recommends inspecting task results, calls, returns, and errors when improving tool contracts and descriptions. It supports connected real use and maintenance based on operation. It provides no isolated quantitative effect for maintaining a saved tool procedure or increasing the number of integrations.

9. [Multi-agent research system](https://www.anthropic.com/research/multi-agent-research-system), Anthropic, 2025-06-13. The account describes duplicate searches and omissions with unclear delegation, and recommends clear objectives, outputs, and boundaries. Its overall system performance comparison changes models, token use, and architecture together, so it cannot quantify the isolated effect of a delegation instruction. The authors also describe limits for tasks with strong dependencies, including coding.

10. [Agent-architecture comparison, v3](https://arxiv.org/html/2512.08296v3), 2026-04-08. The study compares 260 configurations, six benchmarks, five architectures, and three model families. Relative performance changes vary by task and configuration, including +80.8% for decomposable financial reasoning and a 70.0% loss in one sequential-planning configuration. These are relative changes, not percentage-point gains. The result supports matching work structure to execution structure, not a universal benefit from more workers or a fixed team size.

11. [Reflexion, v4](https://arxiv.org/html/2303.11366v4), 2023-10-10. In 50 difficult Rust problems, the reported baseline is 60%, reflection without tests 52%, and tests with reflection 68%. Results also worsen in another Python benchmark. This supports examining the quality and effect of a feedback procedure, not assuming that reflection or retries help. It does not isolate E2E verification or human learning.

12. [Canarying releases](https://sre.google/workbook/canarying-releases/), Google SRE Workbook. Practice guidance uses observed comparison results to continue or stop a rollout and relates samples, duration, and metrics to the service and tolerated risk. It supports evidence-based blocker and stop decisions. Illustrative numbers are not a universal coding-agent retry limit or a personal mastery cutoff. No independent effect size was found for the checklist's recurring-cause prevention item.

### Human steering, security, and resources

13. [Exploratory vibe-coding study](https://arxiv.org/html/2512.22418v1), 2025 manuscript, FSE 2026. The material includes 20 videos, of which seven are coding streams; quantitative activity analysis uses five after excluding edited material. Qualitative examples describe concrete direction informed by code or structure and unproductive repetition without new information. This is not a 20-person controlled trial or a causal estimate for either Human Steering item.

14. [Guidelines for human-AI interaction](https://www.microsoft.com/en-us/research/wp-content/uploads/2019/01/Guidelines-for-Human-AI-Interaction-camera-ready.pdf), CHI 2019. Forty-nine practitioners applied 18 guidelines to 20 AI products to assess relevance and clarity. This supports explanation, clarification, and correction as design practices. It does not measure coding-user success rates or improvement from a particular correction format.

15. [Excessive agency](https://genai.owasp.org/llmrisk/llm062025-excessive-agency/), OWASP. This security guidance recommends limiting functions and permissions and enforcing authorization in downstream systems. It supplies a design basis for effective permission controls. It does not quantify risk reduction or define a personal coding-skill fulfillment rate.

16. [Secrets management cheat sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html), OWASP. The guidance covers protected storage and delivery, exclusion from ordinary logs, rotation, and revocation. It supports checking the actual secret-handling path and distinguishing recovery from the original exposure. It supplies no numerical learning effect or checklist threshold.

17. [Security user study](https://arxiv.org/html/2211.03622), CCS 2023. The study includes 47 participants, 33 using AI assistance and 14 controls, across five security tasks. For encryption/decryption, 21% of assisted solutions versus 43% of control solutions were both correct and secure. Effects differ by task and language. These older-model results distinguish functional correctness from security; they do not imply a present-day AI-code safety rate or measure the effect of adding a security check.

18. [Efficient Agents, v1](https://arxiv.org/html/2508.02694v1), 2025 version. On the GAIA development set, Table 2 reports that increasing Best-of-N from one to four changes accuracy from 53.33% to 53.94%, tokens from 243K to 325K, and per-attempt estimated cost from $0.521 to $0.691. Costs use 2025-05 API prices, not a subscription bill. This supports comparing quality with whole-attempt resource use. The abstract's aggregate cost differs from Table 7, so that promotional aggregate is not used here. The experiment does not establish human learning or a universal optimal model configuration.

## Validation still needed

The operational definitions and ownership rules have been reviewed as a draft. Independent assessor agreement, sensitivity to missing records, calibration of weights and bands, and the relationship between these scores and later rework, errors, or resource use remain unvalidated.

Running the scoring feature on fictional records can reveal interpretation and arithmetic errors. It cannot establish those measurement properties or prove long-term skill improvement. A later validation should compare independent judgments on the same records, investigate disagreements, and measure subsequent outcomes without inventing an unsupported sample minimum or pass rate.
