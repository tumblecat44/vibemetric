# AI Native Score rubric

- `rubric.md` is bundled by the `VibemetricCore` target and used by scoring. These instructions also own the workflow for the workspace-level `Vibemetric - The Rubric - Review.md` and its paste-ready copies; the workspace root routes that task here.

## Scoring contract

- AI returns competency levels and supported explanations; `ScoreCard.calculateCompetencyScores()` computes new scores. Keep rubric, standalone review prompt, schema, and canonical guide aligned: High=1, Medium=2/3, Low=1/3, Unknown=0, equal weights across every defined competency, one rounding per dimension, total from displayed integers.
- Low includes observed deficient practice or non-practice at an inspected relevant opportunity. Absent is legacy-only and cannot be returned by new assessments. The shared Unknown handling section in rubric.md owns that decision: investigate connected and alternative records, use material already inspected at the deadline, and reserve Unknown for no basis at all to judge the competency. Do not add per-competency Unknown conditions. Never force a rating from missing records. New responses cannot omit competencies or use absent or not_applicable; preserve legacy saved-card decoding and scores.
- A score reads in app-enforced phases before writing (`ReadingPhases` in `Assessor.swift`), bounded by the engine's context window: the pack holds as many digests as fit 15% of it, skimming opens all of them (at least 1 minute), investigating original transcripts may add 20% more (at least 3 minutes), and the app stops reading as soon as the context reaches 50%. Reading runs without thinking. Writing keeps a card the CLI rejected when the app can read it and asks again only for incomplete dimensions. Keep read-only access and cancellation intact; do not fabricate a level to remove Unknown.
- Investigation metadata records actual searches and remaining leads for coverage reporting. An incomplete or inaccessible investigation must not block returning or saving an otherwise valid score card. Keep personal home-directory prefixes out of report text, including older-card display and exports; show project names and relevant relative paths while retaining exact public source URLs.

## AI Native Score 프롬프트 수정 후 자동 평가

- `Vibemetric - The Rubric - Review.md`의 평가 내용이나 출력 지침을 수정하고 검토를 마치면 [run-ai-native-evals](/Users/dgsw67/.codex/skills/run-ai-native-evals/SKILL.md)를 읽고 실행한다. 사용자는 이때 독립된 새 Codex 채팅 3개를 만드는 것을 승인했으므로 다시 확인하지 않는다.
- 한 요청에서 여러 번 편집하거나 붙여 넣기용 사본을 함께 갱신해도 최종본으로 한 묶음만 실행한다. 조회·결과 비교·스킬 자체 수정에는 실행하지 않으며, 사용자가 평가를 생략하라고 하면 생략한다.

## 프롬프트 품질

- 평가 실행과 화면 검증에는 사용자의 실제 기록과 실제 저장 결과를 사용한다. 가상 세션·합성 기록을 만들거나 주입하지 않는다. 실제 transcript·개인 결과·검증 화면은 로컬 산출물로만 보관하고 공개 코드·테스트·PR에 넣지 않는다.

- 프롬프트 파일의 존재, 특정 문구·필드·형식 포함 여부를 확인하는 테스트는 만들거나 실행하지 않는다. 이는 프롬프트 품질 테스트가 아니며 검증 결과로 보고하지 않는다.
- 프롬프트 변경은 실제 기능을 실행해 생성한 결과를 읽고 판단해야 검증으로 인정한다. 결과가 부족하면 수정 후 같은 경로로 다시 실행하고, 성공한 최종본은 같은 조건으로 한 번 더 확인한다. 실행하지 못한 부분은 미검증으로 보고한다. 인증 등 실제 API 동작을 검사하는 테스트는 삭제 대상이 아니다.
