// Turning a report into the GitHub issue that triage will work from.
//
// The layout is not decoration. An agent picking this issue up needs to
// find the same four things in the same four places every time — expected,
// actual, steps, and whether it reproduces — so the headings are fixed and
// machine-readable, and the reporter's words are quoted, never summarised.
// The trailing metadata block is the part triage parses; it is HTML-
// commented so a human reading the issue never sees it.

import Foundation

public struct IssueDraft: Sendable, Equatable {
    public var title: String
    public var body: String
    public var labels: [String]

    public init(title: String, body: String, labels: [String]) {
        self.title = title
        self.body = body
        self.labels = labels
    }
}

public enum IssueRenderer {

    /// The label vocabulary, in one place, because both halves of the
    /// system — the app that files and the agent that triages — have to
    /// agree on it exactly.
    public enum Labels {
        /// On every issue Beacon files, so a repository can tell them apart
        /// from issues people opened by hand.
        public static let beacon = "beacon"
        public static func kind(_ kind: FeedbackKind) -> String { "type:" + kind.rawValue }
        public static func impact(_ impact: Impact) -> String { "impact:" + impact.rawValue }
        public static func severity(_ severity: Severity) -> String { "severity:" + severity.rawValue }
        public static func area(_ id: String) -> String { "area:" + id }

        /// Set by triage, not by the app — listed here so the vocabulary
        /// is one list.
        public static let needsInfo = "needs-info"
        public static let cannotReproduce = "cannot-reproduce"
        public static let expectationMismatch = "expectation-mismatch"
        public static let workingAsIntended = "working-as-intended"
        public static let autoFixed = "auto-fixed"
        public static let needsHuman = "needs-human"
        public static let triaged = "triaged"
    }

    public static func render(_ report: FeedbackReport,
                              index: BeaconIndex?,
                              review: CompletenessReview? = nil) -> IssueDraft {
        IssueDraft(title: title(for: report, index: index),
                   body: body(for: report, index: index, review: review),
                   labels: labels(for: report))
    }

    // MARK: Title

    static func title(for report: FeedbackReport, index: BeaconIndex?) -> String {
        let written = report.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let core = written.isEmpty ? derivedTitle(for: report) : written
        let area = report.areaID.flatMap { id -> String? in
            guard id != BeaconIndex.unsureAreaID, id != BeaconIndex.newAreaID else { return nil }
            return index?.area(id: id)?.name ?? id
        }
        let prefix = area.map { "[\($0)] " } ?? ""
        return prefix + core
    }

    /// A title from the report's own first sentence when the reporter did
    /// not write one. Truncated on a word boundary — a title cut mid-word
    /// reads as a bug in the tool.
    static func derivedTitle(for report: FeedbackReport) -> String {
        let source: String
        switch report.body {
        case .bug(let bug): source = bug.whatHappened
        case .feature(let feature): source = feature.whatIWant
        case .feedback(let feedback): source = feedback.message
        }
        let firstLine = source.split(whereSeparator: \.isNewline).first.map(String.init) ?? source
        let sentence = firstLine.split(separator: ".").first.map(String.init) ?? firstLine
        return truncate(sentence.trimmingCharacters(in: .whitespacesAndNewlines), to: 72)
    }

    static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        var cut = String(text.prefix(limit))
        if let space = cut.lastIndex(of: " ") { cut = String(cut[..<space]) }
        return cut + "\u{2026}"
    }

    // MARK: Labels

    static func labels(for report: FeedbackReport) -> [String] {
        var labels = [Labels.beacon, Labels.kind(report.kind), Labels.impact(report.impact)]
        if let area = report.areaID, area != BeaconIndex.unsureAreaID {
            labels.append(Labels.area(area))
        }
        // Severity is deliberately NOT set here. It is an engineering
        // judgement about the product, and the reporter has already given
        // the thing only they can give — how much it costs them.
        return labels
    }

    // MARK: Body

    static func body(for report: FeedbackReport, index: BeaconIndex?,
                     review: CompletenessReview?) -> String {
        var out: [String] = []

        out.append("> Filed from inside the app with Beacon. "
            + "Reported by **\(report.reporter.displayName ?? report.reporter.accountID)** "
            + "(`\(report.reporter.accountID)`) \u{2014} they agreed to be contacted about this.")
        out.append("")

        switch report.body {
        case .bug(let bug): out += bugSections(bug)
        case .feature(let feature): out += featureSections(feature, index: index)
        case .feedback(let feedback): out += feedbackSections(feedback)
        }

        out.append("## How much this affects them")
        out.append("")
        out.append("**\(report.impact.question)**")
        out.append("")

        if !report.attachments.isEmpty {
            out.append("## What they attached")
            out.append("")
            for attachment in report.attachments {
                var line = "- `\(attachment.filename)` (\(attachment.displaySize))"
                if let offset = attachment.timeOffsetSeconds {
                    line += " \u{2014} from the recording at \(timecode(offset))"
                }
                if let note = attachment.note, !note.isEmpty { line += " \u{2014} \u{201C}\(note)\u{201D}" }
                out.append(line)
            }
            out.append("")
        }

        out += contextSections(report.context)

        if let review, review.source != .unavailable, !review.questions.isEmpty {
            out.append("## Checked before sending")
            out.append("")
            out.append("The on-device check asked about these before the report was sent:")
            out.append("")
            for question in review.questions {
                out.append("- \(question.question)")
            }
            out.append("")
        }

        out.append(metadataBlock(report, review: review))
        return out.joined(separator: "\n")
    }

    static func bugSections(_ bug: BugBody) -> [String] {
        var out: [String] = []
        out.append("## What they expected")
        out.append("")
        out.append(quote(bug.expected))
        out.append("")
        out.append("## What actually happened")
        out.append("")
        out.append(quote(bug.whatHappened))
        out.append("")
        out.append("## Steps to see it")
        out.append("")
        for (offset, step) in bug.cleanSteps.enumerated() {
            out.append("\(offset + 1). \(step)")
        }
        out.append("")
        out.append("## Does it happen again?")
        out.append("")
        out.append("**\(bug.reproducibility.question)**")
        out.append("")
        return out
    }

    static func featureSections(_ feature: FeatureBody, index: BeaconIndex?) -> [String] {
        var out: [String] = []
        out.append("## What they want to be able to do")
        out.append("")
        out.append(quote(feature.whatIWant))
        out.append("")
        if !feature.why.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append("## Why \u{2014} the problem behind the request")
            out.append("")
            out.append(quote(feature.why))
            out.append("")
        }
        out.append("## Where it belongs")
        out.append("")
        if feature.isNewArea {
            out.append("**Something new** \u{2014} they said this isn't part of "
                + "anything the app does today.")
        } else if let id = feature.areaID {
            let area = index?.area(id: id)
            out.append("**\(area?.name ?? id)**")
            if let paths = area?.paths, !paths.isEmpty {
                out.append("")
                out.append("Source: " + paths.map { "`\($0)`" }.joined(separator: ", "))
            }
        } else {
            out.append("Not said.")
        }
        out.append("")
        return out
    }

    static func feedbackSections(_ feedback: FeedbackBody) -> [String] {
        ["## What they said", "", quote(feedback.message), ""]
    }

    static func contextSections(_ context: ReportContext) -> [String] {
        var out: [String] = []
        out.append("<details>")
        out.append("<summary>App, machine and settings</summary>")
        out.append("")
        out.append("| | |")
        out.append("|---|---|")
        out.append("| App | \(context.app.name) \(context.app.version) (\(context.app.build)) |")
        if let commit = context.app.commit {
            out.append("| Built from | `\(commit)` |")
        }
        out.append("| System | \(context.environment.operatingSystem) \(context.environment.osVersion) |")
        out.append("| Machine | \(context.environment.deviceModel) (\(context.environment.architecture)) |")
        out.append("| Language | \(context.environment.locale), \(context.environment.timeZone) |")
        out.append("| On-device model | \(context.environment.onDeviceModel) |")
        if let appearance = context.environment.appearance {
            out.append("| Appearance | \(appearance) |")
        }
        if let textSize = context.environment.textSize {
            out.append("| Text size | \(textSize) |")
        }
        if let memory = context.environment.memoryGB {
            out.append("| Memory | \(String(format: "%.0f", memory)) GB |")
        }
        if let disk = context.environment.freeDiskGB {
            out.append("| Free disk | \(String(format: "%.0f", disk)) GB |")
        }
        out.append("")

        if !context.settings.isEmpty {
            out.append("**Settings**")
            out.append("")
            out.append("| Setting | Value |")
            out.append("|---|---|")
            for setting in context.settings {
                out.append("| \(setting.name) | \(setting.value) |")
            }
            out.append("")
        }

        if !context.hostNotes.isEmpty {
            out.append("**From the app**")
            out.append("")
            for note in context.hostNotes { out.append("- **\(note.name)**: \(note.value)") }
            out.append("")
        }
        out.append("</details>")
        out.append("")

        for tree in context.fileTrees {
            out.append("<details>")
            out.append("<summary>\(tree.label) \u{2014} folder layout (names only, nothing was opened)</summary>")
            out.append("")
            out.append("`\(tree.rootPath)`")
            out.append("")
            out.append("```")
            for entry in tree.entries {
                let size = entry.byteCount.map { " (\($0) bytes)" } ?? ""
                out.append(entry.path + (entry.isDirectory ? "/" : size))
            }
            if tree.truncated {
                out.append("\u{2026} listing stopped here \u{2014} \(tree.totalEntriesSeen) items seen")
            }
            out.append("```")
            out.append("")
            out.append("</details>")
            out.append("")
        }

        if !context.log.isEmpty {
            out.append("<details>")
            out.append("<summary>Log \u{2014} the last \(context.log.count) lines before they hit send</summary>")
            out.append("")
            out.append("```")
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime,
                                       .withDashSeparatorInDate, .withFractionalSeconds]
            for line in context.log {
                out.append("\(formatter.string(from: line.at)) "
                    + "\(line.level.rawValue.uppercased()) [\(line.category)] \(line.message)")
            }
            out.append("```")
            out.append("")
            out.append("</details>")
            out.append("")
        }
        return out
    }

    /// The block triage parses. Kept as an HTML comment so it never shows
    /// up in the rendered issue, and kept as JSON so parsing it is not an
    /// exercise in regular expressions.
    static func metadataBlock(_ report: FeedbackReport, review: CompletenessReview?) -> String {
        var fields: [String: String] = [
            "beacon_schema": "1",
            "report_id": report.id.uuidString,
            "reference": report.reference,
            "kind": report.kind.rawValue,
            "impact": report.impact.rawValue,
            "area": report.areaID ?? "",
            "account": report.reporter.accountID,
            "app_version": report.context.app.version,
            "app_build": report.context.app.build,
            "consent_version": report.consentVersion,
            "started_at": ISO8601DateFormatter().string(from: report.startedAt),
        ]
        if let commit = report.context.app.commit { fields["commit"] = commit }
        if case .bug(let bug) = report.body {
            fields["reproducibility"] = bug.reproducibility.rawValue
            fields["step_count"] = String(bug.cleanSteps.count)
        }
        if let review { fields["review_source"] = review.source.rawValue }

        let json = fields.keys.sorted().map { key in
            "  \"\(key)\": \"\(escape(fields[key] ?? ""))\""
        }.joined(separator: ",\n")
        return "<!-- beacon-metadata\n{\n\(json)\n}\n-->"
    }

    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// Quote the reporter's words verbatim. Every line gets the marker so a
    /// multi-line answer doesn't half-escape out of the quote.
    static func quote(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "> _(not said)_" }
        return trimmed.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> " + $0 }.joined(separator: "\n")
    }

    static func timecode(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
