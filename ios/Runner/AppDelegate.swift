import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let registrar = self.registrar(forPlugin: "ARWallPaintView")!
    let factory = ARWallPaintViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "thermolox/ar_wall_paint")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
