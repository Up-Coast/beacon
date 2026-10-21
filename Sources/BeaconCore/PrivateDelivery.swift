// Private delivery: details an app sends about a problem without anyone
// pressing a button, which must never become a GitHub issue.
//
// A report becomes an issue, and every member of a GitHub organization can
// read its repositories. Some details cannot go there: a customer's project
// names, file paths, the words of an error about their data. Private
// delivery seals those details ON THE DEVICE to a public key whose private
// half only the app's owner holds, and sends only the ciphertext to a
// separate store (the `beacon-private` function and a private bucket). The
// function, the bucket and anyone who can see them hold nothing readable,
// and there is no way to read a sealed message back through the relay. The
// owner reads them on their own Mac with `beacon-private read`.
//
// It is OFF unless the developer turns it on: `privateDelivery` in
// `BeaconConfiguration` is nil by default. Sending without the person's
// consent is impossible by construction: either they accepted Beacon's own
// notice, which says this happens, or the developer names the agreement that
// covers it (a beta tester agreement), and that name travels in every
// sealed message.

import CryptoKit
import Foundation

/// The developer's choice to send sealed details privately. See the file
/// comment; nil in `BeaconConfiguration` means nothing is ever sent this way.
public struct PrivateDelivery: Sendable, Equatable {
    /// What allows sending without the person pressing anything.
    public enum Consent: Sendable, Equatable {
        /// The person accepted Beacon's notice, which says this app may send
        /// details on its own. Until they have, nothing is sent.
        case beaconNotice
        /// The person agreed to it elsewhere, under the agreement named here
        /// (for example "the Harbour beta tester agreement"). The name is
        /// sealed into every message, so the record says what covered it.
        case hostAgreement(String)
    }

    /// Why private delivery could not be set up or could not send.
    public enum Failure: Error, Equatable, LocalizedError {
        /// The owner's public key is not a base64 Curve25519 key.
        case invalidPublicKey
        /// The app did not turn private delivery on.
        case notEnabled
        /// The person has not accepted the notice that says this happens.
        case notConsented
        /// After the sweep and the limits, there was nothing to send.
        case empty
        /// The id is not a UUID.
        case invalidID
        /// The sealed message is over the store's limit.
        case tooLarge(bytes: Int)
        /// The store refused it or could not be reached.
        case notStored(status: Int)

        /// The failure in a sentence.
        public var errorDescription: String? {
            switch self {
            case .invalidPublicKey: "The owner's public key is not a valid key."
            case .notEnabled: "Private delivery is not turned on in this app."
            case .notConsented: "The person has not accepted the notice that allows this yet."
            case .empty: "There was nothing to send."
            case .invalidID: "The id is not a UUID."
            case .tooLarge(let bytes): "The sealed message is \(bytes) bytes, over the store's limit."
            case .notStored(let status): "The private store did not keep it (\(status))."
            }
        }
    }

    /// The `beacon-private` function's address.
    public var endpoint: URL
    /// The token the function checks. Like the relay's, it ships inside the
    /// app, so it is a door key, not a secret: it cannot read anything.
    public var appToken: String
    /// The owner's public key, raw (32 bytes).
    public let ownerPublicKey: Data
    /// What allows sending without the person pressing anything.
    public var consent: Consent
    /// The longest any one field may be, in characters, after the sweep.
    public var maximumFieldLength: Int

    /// The most a sealed message may be, in bytes: the store's own limit.
    public static let maximumSealedBytes = 64 * 1024

    /// The default per-field limit, which keeps a sealed message well under
    /// the store's 64 KiB.
    public static let defaultMaximumFieldLength = 8_000

    /// Turns private delivery on. Throws `Failure.invalidPublicKey` when
    /// `ownerPublicKey` (base64, as `beacon-private keygen` prints it) is not
    /// a Curve25519 key, so a typo fails at launch, not at the first send.
    public init(endpoint: URL, appToken: String, ownerPublicKey: String,
                consent: Consent = .beaconNotice,
                maximumFieldLength: Int = PrivateDelivery.defaultMaximumFieldLength) throws {
        guard let raw = Data(base64Encoded: ownerPublicKey),
            (try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw)) != nil
        else { throw Failure.invalidPublicKey }
        self.endpoint = endpoint
        self.appToken = appToken
        self.ownerPublicKey = raw
        self.consent = consent
        self.maximumFieldLength = max(1, maximumFieldLength)
    }
}

/// What one sealed message holds, as the owner reads it back.
public struct PrivateDetails: Codable, Sendable, Equatable {
    /// The message's id, also its name in the store. A public report can cite
    /// it so the two can be matched without the details being in the report.
    public var id: String
    /// The app, version and build that sent it.
    public var app: String
    /// The app's version.
    public var version: String
    /// The app's build.
    public var build: String
    /// When it was sealed.
    public var sealedAt: Date
    /// The agreement that covered sending it, or nil when the person accepted
    /// Beacon's own notice (its version is in `noticeVersion`).
    public var agreement: String?
    /// The notice version the person accepted, when that is what covered it.
    public var noticeVersion: String?
    /// The details, by name, after the secret sweep.
    public var fields: [String: String]
    /// What the sweep removed, so the owner knows a value was masked.
    public var removed: [String]

    /// A message as the app seals it.
    public init(id: String, app: String, version: String, build: String, sealedAt: Date,
                agreement: String?, noticeVersion: String?, fields: [String: String], removed: [String]) {
        self.id = id
        self.app = app
        self.version = version
        self.build = build
        self.sealedAt = sealedAt
        self.agreement = agreement
        self.noticeVersion = noticeVersion
        self.fields = fields
        self.removed = removed
    }
}

/// Sealing and opening a message. One HPKE message (Curve25519, SHA-256,
/// ChaCha20-Poly1305): the 32-byte encapsulated key, then the sealed JSON.
public enum PrivateSealing {
    /// The HPKE `info` both ends use; a change makes old messages unreadable.
    public static let info = Data("beacon-private-v1".utf8)

    /// The details sealed to `publicKey` (raw, 32 bytes).
    public static func seal(_ details: PrivateDetails, to publicKey: Data) throws -> Data {
        let recipient = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKey)
        var sender = try HPKE.Sender(recipientKey: recipient, ciphersuite: .Curve25519_SHA256_ChachaPoly, info: info)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return sender.encapsulatedKey + (try sender.seal(try encoder.encode(details)))
    }

    /// A sealed message opened with the owner's private key.
    public static func open(_ blob: Data, with key: Curve25519.KeyAgreement.PrivateKey) throws -> PrivateDetails {
        var recipient = try HPKE.Recipient(
            privateKey: key, ciphersuite: .Curve25519_SHA256_ChachaPoly, info: info,
            encapsulatedKey: blob.prefix(32))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PrivateDetails.self, from: try recipient.open(blob.dropFirst(32)))
    }
}

extension PrivateDelivery {
    /// The message for these fields: each swept for secrets with the same
    /// sweep every report gets, then cut to `maximumFieldLength`. Empty
    /// fields are dropped; nothing left throws `Failure.empty`.
    public func details(
        id: String, fields: [String: String], app: AppIdentity, hostSecrets: [String],
        noticeVersion: String?, now: Date = Date()
    ) throws -> PrivateDetails {
        let redactor = Redactor(hostSecrets: hostSecrets)
        var kept: [String: String] = [:]
        var removed: [String] = []
        for (name, value) in fields {
            let swept = redactor.sweep(value, location: name)
            removed += swept.findings.map { "\($0.label) in \(name)" }
            let text = String(swept.text.prefix(maximumFieldLength))
            if !text.isEmpty { kept[name] = text }
        }
        guard !kept.isEmpty else { throw Failure.empty }
        let agreement: String? = if case .hostAgreement(let name) = consent { name } else { nil }
        return PrivateDetails(
            id: id, app: app.bundleIdentifier, version: app.version, build: app.build,
            sealedAt: Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down)),
            agreement: agreement, noticeVersion: agreement == nil ? noticeVersion : nil,
            fields: kept, removed: removed.sorted())
    }

    /// Sends a sealed message to the store. A 409 means a message with this
    /// id is already stored, which counts as sent: a retry after a lost answer
    /// never fails and never replaces what is there.
    public func send(_ sealed: Data, id: String, app: String,
                     session: URLSession = .shared) async throws {
        guard sealed.count <= Self.maximumSealedBytes else { throw Failure.tooLarge(bytes: sealed.count) }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ["id": id, "app": app, "ciphertext": sealed.base64EncodedString()])
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 409 else { throw Failure.notStored(status: status) }
    }

    /// The sentence added to Beacon's notice when private delivery is on, so
    /// the person is told before anything is sent.
    public static let noticePoint =
        "This app can also send $ORG details about problems it runs into by itself, "
        + "without you pressing anything. They're locked on this device so that only $ORG can read them."
}

extension ConsentNotice {
    /// This notice with the private delivery sentence added, as a new
    /// version, so a person who accepted the notice without it is asked again.
    public func withPrivateDelivery() -> ConsentNotice {
        ConsentNotice(
            version: version + "+private.1", headline: headline,
            points: points + [PrivateDelivery.noticePoint], acceptButton: acceptButton)
    }
}
