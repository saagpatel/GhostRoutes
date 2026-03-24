import SwiftUI

@MainActor
@Observable
final class AnimationState: NSObject {
    var isPlaying = false
    var progress: Double = 0.0
    let duration: TimeInterval = 45
    private var displayLink: CADisplayLink?
    private var playStartTime: CFTimeInterval = 0
    private var playStartProgress: Double = 0

    /// The chronological cutoff date for the current animation progress.
    func cutoffDate(earliest: Date, latest: Date) -> Date {
        let range = latest.timeIntervalSince(earliest)
        return earliest.addingTimeInterval(range * progress)
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        playStartTime = CACurrentMediaTime()
        playStartProgress = progress

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func pause() {
        isPlaying = false
        displayLink?.invalidate()
        displayLink = nil
    }

    func replay() {
        pause()
        progress = 0
        play()
    }

    func seek(to value: Double) {
        progress = value.clamped(to: 0...1)
    }

    @MainActor @objc private func tick() {
        let elapsed = CACurrentMediaTime() - playStartTime
        let newProgress = playStartProgress + elapsed / duration
        if newProgress >= 1.0 {
            progress = 1.0
            pause()
        } else {
            progress = newProgress
        }
    }
}

// MARK: - Animation Controls

struct AnimationControlsView: View {
    @Bindable var state: AnimationState

    var body: some View {
        VStack(spacing: 12) {
            Slider(value: $state.progress, in: 0...1) { editing in
                if editing { state.pause() }
            }
            .tint(Color(red: 0, green: 0.898, blue: 1.0))

            HStack(spacing: 24) {
                Button { state.replay() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                }

                Button { state.isPlaying ? state.pause() : state.play() } label: {
                    Image(systemName: state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
