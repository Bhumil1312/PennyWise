import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Keep vault files out of OS backups until encrypted recovery is implemented.
    for directory in [FileManager.SearchPathDirectory.documentDirectory, .applicationSupportDirectory] {
      if var url = FileManager.default.urls(for: directory, in: .userDomainMask).first {
        do {
          try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try url.setResourceValues(values)
        } catch {
          return false
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
