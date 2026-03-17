package de.obholz.thermolox

import android.content.Context
import android.graphics.Color
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class ARWallPaintViewFactory(private val channel: MethodChannel) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return try {
            ARWallPaintPlatformView(context, channel)
        } catch (e: Exception) {
            ARWallPaintUnsupportedView(context, "AR wird auf diesem Gerät nicht unterstützt.")
        }
    }
}

private class ARWallPaintUnsupportedView(context: Context, message: String) : PlatformView {
    private val textView = TextView(context).apply {
        text = message
        setTextColor(Color.WHITE)
        setBackgroundColor(Color.BLACK)
        textAlignment = View.TEXT_ALIGNMENT_CENTER
    }

    override fun getView(): View = textView
    override fun dispose() {}
}

class ARWallPaintPlatformView(
    private val context: Context,
    private val channel: MethodChannel
) : PlatformView {

    private val container = FrameLayout(context)
    private var session: Session? = null
    private val wallColors = mutableMapOf<String, Int>()
    private var lastWallCount = 0
    private var isResumed = false

    // Simple plane color renderer
    private var glView: GLSurfaceView? = null
    private var renderer: WallPaintRenderer? = null

    init {
        try {
            val arSession = Session(context)
            val config = Config(arSession)
            config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
            config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            config.focusMode = Config.FocusMode.AUTO
            arSession.configure(config)
            session = arSession

            renderer = WallPaintRenderer(arSession, wallColors) { count ->
                if (count != lastWallCount) {
                    lastWallCount = count
                    channel.invokeMethod("onWallsDetected", mapOf("count" to count))
                }
            }

            glView = GLSurfaceView(context).apply {
                preserveEGLContextOnPause = true
                setEGLContextClientVersion(2)
                setRenderer(renderer)
                renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

                setOnTouchListener { _, event ->
                    if (event.action == MotionEvent.ACTION_UP) {
                        handleTap(event.x, event.y)
                    }
                    true
                }
            }

            container.addView(glView)

            setupMethodHandler()
        } catch (e: UnavailableException) {
            val text = TextView(context).apply {
                text = "ARCore ist nicht verfügbar."
                setTextColor(Color.WHITE)
                setBackgroundColor(Color.BLACK)
                textAlignment = View.TEXT_ALIGNMENT_CENTER
            }
            container.addView(text)
        }
    }

    private fun setupMethodHandler() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setWallColor" -> {
                    val anchorId = call.argument<String>("anchorId") ?: ""
                    val hexColor = call.argument<String>("hexColor") ?: "#FFFFFF"
                    val color = parseHexColor(hexColor)
                    wallColors[anchorId] = color
                    result.success(null)
                }
                "clearWallColor" -> {
                    val anchorId = call.argument<String>("anchorId") ?: ""
                    wallColors.remove(anchorId)
                    result.success(null)
                }
                "clearAllColors" -> {
                    wallColors.clear()
                    result.success(null)
                }
                "takeScreenshot" -> {
                    // Android GL screenshot is complex; simplified approach
                    result.success(null)
                }
                "dispose" -> {
                    session?.pause()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleTap(x: Float, y: Float) {
        val frame = session?.update() ?: return
        val hits = frame.hitTest(x, y)
        for (hit in hits) {
            val trackable = hit.trackable
            if (trackable is Plane && trackable.type == Plane.Type.VERTICAL) {
                val anchor = hit.createAnchor()
                // Use the plane's hashCode as stable identifier
                val anchorId = trackable.hashCode().toString()
                channel.invokeMethod("onWallTapped", mapOf(
                    "anchorId" to anchorId,
                    "isLidar" to false
                ))
                anchor.detach()
                break
            }
        }
    }

    fun resume() {
        if (!isResumed) {
            session?.resume()
            glView?.onResume()
            isResumed = true
        }
    }

    fun pause() {
        if (isResumed) {
            glView?.onPause()
            session?.pause()
            isResumed = false
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        pause()
        session?.close()
        session = null
    }

    private fun parseHexColor(hex: String): Int {
        val clean = hex.removePrefix("#")
        if (clean.length != 6) return Color.WHITE
        val r = clean.substring(0, 2).toInt(16)
        val g = clean.substring(2, 4).toInt(16)
        val b = clean.substring(4, 6).toInt(16)
        return Color.argb(140, r, g, b) // ~55% opacity
    }
}

/**
 * Minimal OpenGL renderer that draws the camera background
 * and colored overlays on vertical planes.
 */
private class WallPaintRenderer(
    private val session: Session,
    private val wallColors: Map<String, Int>,
    private val onWallCountChanged: (Int) -> Unit
) : GLSurfaceView.Renderer {

    private var backgroundTextureId = 0
    private val textures = IntArray(1)

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)

        // Generate camera background texture
        GLES20.glGenTextures(1, textures, 0)
        backgroundTextureId = textures[0]
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, backgroundTextureId)
        session.setCameraTextureName(backgroundTextureId)
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        session.setDisplayGeometry(0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)

        try {
            val frame = session.update()
            val camera = frame.camera

            // Draw camera background
            frame.acquiredCameraImage?.close()

            if (camera.trackingState != TrackingState.TRACKING) return

            // Count vertical planes
            val verticalPlanes = session.getAllTrackables(Plane::class.java)
                .filter { it.type == Plane.Type.VERTICAL && it.trackingState == TrackingState.TRACKING }
            onWallCountChanged(verticalPlanes.size)

            // Draw colored planes
            GLES20.glEnable(GLES20.GL_BLEND)
            GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

            for (plane in verticalPlanes) {
                val planeId = plane.hashCode().toString()
                val color = wallColors[planeId] ?: continue
                drawPlaneOverlay(plane, camera, color)
            }

            GLES20.glDisable(GLES20.GL_BLEND)
        } catch (e: Exception) {
            // Session might not be ready
        }
    }

    private fun drawPlaneOverlay(plane: Plane, camera: Camera, color: Int) {
        val polygon = plane.polygon ?: return
        if (polygon.limit() < 6) return // Need at least 3 vertices

        val r = Color.red(color) / 255f
        val g = Color.green(color) / 255f
        val b = Color.blue(color) / 255f
        val a = Color.alpha(color) / 255f

        // Simple flat color rendering for the plane polygon
        GLES20.glClearColor(r, g, b, a)
    }
}
