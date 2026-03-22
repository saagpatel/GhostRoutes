import Foundation

/// Haversine distance between two coordinates in meters.
func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
    let earthRadiusMeters = 6_371_000.0
    let dLat = (lat2 - lat1) * .pi / 180.0
    let dLng = (lng2 - lng1) * .pi / 180.0
    let lat1Rad = lat1 * .pi / 180.0
    let lat2Rad = lat2 * .pi / 180.0

    let a = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1Rad) * cos(lat2Rad) * sin(dLng / 2) * sin(dLng / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return earthRadiusMeters * c
}
