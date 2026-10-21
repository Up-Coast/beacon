// Private delivery: off unless turned on, told to the person first, swept
// for secrets, and readable only with the owner's private key.

import CryptoKit
import Foundation
import Testing
@testable import BeaconCore

private struct NoTransport: ReportTransport {
    var destinationDescription: String { "the team" }
    func submit(_ submission: ReportSubmission) async throws -> SubmissionReceipt { SubmissionReceipt(summary: "") }
}

@Suite("Private delivery: off by default, said first, sealed to the owner")
struct PrivateDeliveryTests {

    private let owner = Curve25519.KeyAgreement.PrivateKey()
    private let app = AppIdentity(name: "Harbour", bundleIdentifier: "com.example.harbour", version: "1.2", build: "42")
    private let id = "11111111-2222-3333-4444-555555555555"

    private func delivery(consent: PrivateDelivery.Consent = .beaconNotice, limit: Int = 8_000) throws -> PrivateDelivery {
        try PrivateDelivery(
            endpoint: URL(string: "https://x.supabase.co/functions/v1/beacon-private")!, appToken: "token",
            ownerPublicKey: owner.publicKey.rawRepresentation.base64EncodedString(), consent: consent,
            maximumFieldLength: limit)
    }

    private func configuration(_ delivery: PrivateDelivery?) -> BeaconConfiguration {
        BeaconConfiguration(
            app: app, organizationName: "the Harbour team", currentReporter: { .anonymous() },
            transport: NoTransport(), privateDelivery: delivery)
    }

    @Test func itIsOffUnlessTheDeveloperTurnsItOn() {
        let configuration = BeaconConfiguration(
            app: app, organizationName: "the Harbour team", currentReporter: { .anonymous() },
            transport: NoTransport())
        #expect(configuration.privateDelivery == nil)
    }

    @Test func turningItOnAddsASentenceToTheNoticeAndAsksAgain() throws {
        let reporter = Reporter.anonymous()
        let off = configuration(nil).consentNotice(for: reporter)
        let on = configuration(try delivery()).consentNotice(for: reporter)
        #expect(on.version != off.version, "a person who accepted the old notice is asked again")
        #expect(on.points.count == off.points.count + 1)
        let sentence = try #require(on.points.last)
        #expect(sentence.contains("the Harbour team"))
        #expect(!sentence.contains("$ORG"))
        #expect(!sentence.lowercased().contains("github"))
    }

    @Test func aBadPublicKeyFailsWhenItIsSetNotWhenItSends() {
        #expect(throws: PrivateDelivery.Failure.invalidPublicKey) {
            _ = try PrivateDelivery(endpoint: URL(string: "https://x")!, appToken: "t", ownerPublicKey: "not a key")
        }
    }

    @Test func onlyTheOwnersKeyOpensTheMessage() throws {
        let details = try delivery().details(
            id: id, fields: ["cause": "Could not read Acme/Payroll.swift"], app: app, hostSecrets: [],
            noticeVersion: "v1")
        let sealed = try PrivateSealing.seal(details, to: try delivery().ownerPublicKey)
        #expect(!String(decoding: sealed, as: UTF8.self).contains("Payroll"))
        #expect(try PrivateSealing.open(sealed, with: owner) == details)
        #expect(throws: (any Error).self) {
            _ = try PrivateSealing.open(sealed, with: Curve25519.KeyAgreement.PrivateKey())
        }
    }

    @Test func secretsAreSweptAndTheSweepIsRecorded() throws {
        let key = "ghp" + "_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"
        let details = try delivery().details(
            id: id, fields: ["cause": "token \(key) and hunter2-correct-horse"], app: app,
            hostSecrets: ["hunter2-correct-horse"], noticeVersion: nil)
        let cause = try #require(details.fields["cause"])
        #expect(!cause.contains(key))
        #expect(!cause.contains("hunter2-correct-horse"))
        #expect(details.removed.count == 2)
    }

    @Test func fieldsAreCutToTheLimitAndEmptyOnesAreDropped() throws {
        let details = try delivery(limit: 10).details(
            id: id, fields: ["long": String(repeating: "a", count: 50), "blank": ""], app: app, hostSecrets: [],
            noticeVersion: nil)
        #expect(details.fields == ["long": String(repeating: "a", count: 10)])
        #expect(throws: PrivateDelivery.Failure.empty) {
            _ = try delivery().details(id: id, fields: ["blank": ""], app: app, hostSecrets: [], noticeVersion: nil)
        }
    }

    @Test func whatCoveredTheSendingIsSealedIn() throws {
        let agreed = try delivery(consent: .hostAgreement("the Harbour beta agreement")).details(
            id: id, fields: ["a": "b"], app: app, hostSecrets: [], noticeVersion: "ignored")
        #expect(agreed.agreement == "the Harbour beta agreement")
        #expect(agreed.noticeVersion == nil)
        let noticed = try delivery().details(id: id, fields: ["a": "b"], app: app, hostSecrets: [], noticeVersion: "v7")
        #expect(noticed.agreement == nil)
        #expect(noticed.noticeVersion == "v7")
        #expect(noticed.app == "com.example.harbour")
        #expect(noticed.build == "42")
    }

    @Test func aMessageOverTheStoresLimitIsRefusedBeforeItIsSent() async throws {
        let oversize = Data(count: PrivateDelivery.maximumSealedBytes + 1)
        await #expect(throws: PrivateDelivery.Failure.tooLarge(bytes: oversize.count)) {
            try await delivery().send(oversize, id: id, app: app.bundleIdentifier)
        }
    }

    @Test func nothingIsSentUntilThePersonAcceptsTheNoticeThatSaysSo() throws {
        let store = UserDefaultsConsentStore(
            defaults: UserDefaults(suiteName: "beacon.private.tests.\(UUID().uuidString)")!)
        let reporter = Reporter(accountID: "sam")
        var configuration = configuration(try delivery())
        configuration.currentReporter = { reporter }
        configuration.consentStore = store
        #expect(throws: PrivateDelivery.Failure.notConsented) { _ = try configuration.privateDeliveryNoticeVersion() }

        // Accepting the notice WITHOUT the private sentence is not enough.
        let plain = self.configuration(nil).consentNotice(for: reporter)
        store.save(ConsentRecord(acceptedVersion: plain.version, acceptedAt: Date(), accountID: "sam"))
        #expect(throws: PrivateDelivery.Failure.notConsented) { _ = try configuration.privateDeliveryNoticeVersion() }

        let withSentence = configuration.consentNotice(for: reporter)
        store.save(ConsentRecord(acceptedVersion: withSentence.version, acceptedAt: Date(), accountID: "sam"))
        #expect(try configuration.privateDeliveryNoticeVersion() == withSentence.version)
    }

    @Test func offMeansNotEnabledAndANamedAgreementNeedsNoNotice() throws {
        #expect(throws: PrivateDelivery.Failure.notEnabled) { _ = try configuration(nil).privateDeliveryNoticeVersion() }
        let agreed = configuration(try delivery(consent: .hostAgreement("the beta agreement")))
        #expect(try agreed.privateDeliveryNoticeVersion() == nil)
    }
}
