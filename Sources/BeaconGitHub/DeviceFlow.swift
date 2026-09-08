// Signing a reporter in to GitHub without shipping a secret.
//
// GitHub's device flow is the right shape for a desktop app: the app shows
// an eight-character code, the person types it into github.com in their
// own browser, and the app gets a token belonging to THEM. The only value
// baked into the app is the OAuth client id, which is public by design —
// no client secret, nothing worth extracting from the binary.
//
// The result: reports are filed by the person who wrote them, under their
// own account, and revoking access is something they can do themselves.
// The trade-off is that everyone reporting needs a GitHub account that can
// see the repository, which is why this is one of three transports rather
// than the only one.
//
// Endpoints and error codes are GitHub's own, from their OAuth
// documentation.

import Foundation
import BeaconCore

public struct GitHubDeviceFlow: Sendable {

    public var clientID: String
    /// `repo` is what filing an issue on a private repository needs. Ask
    /// for nothing else: an over-scoped token is a liability, and a person
    /// reading the consent screen will notice.
    public var scopes: [String]

    public init(clientID: String, scopes: [String] = ["repo"]) {
        self.clientID = clientID
        self.scopes = scopes
    }

    /// What the reporter is shown while they authorise.
    public struct Challenge: Sendable, Equatable {
        public var userCode: String
        public var verificationURL: URL
        public var deviceCode: String
        public var expiresAt: Date
        public var pollInterval: TimeInterval
    }

    public enum DeviceFlowError: Error, LocalizedError, Equatable {
        case declined
        case expired
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .declined: "The sign-in was cancelled, so nothing was connected."
            case .expired: "The code ran out before it was entered. Starting again gives you a fresh one."
            case .failed(let detail): "Signing in to GitHub didn't work: \(detail)"
            }
        }
    }

    static let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    static let tokenURL = URL(string: "https://github.com/login/oauth/access_token")!

    public func begin() async throws -> Challenge {
        let response = try await post(Self.deviceCodeURL, form: [
            "client_id": clientID,
            "scope": scopes.joined(separator: " "),
        ])
        guard let deviceCode = response["device_code"] as? String,
              let userCode = response["user_code"] as? String,
              let verification = (response["verification_uri"] as? String)
                  .flatMap(URL.init(string:))
        else {
            throw DeviceFlowError.failed(response["error_description"] as? String
                ?? "GitHub didn't return a code.")
        }
        let expiresIn = (response["expires_in"] as? Double) ?? 900
        let interval = (response["interval"] as? Double) ?? 5
        return Challenge(userCode: userCode,
                         verificationURL: verification,
                         deviceCode: deviceCode,
                         expiresAt: Date().addingTimeInterval(expiresIn),
                         pollInterval: interval)
    }

    /// Wait for the person to finish in their browser. Honours GitHub's
    /// `slow_down` by widening the gap rather than hammering on.
    public func awaitToken(_ challenge: Challenge) async throws -> String {
        var interval = challenge.pollInterval
        while Date() < challenge.expiresAt {
            try await Task.sleep(for: .seconds(interval))
            let response = try await post(Self.tokenURL, form: [
                "client_id": clientID,
                "device_code": challenge.deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ])
            if let token = response["access_token"] as? String { return token }
            switch response["error"] as? String {
            case "authorization_pending": continue
            case "slow_down": interval += 5
            case "access_denied": throw DeviceFlowError.declined
            case "expired_token": throw DeviceFlowError.expired
            case let other?: throw DeviceFlowError.failed(other)
            case nil: throw DeviceFlowError.failed("GitHub sent back an answer we didn't understand.")
            }
        }
        throw DeviceFlowError.expired
    }

    func post(_ url: URL, form: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("beacon", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data(form.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value)"
        }.joined(separator: "&").utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        } catch {
            throw DeviceFlowError.failed(error.localizedDescription)
        }
    }
}

/// Where the token is kept between launches: the keychain, because it is
/// a credential belonging to a person and UserDefaults is a plain file.
public enum GitHubTokenStore {

    public static func save(_ token: String, account: String, service: String = "beacon.github") -> Bool {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    public static func read(account: String, service: String = "beacon.github") -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(account: String, service: String = "beacon.github") {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
    }
}
