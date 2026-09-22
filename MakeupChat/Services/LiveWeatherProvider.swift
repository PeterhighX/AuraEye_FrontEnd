import Combine
import CoreLocation
import Foundation

struct LiveWeatherSnapshot: Equatable {
    var temperature = 26
    var conditionText = "多云"
    var symbolName = "cloud.sun.fill"
    var uvIndex = 3
    var district = "福田区"

    static let dataSourceURL = URL(string: "https://open-meteo.com/")!

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
    private var isLoading = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        guard !isLoading else { return }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedAlways ||
                manager.authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !isLoading else { return }
        isLoading = true
        Task { await loadWeather(at: location) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        isLive = false
    }

    private func loadWeather(at location: CLLocation) async {
        defer { isLoading = false }

        do {
            let response = try await fetchWeather(at: location)
            let condition = Self.condition(for: response.current.weatherCode, isDay: response.current.isDay == 1)

            snapshot = LiveWeatherSnapshot(
                temperature: Int(response.current.temperature.rounded()),
                conditionText: condition.text,
                symbolName: condition.symbolName,
                uvIndex: max(0, Int(response.current.uvIndex.rounded())),
                district: snapshot.district
            )
            isLive = true

            await loadDistrict(at: location)
        } catch {
            // Keep the design fallback visible and allow a later start() to retry.
            isLive = false
        }
    }

    private func fetchWeather(at location: CLLocation) async throws -> OpenMeteoResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day,uv_index"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else { throw OpenMeteoError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw OpenMeteoError.invalidResponse
        }
        return try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
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

    private static func condition(for code: Int, isDay: Bool) -> (text: String, symbolName: String) {
        switch code {
        case 0:
            return ("晴", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1:
            return ("晴间多云", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 2:
            return ("多云", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return ("阴", "cloud.fill")
        case 45, 48:
            return ("雾", "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return ("毛毛雨", "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67:
            return ("雨", "cloud.rain.fill")
        case 71, 73, 75, 77:
            return ("雪", "cloud.snow.fill")
        case 80, 81, 82:
            return ("阵雨", "cloud.heavyrain.fill")
        case 85, 86:
            return ("阵雪", "cloud.snow.fill")
        case 95, 96, 99:
            return ("雷雨", "cloud.bolt.rain.fill")
        default:
            return ("多云", "cloud.fill")
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    let current: CurrentWeather

    struct CurrentWeather: Decodable {
        let temperature: Double
        let weatherCode: Int
        let isDay: Int
        let uvIndex: Double

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
            case uvIndex = "uv_index"
        }
    }
}

private enum OpenMeteoError: Error {
    case invalidURL
    case invalidResponse
}
