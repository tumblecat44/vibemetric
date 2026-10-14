# Changelog

## 0.3.0 (2026-10-14)

- Every fix and category shows two parts: **Problem**, as short bullets with the sessions it comes from, and **Solution**, with the fix in one line and Prompt and Steps tabs.
- The summary at the top of the score is smaller and, on new scores, written as 2–3 plain-language bullets.
- Menu bar: two problems, each with its fix, and the full problem sentence instead of a count.
- Main window: what to fix is a carousel, with the next fix showing at the edge.
- New scores describe problems in plain words: what happened, how often and what it cost, without jargon or praise mixed in.

## 0.2.0 (2026-10-13)

- Vibemetric is open source under the MIT license. This repository has the complete free app.
- Builds from source have no Pro features and don't check for updates. The official app from vibemetric.app keeps both.
- Optional modules attach through the plug-in points in `Sources/VibemetricAppKit/Extensions.swift`.
- Menu bar: the most urgent fix comes first, with the score as a small line below it.
- Score details are easier to read: short fields and a new General layout.
- Score explanations use month-day dates and name the real projects the evidence comes from.
- Recommendation tables stay intact in narrow windows.
- Scanning uses less memory: each transcript's temporary objects are freed as soon as it's read.

Versions before 0.2.0 were released from a private repository. Their history is not in this repository.
