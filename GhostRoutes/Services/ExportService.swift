import CoreLocation
import MapKit
import UIKit

@MainActor
struct ExportService {

    /// Render the ghost map as a PNG using MKMapSnapshotter + Core Graphics overlay compositing.
    static func renderSnapshot(
        ghosts: [GhostLocation],
        routes: [MapViewModel.RouteSegment],
        region: MKCoordinateRegion,
        size: CGSize = CGSize(width: 390, height: 844),
        scale: CGFloat = 3.0
    ) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = scale
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)

        guard let snapshot = try? await snapshotter.start() else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            snapshot.image.draw(at: .zero)

            let context = ctx.cgContext

            // Draw route polylines
            for segment in routes {
                guard segment.coordinates.count >= 2 else { continue }

                let points = segment.coordinates.map { snapshot.point(for: $0) }

                context.setLineWidth(segment.isGhost ? 2 : 3)
                context.setLineCap(.round)

                if segment.isGhost {
                    let opacity = ghostOpacity(segment.ghostlinessScore ?? 1.0)
                    context.setStrokeColor(
                        UIColor.white.withAlphaComponent(opacity).cgColor
                    )
                    context.setLineDash(phase: 0, lengths: [6, 4])
                } else {
                    context.setStrokeColor(
                        UIColor(red: 0, green: 0.898, blue: 1.0, alpha: 1.0).cgColor
                    )
                    context.setLineDash(phase: 0, lengths: [])
                }

                context.beginPath()
                context.move(to: points[0])
                for point in points.dropFirst() {
                    context.addLine(to: point)
                }
                context.strokePath()
            }

            // Draw ghost circles
            for ghost in ghosts {
                let center = snapshot.point(for: CLLocationCoordinate2D(
                    latitude: ghost.clusterLat,
                    longitude: ghost.clusterLng
                ))
                let radius: CGFloat = 15

                let opacity = ghostOpacity(ghost.ghostlinessScore)

                // Fill
                context.setFillColor(
                    UIColor.white.withAlphaComponent(opacity * 0.3).cgColor
                )
                context.fillEllipse(in: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                ))

                // Stroke
                context.setStrokeColor(
                    UIColor.white.withAlphaComponent(opacity).cgColor
                )
                context.setLineWidth(2)
                context.setLineDash(phase: 0, lengths: [5, 5])
                context.strokeEllipse(in: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: radius * 2, height: radius * 2
                ))
            }
        }
    }

    private static func ghostOpacity(_ score: Double) -> CGFloat {
        CGFloat(min(0.15 + score * 0.05, 0.65))
    }
}
