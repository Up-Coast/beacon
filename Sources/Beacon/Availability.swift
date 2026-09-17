// Who is offered reporting, and how a build finds out which kind it is.
//
// A report button is for people testing the app. An App Store customer
// can't file into a private repository and shouldn't be shown a
// walkthrough for a tool they can't use, so a host can ask for test builds
// only. Which kind of build this is comes from the App Store's own signed
// record of the install, not from a flag somebody has to remember to flip
// before release.

import Foundation
import StoreKit
import Observation

public enum BeaconAudience: Sendable, Equatable {
    /// Every build offers reporting.
    case everyone
    /// Builds run from Xcode and TestFlight builds do; App Store builds
    /// don't.
    case testBuilds
}

/// Where this copy of the app came from.
public enum DistributionChannel: String, Sendable, Equatable {
    case development
    case testFlight
    case appStore

    /// Read from the App Store's record of this install. When that record
    /// can't be had, a debug build counts as development and anything else
    /// as the App Store: when in doubt, a customer is not shown a tester's
    /// tool.
    public static func current() async -> DistributionChannel {
        do {
            let transaction = try await AppTransaction.shared
            return channel(for: transaction.unsafePayloadValue.environment)
        } catch {
            #if DEBUG
            return .development
            #else
            return .appStore
            #endif
        }
    }

    static func channel(for environment: AppStore.Environment) -> DistributionChannel {
        switch environment {
        case .xcode: .development
        case .sandbox: .testFlight
        default: .appStore
        }
    }

    func offers(_ audience: BeaconAudience) -> Bool {
        switch audience {
        case .everyone: true
        case .testBuilds: self != .appStore
        }
    }
}

@MainActor
@Observable
final class BeaconAvailability {
    static let shared = BeaconAvailability()

    private(set) var isOffered = false

    func resolve(for audience: BeaconAudience) async {
        if audience == .everyone {
            isOffered = true
            return
        }
        let channel = await DistributionChannel.current()
        isOffered = channel.offers(audience)
        Beacon.log.info("this is a \(channel.rawValue) build; reporting is "
                        + (isOffered ? "offered" : "not offered"), category: "beacon")
    }
}
