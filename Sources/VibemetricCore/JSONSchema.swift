import Foundation

/// Shared structured-output schema for Claude Code and Codex, mirroring `ScoreCard`.
enum JSONSchema {
    static var scoreCard: String {
        let str: [String: Any] = ["type": "string"]
        let int: [String: Any] = ["type": "integer"]
        func object(_ props: [String: Any], optional: Set<String> = []) -> [String: Any] {
            ["type": "object", "additionalProperties": false, "properties": props,
             "required": props.keys.filter { !optional.contains($0) }.sorted()]
        }
        func array(_ items: [String: Any], min: Int? = nil, max: Int? = nil) -> [String: Any] {
            var a: [String: Any] = ["type": "array", "items": items]
            if let min { a["minItems"] = min }
            if let max { a["maxItems"] = max }
            return a
        }

        let evidence = object(["tool": str, "sessionId": str, "date": str, "note": str, "project": str])
        let explanation = object(["sourceBasis": str, "criteria": str, "observedBehavior": str, "overallJudgment": str])
        let planning = object([
            "competencies": array(object([
                "id": ["type": "string", "enum": PlanningAssessment.CompetencyID.allCases.map(\.rawValue)],
                "level": ["type": "string", "enum": PlanningAssessment.Level.allCases.map(\.rawValue)],
                "summary": str,
                "explanation": explanation,
                "sources": array(object(["title": str, "url": str, "note": str])),
                "criteria": object(["high": str, "medium": str, "low": str]),
                "solution": ["type": ["string", "null"]],
            ]), min: 4, max: 4),
        ])
        let dimensionID: [String: Any] = ["type": "string", "enum": Dimension.allCases.map(\.rawValue)]
        let dimensionProperties: [String: Any] = [
            "dimension": dimensionID,
            "score": ["type": ["integer", "null"], "minimum": 0, "maximum": 10],
            "status": ["type": "string", "enum": ["scored", "not_assessable"]],
            "headline": str,
            "saw": str,
            "issueLine": str,
            "fixLine": str,
            "strengths": array(str, max: 3),
            "impact": str,
            "tryThis": ["type": ["string", "null"]],
            "solutionSteps": array(str, max: 4),
            "evidence": array(evidence, max: 3),
            "changeReason": ["type": ["string", "null"]],
        ]
        var planningDimension = dimensionProperties
        planningDimension["dimension"] = ["type": "string", "enum": [Dimension.planningSpecs.rawValue]]
        planningDimension["planning"] = planning
        planningDimension["assessment"] = ["type": "null"]
        let catalog: RubricGuide
        do {
            catalog = try RubricGuide.load()
        } catch {
            preconditionFailure("The bundled competency guide could not be loaded: \(error.localizedDescription)")
        }
        let otherDimensions = Dimension.allCases.filter { $0 != .planningSpecs }.map { dimension in
            let guide = catalog.guide(for: dimension)!
            var properties = dimensionProperties
            properties["dimension"] = ["type": "string", "enum": [dimension.rawValue]]
            properties["planning"] = ["type": "null"]
            properties["assessment"] = object([
                "competencies": array(object([
                    "id": ["type": "string", "enum": guide.competencies.map(\.id)],
                    "level": ["type": "string", "enum": PlanningAssessment.Level.allCases.map(\.rawValue)],
                    "summary": str,
                    "explanation": explanation,
                    "solution": ["type": ["string", "null"]],
                ]), min: guide.competencies.count, max: guide.competencies.count),
            ])
            return object(properties)
        }
        let dimension: [String: Any] = ["anyOf": [object(planningDimension)] + otherDimensions]
        let schema = object([
            "language": str,
            "diagnosis": str,
            "summary": array(str, min: 2, max: 3),
            "highlights": array(str, max: 4),
            "dimensions": array(dimension, min: 10, max: 10),
            "improvement": object([
                "title": str, "situation": str,
                "actions": array(str, min: 3, max: 4),
                "suggestedInstruction": ["type": ["string", "null"]],
                "signOfSuccess": str, "tryItOn": str,
                "dimension": dimensionID,
                "impact": str,
                "evidence": array(evidence, max: 3),
                "count": ["type": ["integer", "null"], "minimum": 1],
                "countLabel": ["type": ["string", "null"]],
            ]),
            "followUp": ["anyOf": [
                object([
                    "previousTitle": str,
                    "status": ["type": "string", "enum": ["not_started", "partly_done", "done", "applied"]],
                    "summary": str,
                    "evidence": array(evidence, max: 4),
                ]),
                ["type": "null"],
            ]],
            "roadmap": array(object(["stage": int, "change": str, "result": str]), min: 1, max: 3),
            "scope": object([
                "assessedAt": str, "timeZone": str,
                "recordDates": array(object(["tool": str, "from": str, "to": str, "sessions": int])),
                "sessionsExamined": int, "tasksCheckedInDetail": int,
                "elapsedMinutes": ["type": "number"],
                "limits": array(str),
            ]),
        ])
        let data = try! JSONSerialization.data(withJSONObject: schema, options: [.sortedKeys])
        return String(data: data, encoding: .utf8)!
    }
}
