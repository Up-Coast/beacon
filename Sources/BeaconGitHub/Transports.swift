// The three ways a report reaches GitHub, and when to pick each.
//
// This is the one decision every adopting app has to make, so all three
// are shipped and the trade-offs are written down here rather than left in
// somebody's head.
//
//   GitHubIssueTransport — the reporter signs in with their own GitHub
//   account, once, and reports post as them. No server, no secret in the
//   app, and the issue carries a real author. Needs every tester to have a
//   GitHub account with access to the repository, which is exactly true of
//   an internal team and false of a public beta.
//
//   RelayTransport — the app posts to a small endpoint you run, which
//   holds the GitHub credential and files on everyone's behalf. Testers
//   need nothing. Costs you one service to deploy and keep alive.
//
//   LocalBundleTransport — the report is written to a folder and the
//   reporter is shown where. Nothing is sent. Always works, needs nothing,
//   and somebody has to carry the last step by hand.
//
// A host can also chain them: try the first, fall back to the last, and
// nobody ever loses a report because a network was down. That is what
// FallbackTransport does, and it is the recommended default.

import Foundation
import BeaconCore

// MARK: - Direct to GitHub

public struct GitHubIssueTransport: ReportTransport {
    public var client: GitHubClient
    /// The branch attachments are committed to. Its own branch, so a
    /// report can never land on a branch anyone builds from.
    public var attachmentBranch: String
    /// Where the repository can be browsed, for the receipt's link.
    public var repositoryDescription: String

    public init(client: GitHubClient,
                attachmentBranch: String = "beacon-attachments") {
        self.client = client
        self.attachmentBranch = attachmentBranch
        self.repositoryDescription = "\(client.owner)/\(client.repository)"
    }

    public var destinationDescription: String {
        "an issue on \(repositoryDescription)"
    }

    public func submit(_ submission: ReportSubmission) async throws -> SubmissionReceipt {
        var body = submission.issue.body

        // Attachments first: an issue that links to files which failed to
        // upload is worse than one that says the upload failed.
        if !submission.attachments.isEmpty {
            let links = try await uploadAttachments(submission)
            if !links.isEmpty {
                body = insertAttachmentLinks(links, into: body)
            }
        }

        let issue = try await client.createIssue(
            title: submission.issue.title,
            body: body,
            labels: submission.issue.labels)

        return SubmissionReceipt(
            summary: "Filed as issue #\(issue.number) on \(repositoryDescription). "
                + "Anyone on the team can read it, and we may come back to you about it.",
            issueNumber: issue.number,
            url: issue.url,
            isFiled: true)
    }

    func uploadAttachments(_ submission: ReportSubmission) async throws -> [(String, URL)] {
        try await client.ensureBranch(attachmentBranch)
        var links: [(String, URL)] = []
        for attachment in submission.attachments {
            let path = ".beacon/attachments/\(submission.report.reference)/\(attachment.filename)"
            let url = try await client.putFile(
                path: path,
                data: attachment.data,
                message: "Beacon attachment for \(submission.report.reference)",
                branch: attachmentBranch)
            if let url { links.append((attachment.filename, url)) }
        }
        return links
    }

    /// Rewrite the attachments section so each filename becomes a link.
    /// The list is already there from the renderer; this only makes the
    /// names clickable, so the issue reads the same either way.
    func insertAttachmentLinks(_ links: [(String, URL)], into body: String) -> String {
        var output = body
        for (filename, url) in links {
            output = output.replacingOccurrences(
                of: "- `\(filename)`", with: "- [`\(filename)`](\(url.absoluteString))")
        }
        return output
    }
}

// MARK: - Through a relay you run

public struct RelayTransport: ReportTransport {
    /// The endpoint that holds the GitHub credential and files on behalf
    /// of everyone.
    public var endpoint: URL
    /// A shared value the relay checks so it isn't an open issue-filing
    /// hole on the internet. This is NOT a GitHub credential and cannot
    /// file anything by itself — the difference matters, because this one
    /// does ship inside the app.
    public var appToken: String?
    public var destinationName: String

    public init(endpoint: URL, appToken: String? = nil,
                destinationName: String = "the team") {
        self.endpoint = endpoint
        self.appToken = appToken
        self.destinationName = destinationName
    }

    public var destinationDescription: String { "\(destinationName), as a GitHub issue" }

    public func submit(_ submission: ReportSubmission) async throws -> SubmissionReceipt {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let appToken { request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization") }

        // base64 adds a third again, and a request that dies at the far end
        // after a long upload is the worst way to tell somebody their
        // report is too big. Check it here, with the real encoded size.
        let encodedBytes = submission.attachments.reduce(0) { $0 + ($1.byteCount * 4 + 2) / 3 }
        let limit = AcceptedFormats.maximumTotalBytes
        guard encodedBytes <= limit else {
            throw TransportError.tooLarge(bytes: encodedBytes, limit: limit)
        }

        let payload: [String: Any] = [
            "title": submission.issue.title,
            "body": submission.issue.body,
            "labels": submission.issue.labels,
            "reference": submission.report.reference,
            "account": submission.report.reporter.accountID,
            "attachments": submission.attachments.map {
                ["filename": $0.filename, "base64": $0.data.base64EncodedString()]
            },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TransportError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            throw TransportError.rejected(
                status: status,
                detail: parsed["error"] as? String ?? "The relay turned the report away.")
        }
        let number = parsed["issue_number"] as? Int
        return SubmissionReceipt(
            summary: number.map { "Filed as issue #\($0). We may come back to you about it." }
                ?? "Sent. We may come back to you about it.",
            issueNumber: number,
            url: (parsed["html_url"] as? String).flatMap(URL.init(string:)),
            isFiled: true)
    }
}

// MARK: - Saved on this machine

public struct LocalBundleTransport: ReportTransport {
    /// Where the archive already wrote the report. Passed in rather than
    /// re-derived so the receipt points at the actual folder.
    public var folderProvider: @Sendable () -> URL?
    /// How the reporter is told to hand it over.
    public var handoverInstruction: String

    public init(folderProvider: @escaping @Sendable () -> URL?,
                handoverInstruction: String = "Send the folder to the team and we'll take it from there.") {
        self.folderProvider = folderProvider
        self.handoverInstruction = handoverInstruction
    }

    public var destinationDescription: String { "a folder on \(PlatformWording.thisDevice)" }

    public func submit(_ submission: ReportSubmission) async throws -> SubmissionReceipt {
        let folder = folderProvider()
        return SubmissionReceipt(
            summary: "Your report is saved on \(PlatformWording.thisDevice). \(handoverInstruction)",
            issueNumber: nil,
            url: folder,
            // Deliberately false: nothing was filed. Saying "sent" here
            // would leave somebody believing a report is on its way when
            // it is sitting in a folder.
            isFiled: false)
    }
}

// MARK: - Try one, fall back to the other

public struct FallbackTransport: ReportTransport {
    public var primary: any ReportTransport
    public var fallback: any ReportTransport
    /// Told what went wrong, so a host can log it or show it.
    public var onFallback: (@Sendable (any Error) -> Void)?

    public init(primary: any ReportTransport, fallback: any ReportTransport,
                onFallback: (@Sendable (any Error) -> Void)? = nil) {
        self.primary = primary
        self.fallback = fallback
        self.onFallback = onFallback
    }

    public var destinationDescription: String { primary.destinationDescription }

    public func submit(_ submission: ReportSubmission) async throws -> SubmissionReceipt {
        do {
            return try await primary.submit(submission)
        } catch {
            onFallback?(error)
            var receipt = try await fallback.submit(submission)
            receipt.summary = "We couldn't reach GitHub just now, so your report "
                + "is saved on \(PlatformWording.thisDevice) instead. " + receipt.summary
            return receipt
        }
    }
}
