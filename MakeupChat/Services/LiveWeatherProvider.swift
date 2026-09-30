import Combine
import CoreLocation
import Foundation

struct LiveWeatherSnapshot: Equatable {
    var temperature: Int? = 25
    var conditionText: String? = "多云"
    var symbolName: String? = "cloud.fill"
    var uvIndex: Int? = 3
    var district = "默认天气"
    var observedAt: Date?

    static let dataSourceURL = URL(string: "https://open-meteo.com/")!
    static let fallback = LiveWeatherSnapshot()
    var uvDescription: String {
        guard let uvIndex else { return "加载中" }
        switch uvIndex {
        case 0...2: return "弱"
        case 3...5: return "中等"
        case 6...7: return "较强"
        case 8...10: return "很强"
        default: return "极强"
        }
    }

    var uvProgress: Double {
        guard let uvIndex else { return 0 }
        return min(max(Double(uvIndex) / 11.0, 0.08), 1)
    }

    var uvSummary: String {
        guard let uvIndex else { return uvDescription }
        return "\(uvDescription) · \(uvIndex)"
    }
}

@MainActor
final class LiveWeatherProvider: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = LiveWeatherProvider()

    @Published private(set) var snapshot = LiveWeatherSnapshot.fallback
    @Published private(set) var isLive = false

    private let locationManager = CLLocationManager()
    private var isLoading = false
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        guard !isLoading else { return }

        if let lastLocation {
            requestWeather(at: lastLocation)
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied, .restricted:
            markLocationUnavailable(as: "未授权")
        @unknown default:
            markLocationUnavailable(as: "定位失败")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            markLocationUnavailable(as: "未授权")
        case .notDetermined:
            break
        @unknown default:
            markLocationUnavailable(as: "定位失败")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !isLoading else { return }
        lastLocation = location
        requestWeather(at: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        markLocationUnavailable(as: "定位失败")
    }

    private func markLocationUnavailable(as district: String) {
        isLoading = false
        isLive = false
        snapshot = Self.fallbackSnapshot(district: district)
    }

    private func requestWeather(at location: CLLocation) {
        guard !isLoading else { return }
        isLoading = true
        Task {
            await loadWeather(at: location)
            isLoading = false
        }
    }

    private func loadWeather(at location: CLLocation) async {
        do {
            let response = try await fetchWeather(at: location)
            let condition = Self.condition(for: response.current.weatherCode, isDay: response.current.isDay == 1)

            snapshot = LiveWeatherSnapshot(
                temperature: Int(response.current.temperature.rounded()),
                conditionText: condition.text,
                symbolName: condition.symbolName,
                uvIndex: max(0, Int(response.current.uvIndex.rounded())),
                district: snapshot.district,
                observedAt: Date(timeIntervalSince1970: response.current.time)
            )
            isLive = true

            await loadDistrict(at: location)
        } catch {
            isLive = false
            snapshot = Self.fallbackSnapshot(district: "离线天气")
        }
    }

    private static func fallbackSnapshot(district: String) -> LiveWeatherSnapshot {
        var fallback = LiveWeatherSnapshot.fallback
        fallback.district = district
        return fallback
    }

    private func fetchWeather(at location: CLLocation) async throws -> OpenMeteoResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day,uv_index"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
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
            guard let place = placemarks.first,
                  let district = place.subLocality ?? place.locality ?? place.administrativeArea,
                  !district.isEmpty else {
                snapshot.district = "地区不可用"
                return
            }
            snapshot.district = district
        } catch {
            // Weather remains usable even if the network reverse-geocoding request fails.
            snapshot.district = "地区不可用"
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
        let time: TimeInterval
        let temperature: Double
        let weatherCode: Int
        let isDay: Int
        let uvIndex: Double

        enum CodingKeys: String, CodingKey {
            case time
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
