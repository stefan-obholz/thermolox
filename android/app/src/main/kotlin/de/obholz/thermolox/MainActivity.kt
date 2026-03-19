package de.obholz.thermolox

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "everloxx/ar_wall_paint"
        )

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "everloxx/ar_wall_paint",
            ARWallPaintViewFactory(channel)
        )
    }
}
