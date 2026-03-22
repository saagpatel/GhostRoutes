import SwiftUI

struct GhostAnnotationView: View {
    let ghost: GhostLocation

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(ghostOpacity))

            if let name = ghost.cachedDisplayName {
                Text(name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: .capsule)
            }
        }
    }

    private var ghostOpacity: Double {
        min(0.15 + ghost.ghostlinessScore * 0.05, 0.65)
    }
}
