import Flutter
import UIKit
import CoreLocation
import WeatherKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      WeatherKitBridge.register(with: controller.binaryMessenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

private enum WeatherType: String {
  case rain
  case snow
  case cloudy
  case clear
}

private final class WeatherKitBridge {
  private static let channelName = "weatherkit_channel"
  private static let methodName = "getMorningForecast"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == methodName else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard #available(iOS 16.0, *) else {
        result(FlutterError(code: "UNAVAILABLE", message: "WeatherKit requires iOS 16+", details: nil))
        return
      }

      let args = call.arguments as? [String: Any]
      let latitude = (args?["latitude"] as? NSNumber)?.doubleValue ?? 37.57
      let longitude = (args?["longitude"] as? NSNumber)?.doubleValue ?? 126.98

      Task {
        do {
          let payload = try await fetchMorningForecast(latitude: latitude, longitude: longitude)
          result(payload)
        } catch {
          result(FlutterError(code: "WEATHERKIT_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  @available(iOS 16.0, *)
  private static func fetchMorningForecast(
    latitude: Double,
    longitude: Double
  ) async throws -> [String: Any] {
    let service = WeatherService()
    let location = CLLocation(latitude: latitude, longitude: longitude)
    let weather = try await service.weather(for: location)

    let calendar = Calendar.current
    let now = Date()

    let hourlyToday = weather.hourlyForecast.forecast.filter {
      calendar.isDate($0.date, inSameDayAs: now)
    }

    let morningTemps = hourlyToday
      .filter {
        let h = calendar.component(.hour, from: $0.date)
        return h >= 6 && h <= 9
      }
      .map { $0.temperature.value }

    let morningTemp: Double
    if morningTemps.isEmpty {
      morningTemp = weather.currentWeather.temperature.value
    } else {
      morningTemp = morningTemps.reduce(0, +) / Double(morningTemps.count)
    }

    var maxTemp = weather.currentWeather.temperature.value
    var minTemp = weather.currentWeather.temperature.value
    if let daily = weather.dailyForecast.forecast.first(where: {
      calendar.isDate($0.date, inSameDayAs: now)
    }) {
      maxTemp = daily.highTemperature.value
      minTemp = daily.lowTemperature.value
    }

    let conditionText = String(describing: weather.currentWeather.condition).lowercased()
    let maxChance = hourlyToday.map { $0.precipitationChance }.max() ?? 0
    let weatherType = classifyWeatherType(
      conditionText: conditionText,
      precipitationChance: maxChance
    )

    let timeHint = firstPrecipitationHint(hourly: hourlyToday, calendar: calendar)

    return [
      "weatherType": weatherType.rawValue,
      "morningTemp": morningTemp,
      "maxTemp": maxTemp,
      "minTemp": minTemp,
      "timeHint": timeHint,
    ]
  }

  @available(iOS 16.0, *)
  private static func classifyWeatherType(
    conditionText: String,
    precipitationChance: Double
  ) -> WeatherType {
    if conditionText.contains("snow") || conditionText.contains("sleet") || conditionText.contains("blizzard") {
      return .snow
    }
    if conditionText.contains("rain") || conditionText.contains("drizzle") || conditionText.contains("thunder") || precipitationChance >= 0.4 {
      return .rain
    }
    if conditionText.contains("cloud") || conditionText.contains("overcast") || conditionText.contains("fog") || conditionText.contains("haze") {
      return .cloudy
    }
    return .clear
  }

  @available(iOS 16.0, *)
  private static func firstPrecipitationHint(
    hourly: [HourWeather],
    calendar: Calendar
  ) -> String {
    guard let firstWet = hourly.first(where: {
      let c = String(describing: $0.condition).lowercased()
      return c.contains("rain")
        || c.contains("drizzle")
        || c.contains("thunder")
        || c.contains("snow")
        || c.contains("sleet")
    }) else {
      return ""
    }
    let hour = calendar.component(.hour, from: firstWet.date)
    if hour >= 6 && hour < 12 { return "오전에" }
    if hour < 18 { return "오후에" }
    if hour < 22 { return "저녁에" }
    return "밤에"
  }
}
