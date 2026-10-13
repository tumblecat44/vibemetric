# Changelog

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
