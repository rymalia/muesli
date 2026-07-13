import Foundation
import Testing
@testable import MuesliNativeApp

@Suite("Feature tour")
struct FeatureTourTests {
    private let tour = FeatureTourCatalog.latest

    @Test("marketing versions compare numeric components and ignore prerelease suffixes")
    func versionComparison() throws {
        #expect(try #require(MarketingVersion("0.7.1")) < #require(MarketingVersion("0.8.0")))
        #expect(try #require(MarketingVersion("0.8")) == #require(MarketingVersion("0.8.0")))
        #expect(try #require(MarketingVersion("0.8.0-preprod.1")) == #require(MarketingVersion("0.8.0")))
        #expect(MarketingVersion("not-a-version") == nil)
    }

    @Test("existing users without legacy version markers see the first feature tour")
    func legacyUpgrade() {
        #expect(FeatureTourPresentationPolicy.shouldPresentAutomatically(
            currentVersion: "0.8.0",
            previousVersion: nil,
            lastPresentedTourVersion: nil,
            hasCompletedOnboarding: true,
            tour: tour
        ))
    }

    @Test("fresh installs and pre-target versions do not see the tour")
    func ineligibleLaunches() {
        #expect(!FeatureTourPresentationPolicy.shouldPresentAutomatically(
            currentVersion: "0.8.0",
            previousVersion: nil,
            lastPresentedTourVersion: nil,
            hasCompletedOnboarding: false,
            tour: tour
        ))
        #expect(!FeatureTourPresentationPolicy.shouldPresentAutomatically(
            currentVersion: "0.7.1",
            previousVersion: "0.7.0",
            lastPresentedTourVersion: nil,
            hasCompletedOnboarding: true,
            tour: tour
        ))
    }

    @Test("upgrade crossing the target version presents once")
    func crossingTarget() {
        #expect(FeatureTourPresentationPolicy.shouldPresentAutomatically(
            currentVersion: "0.8.0-preprod.1",
            previousVersion: "0.7.1",
            lastPresentedTourVersion: nil,
            hasCompletedOnboarding: true,
            tour: tour
        ))
        #expect(!FeatureTourPresentationPolicy.shouldPresentAutomatically(
            currentVersion: "0.8.0",
            previousVersion: "0.7.1",
            lastPresentedTourVersion: "0.8.0",
            hasCompletedOnboarding: true,
            tour: tour
        ))
        #expect(!FeatureTourPresentationPolicy.shouldPresentAutomatically(
            currentVersion: "0.8.1",
            previousVersion: "0.8.0",
            lastPresentedTourVersion: nil,
            hasCompletedOnboarding: true,
            tour: tour
        ))
    }

    @Test("0.8 catalog points each walkthrough step at a unique product location")
    func catalogShape() {
        #expect(tour.version == "0.8.0")
        #expect(tour.steps.count == 4)
        #expect(Set(tour.steps.map(\.id)).count == tour.steps.count)
        #expect(Set(tour.steps.map(\.target)).count == tour.steps.count)

        let authenticatedTour = FeatureTourCatalog.latest(includeCloudCleanup: true)
        #expect(authenticatedTour.steps.count == 5)
        #expect(authenticatedTour.steps.contains { $0.target == .cloudCleanupSetting })

        let modelsStep = tour.steps.last
        #expect(modelsStep?.id == "models")
        #expect(modelsStep?.target == .experimentalModels)
        #expect(modelsStep?.message.contains("Nemotron 3.5") == true)
        #expect(modelsStep?.message.contains("Parakeet Realtime") == true)
        #expect(modelsStep?.message.contains("Indic ASR") == true)
        #expect(modelsStep?.message.contains("Gemma 4") == true)
    }

    @Test("store suppresses fresh installs and presents a legacy upgrade only once")
    func storeLifecycle() throws {
        let suiteName = "FeatureTourTests.storeLifecycle.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FeatureTourStore(defaults: defaults)

        #expect(store.automaticTour(
            currentVersion: "0.8.0",
            hasCompletedOnboarding: false,
            canPresent: false
        ) == nil)

        // A fresh install that later completes onboarding is already recorded at
        // 0.8 and does not receive a second onboarding-like flow.
        #expect(store.automaticTour(
            currentVersion: "0.8.0",
            hasCompletedOnboarding: true,
            canPresent: true
        ) == nil)

        defaults.removePersistentDomain(forName: suiteName)
        let legacyStore = FeatureTourStore(defaults: defaults)
        let presented = try #require(legacyStore.automaticTour(
            currentVersion: "0.8.0",
            hasCompletedOnboarding: true,
            canPresent: true
        ))
        legacyStore.markOffered(presented)

        #expect(legacyStore.automaticTour(
            currentVersion: "0.8.0",
            hasCompletedOnboarding: true,
            canPresent: true
        ) == nil)
    }

    @Test("permission repair defers the tour without consuming upgrade eligibility")
    func permissionRepairDeferral() throws {
        let suiteName = "FeatureTourTests.permissionRepair.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = FeatureTourStore(defaults: defaults)

        #expect(store.automaticTour(
            currentVersion: "0.8.0",
            hasCompletedOnboarding: true,
            canPresent: false
        ) == nil)
        #expect(store.automaticTour(
            currentVersion: "0.8.0",
            hasCompletedOnboarding: true,
            canPresent: true
        ) != nil)
    }
}
