import CoreLocation
import Foundation

@MainActor
final class AppLocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var currentAddress: String?
    @Published private(set) var lastErrorMessage: String?

    private let manager: CLLocationManager
    private let geocoder = CLGeocoder()
    private var geocodedLocationCache: [String: CLLocation] = [:]

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    func refreshLocation() {
        lastErrorMessage = nil

        guard CLLocationManager.locationServicesEnabled() else {
            lastErrorMessage = "Location services are disabled on this device."
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .restricted, .denied:
            lastErrorMessage = "Enable location access in Settings to see nearby posts."
        @unknown default:
            lastErrorMessage = "Location access is unavailable right now."
        }
    }

    func distance(to address: String) async -> CLLocationDistance? {
        guard let currentLocation else { return nil }
        guard let destination = await location(for: address) else { return nil }
        return currentLocation.distance(from: destination)
    }

    private func location(for address: String) async -> CLLocation? {
        let normalized = address
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else { return nil }

        if let cachedLocation = geocodedLocationCache[normalized] {
            return cachedLocation
        }

        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            guard let location = placemarks.first?.location else { return nil }
            geocodedLocationCache[normalized] = location
            return location
        } catch {
            return nil
        }
    }

    private func resolveCurrentAddress(from location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            currentAddress = Self.formattedAddress(from: placemarks.first)
        } catch {
            currentAddress = nil
        }
    }

    static func shortAddress(_ address: String?, limit: Int = 34) -> String? {
        guard let address else { return nil }
        guard address.count > limit else { return address }
        return String(address.prefix(limit - 1)) + "…"
    }

    private static func formattedAddress(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }

        let line1 = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let line2 = [
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        let combined = [line1, line2]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        return combined.isEmpty ? nil : combined
    }
}

extension AppLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if isAuthorized {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }

        Task { @MainActor in
            currentLocation = latestLocation
            await resolveCurrentAddress(from: latestLocation)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            lastErrorMessage = error.localizedDescription
        }
    }
}
