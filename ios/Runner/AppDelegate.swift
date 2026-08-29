import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Clé Google Maps lue depuis Info.plist, elle-même alimentée par
    // ios/Flutter/Secrets.xcconfig (ignoré par git). Aucune clé en dur ici.
    // Si la clé est absente, on n'initialise pas le SDK : l'application
    // affiche alors la carte OpenStreetMap au lieu de planter.
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "CityCareMapsApiKey") as? String,
       !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
