import Foundation

/// Shared structured-output schema for Claude Code and Codex, mirroring `ScoreCard`.
enum JSONSchema {
    static var scoreCard: String {
        scoreCard(for: .codex)
    }

    /// What a Codex reading run returns: a short note. The saved session carries everything it read.
    static let readingCheckpoint = #"{"type":"object","additionalProperties":false,"properties":{"note":{"type":"string"}},"required":["note"]}"#

    private static let str: [String: Any] = ["type": "string"]
    private static let int: [String: Any] = ["type": "integer"]
    private static func object(_ props: [String: Any], optional: Set<String> = []) -> [String: Any] {
        ["type": "object", "additionalProperties": false, "properties": props,
         "required": props.keys.filter { !optional.contains($0) }.sorted()]
    }
    private static func array(_ items: [String: Any], min: Int? = nil, max: Int? = nil) -> [String: Any] {
        var a: [String: Any] = ["type": "array", "items": items]
        if let min { a["minItems"] = min }
        if let max { a["maxItems"] = max }
        return a
    }
    private static let evidence = object(["tool": str, "sessionId": str, "date": str, "note": str, "project": str])
    private static let dimensionID: [String: Any] = ["type": "string", "enum": Dimension.allCases.map(\.rawValue)]
    private static func encoded(_ schema: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: schema, options: [.sortedKeys])
        return String(data: data, encoding: .utf8)!
    }

    /// The schema of each dimension's result, in rubric order.
    private static func dimensionSchemas(for engine: AssessmentEngine) -> [(Dimension, [String: Any])] {
        let explanation = object(["sourceBasis": str, "criteria": str, "observedBehavior": str, "overallJudgment": str])
        let planning = object([
            "competencies": array(object([
                "id": ["type": "string", "enum": PlanningAssessment.CompetencyID.allCases.map(\.rawValue)],
                "level": ["type": "string", "enum": PlanningAssessment.Level.assessmentCases.map(\.rawValue)],
                "summary": str,
                "explanation": explanation,
                "sources": array(object(["title": str, "url": str, "note": str])),
                "criteria": object(["high": str, "medium": str, "low": str]),
                "solution": ["type": ["string", "null"]],
            ]), min: 4, max: 4),
        ])
        let dimensionProperties: [String: Any] = [
            "dimension": dimensionID,
            "status": ["type": "string", "enum": ["scored"]],
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
        let planningOptional = engine == .claude ? Set(["assessment", "changeReason"]) : []
        return [(.planningSpecs, object(planningDimension, optional: planningOptional))]
            + Dimension.allCases.filter { $0 != .planningSpecs }.map { dimension in
                let guide = catalog.guide(for: dimension)!
                var properties = dimensionProperties
                properties["dimension"] = ["type": "string", "enum": [dimension.rawValue]]
                properties["planning"] = ["type": "null"]
                properties["assessment"] = object([
                    "competencies": array(object([
                        "id": ["type": "string", "enum": guide.competencies.map(\.id)],
                        "level": ["type": "string", "enum": PlanningAssessment.Level.assessmentCases.map(\.rawValue)],
                        "summary": str,
                        "explanation": explanation,
                        "solution": ["type": ["string", "null"]],
                    ]), min: guide.competencies.count, max: guide.competencies.count),
                ])
                let optional = engine == .claude ? Set(["planning", "changeReason"]) : []
                return (dimension, object(properties, optional: optional))
            }
    }

    static func scoreCard(for engine: AssessmentEngine) -> String {
        encoded(object(cardProperties(for: engine)))
    }

    /// A writing part's card fields: everything except `dimensions`.
    static func cardFrame(for engine: AssessmentEngine) -> String {
        var properties = cardProperties(for: engine)
        properties["dimensions"] = nil
        return encoded(object(properties))
    }

    /// A writing part's card fields for one dimension: `dimensions` holding just that one.
    static func cardDimension(for engine: AssessmentEngine, _ dimension: Dimension) -> String {
        let schema = dimensionSchemas(for: engine).first { $0.0 == dimension }!.1
        return encoded(object(["dimensions": array(schema, min: 1, max: 1)]))
    }

    /// One format for Claude's reading run and every writing part: the reading note and all of the card's fields, none
    /// required, so each run fills only its own. Claude Code sends the format at the start of every request, and the
    /// prompt cache works only on an identical start, so with one format the writing copies reuse the reading's cache
    /// instead of each paying to load the whole session again. The app checks each part's fields (`CardPart.isComplete`).
    static var sharedParts: String {
        var properties = cardProperties(for: .claude)
        var dimensions = properties["dimensions"] as! [String: Any]
        dimensions["minItems"] = 0
        properties["dimensions"] = dimensions
        properties["note"] = str
        return encoded(["type": "object", "additionalProperties": false, "properties": properties, "required": [String]()])
    }

    private static func cardProperties(for engine: AssessmentEngine) -> [String: Any] {
        let dimension: [String: Any] = ["anyOf": dimensionSchemas(for: engine).map(\.1)]
        return [
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
                "unknownInvestigations": array(object([
                    "dimension": dimensionID,
                    "competencyID": str,
                    "status": ["type": "string", "enum": ["not_found", "unavailable", "incomplete"]],
                    "searches": array(str),
                    "remainingLeads": array(str),
                ])),
            ]),
        ]
    }
}
