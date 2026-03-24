import Testing
import Foundation
@testable import GhostRoutes

@Suite("AnimationState")
struct AnimationStateTests {

    private let earliest = Date(timeIntervalSince1970: 1672531200)  // 2023-01-01
    private let latest = Date(timeIntervalSince1970: 1688169600)    // 2023-07-01 (~6 months later)

    @Test("cutoffDate at progress 0.0 returns earliest")
    @MainActor
    func cutoffAtZero() {
        let state = AnimationState()
        state.progress = 0.0

        let cutoff = state.cutoffDate(earliest: earliest, latest: latest)
        #expect(abs(cutoff.timeIntervalSince(earliest)) < 1.0)
    }

    @Test("cutoffDate at progress 1.0 returns latest")
    @MainActor
    func cutoffAtOne() {
        let state = AnimationState()
        state.progress = 1.0

        let cutoff = state.cutoffDate(earliest: earliest, latest: latest)
        #expect(abs(cutoff.timeIntervalSince(latest)) < 1.0)
    }

    @Test("cutoffDate at progress 0.5 returns midpoint")
    @MainActor
    func cutoffAtHalf() {
        let state = AnimationState()
        state.progress = 0.5

        let midpoint = Date(
            timeIntervalSince1970: (earliest.timeIntervalSince1970 + latest.timeIntervalSince1970) / 2
        )
        let cutoff = state.cutoffDate(earliest: earliest, latest: latest)
        #expect(abs(cutoff.timeIntervalSince(midpoint)) < 1.0)
    }

    @Test("replay resets progress to 0")
    @MainActor
    func replayResetsProgress() {
        let state = AnimationState()
        state.progress = 0.75

        state.replay()
        // replay calls play() after setting progress to 0, so pause to check
        state.pause()
        #expect(state.progress == 0.0 || state.progress < 0.01)
    }

    @Test("seek clamps to 0...1 range")
    @MainActor
    func seekClamps() {
        let state = AnimationState()

        state.seek(to: -0.5)
        #expect(state.progress == 0.0)

        state.seek(to: 1.5)
        #expect(state.progress == 1.0)

        state.seek(to: 0.42)
        #expect(abs(state.progress - 0.42) < 0.001)
    }
}
