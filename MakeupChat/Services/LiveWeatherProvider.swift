import CoreLocation
import Foundation
import SwiftUI
import WeatherKit

struct LiveWeatherSnapshot: Equatable {
    var temperature = 26
    var conditionText = "多云"
    var symbolName = "cloud.sun.fill"
    var uvIndex = 3
    var district = "福田区"

    var uvDescription: String {
        switch uvIndex {
        case 0...2: return "弱"
        case 3...5: return "中等"
        case 6...7: return "较强"
        case 8...10: return "很强"
        default: return "极强"
        }
    }

    var uvProgress: Double {
        min(max(Double(uvIndex) / 11.0, 0.08), 1)
    }
}

@MainActor
final class LiveWeatherProvider: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var snapshot = LiveWeatherSnapshot()
    @Published private(set) var isLive = false

    private let locationManager = CLLocationManager()
    private var hasRequestedWeather = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
#if targetEnvironment(simulator)
        // WeatherKit's JWT service is not reliable in some beta simulator
        // runtimes. Keep the screen usable with the design fallback; a real
        // device still receives live WeatherKit and location updates.
        isLive = false
        return
#else
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
#endif
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedAlways ||
                manager.authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !hasRequestedWeather else { return }
        hasRequestedWeather = true
        Task { await loadWeather(at: location) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLive = false
    }

    private func loadWeather(at location: CLLocation) async {
        do {
            let response = try await WeatherService.shared.weather(for: location)
            let current = response.currentWeather
            let uvIndex = response.dailyForecast.first?.uvIndex.value ?? snapshot.uvIndex

            snapshot = LiveWeatherSnapshot(
                temperature: Int(current.temperature.converted(to: .celsius).value.rounded()),
                conditionText: Self.conditionText(for: current.symbolName),
                symbolName: current.symbolName,
                uvIndex: uvIndex,
                district: snapshot.district
            )
            isLive = true

            await loadDistrict(at: location)
        } catch {
            // WeatherKit entitlement, network and simulator-location failures use
            // the high-fidelity fallback snapshot instead of blanking the card.
            isLive = false
        }
    }

    private func loadDistrict(at location: CLLocation) async {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let place = placemarks.first else { return }
            snapshot.district = place.subLocality ?? place.locality ?? snapshot.district
        } catch {
            // A missing placemark must never invalidate otherwise valid weather.
        }
    }

    private static func conditionText(for symbolName: String) -> String {
        let value = symbolName.lowercased()
        if value.contains("thunder") { return "雷雨" }
        if value.contains("snow") || value.contains("sleet") { return "雪" }
        if value.contains("rain") || value.contains("drizzle") { return "雨" }
        if value.contains("fog") || value.contains("haze") { return "雾" }
        if value.contains("cloud.sun") || value.contains("cloud.moon") { return "多云" }
        if value.contains("cloud") { return "阴" }
        return "晴"
    }
}
