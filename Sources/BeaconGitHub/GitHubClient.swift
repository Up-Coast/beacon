// The thin slice of GitHub's REST API that filing a report needs.
//
// Deliberately hand-rolled and small. Beacon has to drop into any app
// without dragging a dependency tree behind it, and the whole surface used
// here is four calls: create an issue, add labels, put a file, and read
// who the token belongs to.

import Foundation
import BeaconCore

public struct GitHubClient: Sendable {
    public var owner: String
    public var repository: String
    public var token: String
    public var apiBase: URL

    public init(owner: String, repository: String, token: String,
                apiBase: URL = URL(string: "https://api.github.com")!) {
        self.owner = owner
        self.repository = repository
        self.token = token
        self.apiBase = apiBase
    }

    var repoPath: String { "repos/\(owner)/\(repository)" }

    // MARK: Requests

    func send(_ method: String, _ path: String,
              body: [String: Any]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: apiBase.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("beacon", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TransportError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            let message = parsed["message"] as? String ?? "no reason given"
            throw TransportError.rejected(status: status, detail: Self.explain(status, message))
        }
        return parsed
    }

    /// Turn GitHub's status codes into something a reporter can act on.
    /// They are not going to read an API error, and most of these are
    /// really a setup problem on our side, not theirs.
    static func explain(_ status: Int, _ message: String) -> String {
        switch status {
        case 401: "The app's GitHub sign-in has expired. Signing in again usually fixes it."
        case 403 where message.lowercased().contains("rate limit"):
            "GitHub is rate-limiting us. Your report is saved \u{2014} try sending it again in a few minutes."
        case 403: "This account doesn't have permission to file into that repository."
        case 404: "That repository couldn't be found, or this account can't see it."
        case 410: "Issues are switched off on that repository."
        case 422: "GitHub refused the report as written (\(message))."
        default: message
        }
    }

    // MARK: Calls

    public struct CreatedIssue: Sendable, Equatable {
        public var number: Int
        public var url: URL?
    }

    public func createIssue(title: String, body: String, labels: [String]) async throws -> CreatedIssue {
        let response = try await send("POST", "\(repoPath)/issues", body: [
            "title": title, "body": body, "labels": labels,
        ])
        guard let number = response["number"] as? Int else {
            throw TransportError.rejected(status: 200, detail: "GitHub didn't return an issue number.")
        }
        return CreatedIssue(number: number,
                            url: (response["html_url"] as? String).flatMap(URL.init(string:)))
    }

    /// Who this token belongs to. Used at sign-in to show the reporter
    /// which account they just connected.
    public func currentLogin() async throws -> String {
        let response = try await send("GET", "user")
        return response["login"] as? String ?? "unknown"
    }

    /// Put one file into the repository. Attachments go through here
    /// because GitHub's issue API cannot take a file: the browser uploader
    /// is a separate, unpublished endpoint, and building on an unpublished
    /// endpoint is how an integration breaks silently six months later.
    ///
    /// Files land on their own branch so a report can never touch the code
    /// branches, and the issue links to them.
    @discardableResult
    public func putFile(path: String, data: Data, message: String,
                        branch: String) async throws -> URL? {
        let response = try await send("PUT", "\(repoPath)/contents/\(path)", body: [
            "message": message,
            "content": data.base64EncodedString(),
            "branch": branch,
        ])
        let content = response["content"] as? [String: Any]
        return (content?["html_url"] as? String).flatMap(URL.init(string:))
    }

    /// Make sure the attachments branch exists, creating it from the
    /// default branch's head the first time.
    public func ensureBranch(_ name: String) async throws {
        if (try? await send("GET", "\(repoPath)/git/ref/heads/\(name)")) != nil { return }
        let repo = try await send("GET", repoPath)
        let base = repo["default_branch"] as? String ?? "main"
        let head = try await send("GET", "\(repoPath)/git/ref/heads/\(base)")
        guard let object = head["object"] as? [String: Any],
              let sha = object["sha"] as? String else {
            throw TransportError.rejected(status: 200, detail: "Couldn't read the repository's default branch.")
        }
        _ = try await send("POST", "\(repoPath)/git/refs", body: [
            "ref": "refs/heads/\(name)", "sha": sha,
        ])
    }
}
