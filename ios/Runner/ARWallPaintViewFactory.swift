import Flutter
import UIKit

class ARWallPaintViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        if #available(iOS 15.0, *) {
            return ARWallPaintView(
                frame: frame,
                viewIdentifier: viewId,
                messenger: messenger
            )
        } else {
            return ARWallPaintUnsupportedView()
        }
    }
}

/// Fallback for devices without iOS 14+ or LiDAR (iPhone Pro / iPad Pro required)
private class ARWallPaintUnsupportedView: NSObject, FlutterPlatformView {
    func view() -> UIView {
        let label = UILabel()
        label.text = "AR-Wandfarbe erfordert ein iPhone Pro oder iPad Pro mit LiDAR-Sensor und iOS 14+."
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = .black
        label.numberOfLines = 0
        return label
    }
}
