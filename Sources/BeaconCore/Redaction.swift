// Keeping secrets out of a report that is about to become a GitHub issue.
//
// A report is assembled on the reporter's machine out of their settings,
// their paths and their log — three places credentials habitually turn up.
// Once it is an issue it cannot be un-published, so the sweep runs LAST,
// over the finished text and every attachment, and a hit is not silently
// scrubbed: the reporter is shown what was found and where. Silent
// scrubbing trains nobody and hides a real leak in the host app's logging.

import Foundation

public struct RedactionFinding: Sendable, Equatable, Identifiable {
    public var id: String { "\(location):\(label)" }
    /// Where it was found, in words the reporter can act on ("your log",
    /// "the file you attached: config.json").
    public var location: String
    /// What it looks like, never the value itself.
    public var label: String

    public init(location: String, label: String) {
        self.location = location
        self.label = label
    }
}

public struct Redactor: Sendable {
    /// The mask that replaces a hit.
    public static let mask = "[removed by Beacon]"

    /// Patterns for credential shapes that are worth catching everywhere.
    /// Each is deliberately narrow: a pattern that fires on ordinary prose
    /// makes reporters distrust the whole screen.
    /// Patterns are held as source and compiled at sweep time. A compiled
    /// `Regex` is not `Sendable`, and a sweep runs once per report — the
    /// compile is nowhere near the cost of the file reads around it.
    struct Rule: Sendable {
        let label: String
        let pattern: String
    }

    static let rules: [Rule] = {
        let specs: [(String, String)] = [
            ("an Anthropic API key", #"sk-ant-[A-Za-z0-9\-_]{16,}"#),
            ("an OpenAI-style API key", #"\bsk-[A-Za-z0-9]{32,}"#),
            ("a GitHub token", #"\bgh[pousr]_[A-Za-z0-9]{20,}"#),
            ("a GitHub fine-grained token", #"\bgithub_pat_[A-Za-z0-9_]{20,}"#),
            ("an AWS access key id", #"\bAKIA[0-9A-Z]{16}\b"#),
            ("a Google API key", #"\bAIza[0-9A-Za-z\-_]{35}\b"#),
            ("a Slack token", #"\bxox[baprs]-[A-Za-z0-9\-]{10,}"#),
            ("a Stripe key", #"\b[rs]k_(live|test)_[A-Za-z0-9]{16,}"#),
            ("a private key block", #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#),
            ("a bearer token", #"(?i)\bbearer\s+[A-Za-z0-9\-._~+/]{20,}={0,2}"#),
            ("a JSON web token", #"\beyJ[A-Za-z0-9\-_]{10,}\.[A-Za-z0-9\-_]{10,}\.[A-Za-z0-9\-_]{10,}"#),
            ("a password in a setting", #"(?i)\b(password|passwd|secret|api[_-]?key|access[_-]?token)\b\s*[:=]\s*\S{6,}"#),
            ("a URL with a password in it", #"[a-zA-Z][a-zA-Z0-9+.\-]*://[^\s/:@]+:[^\s/@]+@"#),
        ]
        return specs.map { Rule(label: $0.0, pattern: $0.1) }
    }()

    /// Extra strings the host app knows are secret — read from its own
    /// keychain or config and handed in. Values shorter than 8 characters
    /// are ignored: they are too short to be credentials and long enough
    /// to appear inside ordinary words.
    public var hostSecrets: [String]

    public init(hostSecrets: [String] = []) {
        self.hostSecrets = hostSecrets.filter { $0.count >= 8 }
    }

    /// Sweep one piece of text. Returns the masked text and what was found.
    public func sweep(_ text: String, location: String) -> (text: String, findings: [RedactionFinding]) {
        var output = text
        var findings: [RedactionFinding] = []

        for secret in hostSecrets where output.contains(secret) {
            output = output.replacingOccurrences(of: secret, with: Self.mask)
            findings.append(.init(location: location,
                                  label: "a value this app knows is a secret"))
        }

        for rule in Self.rules {
            guard let regex = try? Regex(rule.pattern) else { continue }
            var matched = false
            while let match = output.firstMatch(of: regex) {
                output.replaceSubrange(match.range, with: Self.mask)
                matched = true
            }
            if matched {
                findings.append(.init(location: location, label: rule.label))
            }
        }
        return (output, findings)
    }

    /// Sweep an attachment's bytes when they are text-shaped. Binary
    /// attachments (images, video) are passed through untouched — there is
    /// nothing to scan and re-encoding them would only lose fidelity.
    public func sweep(_ attachment: Attachment) -> (attachment: Attachment, findings: [RedactionFinding]) {
        let ext = (attachment.filename as NSString).pathExtension.lowercased()
        guard AcceptedFormats.textExtensions.contains(ext),
              let text = String(data: attachment.data, encoding: .utf8)
        else { return (attachment, []) }

        let result = sweep(text, location: "the file you attached: \(attachment.filename)")
        guard !result.findings.isEmpty else { return (attachment, []) }
        var swept = attachment
        swept.data = Data(result.text.utf8)
        return (swept, result.findings)
    }

    // MARK: Paths

    /// Replace the home directory with `~` so a report doesn't publish the
    /// reporter's account name on every line. Applied to every path Beacon
    /// records, not only ones it thinks are sensitive.
    public static func redactHome(_ path: String,
                                  home: String = NSHomeDirectory()) -> String {
        guard !home.isEmpty else { return path }
        var trimmedHome = home
        while trimmedHome.hasSuffix("/") { trimmedHome.removeLast() }
        guard !trimmedHome.isEmpty else { return path }
        if path == trimmedHome { return "~" }
        return path.replacingOccurrences(of: trimmedHome + "/", with: "~/")
    }
}
