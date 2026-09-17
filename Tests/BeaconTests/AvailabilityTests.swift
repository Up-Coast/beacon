import Testing
import StoreKit
@testable import Beacon

@Suite("Who a build offers reporting to")
struct AvailabilityTests {

    @Test func theAppStoreEnvironmentSaysWhichKindOfBuildThisIs() {
        #expect(DistributionChannel.channel(for: .xcode) == .development)
        #expect(DistributionChannel.channel(for: .sandbox) == .testFlight)
        #expect(DistributionChannel.channel(for: .production) == .appStore)
    }

    /// The point of `.testBuilds`: a customer who bought the app never
    /// sees a button that files into a repository they can't open.
    @Test func testBuildsOnlyKeepsReportingOutOfTheAppStore() {
        #expect(!DistributionChannel.appStore.offers(.testBuilds))
        #expect(DistributionChannel.testFlight.offers(.testBuilds))
        #expect(DistributionChannel.development.offers(.testBuilds))
    }

    @Test func everyoneMeansEveryone() {
        #expect(DistributionChannel.appStore.offers(.everyone))
    }
}
