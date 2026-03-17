import ARKit
import Flutter
import RealityKit
import UIKit

@available(iOS 15.0, *)
class ARWallPaintView: NSObject, FlutterPlatformView, ARSessionDelegate {
    private let arView: ARView
    private let channel: FlutterMethodChannel

    // Wall color state: anchorId → hex color
    private var wallColors: [UUID: UIColor] = [:]
    // Wall overlay entities: anchorId → anchor entity holding the colored plane
    private var wallEntities: [UUID: AnchorEntity] = [:]
    // Track last reported wall count to avoid duplicate callbacks
    private var lastWallCount: Int = 0

    init(frame: CGRect, viewIdentifier viewId: Int64, messenger: FlutterBinaryMessenger) {
        arView = ARView(frame: frame)
        channel = FlutterMethodChannel(
            name: "thermolox/ar_wall_paint",
            binaryMessenger: messenger
        )
        super.init()

        // --- RealityKit scene understanding: automatic occlusion via LiDAR mesh ---
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.environment.sceneUnderstanding.options.insert(.receivesLighting)

        // Enable person occlusion at the rendering level
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            arView.renderOptions.remove(.disablePersonOcclusion)
        }

        arView.session.delegate = self

        // Tap gesture for wall selection
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        setupMethodChannel()
        startSession()
    }

    func view() -> UIView {
        return arView
    }

    // MARK: - AR Session

    private func startSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.vertical]
        config.environmentTexturing = .automatic

        // LiDAR scene reconstruction for furniture/object occlusion
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        // Person segmentation with depth for people occlusion
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }

        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - Method Channel

    private func setupMethodChannel() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(FlutterError(code: "DISPOSED", message: "View disposed", details: nil))
                return
            }
            switch call.method {
            case "setWallColor":
                guard let args = call.arguments as? [String: Any],
                      let anchorIdStr = args["anchorId"] as? String,
                      let hexColor = args["hexColor"] as? String,
                      let anchorId = UUID(uuidString: anchorIdStr) else {
                    result(FlutterError(code: "INVALID_ARGS", message: "anchorId and hexColor required", details: nil))
                    return
                }
                self.setWallColor(anchorId: anchorId, hex: hexColor)
                result(nil)

            case "clearWallColor":
                guard let args = call.arguments as? [String: Any],
                      let anchorIdStr = args["anchorId"] as? String,
                      let anchorId = UUID(uuidString: anchorIdStr) else {
                    result(FlutterError(code: "INVALID_ARGS", message: "anchorId required", details: nil))
                    return
                }
                self.clearWallColor(anchorId: anchorId)
                result(nil)

            case "clearAllColors":
                self.clearAllColors()
                result(nil)

            case "takeScreenshot":
                self.arView.snapshot(saveToHDR: false) { image in
                    if let image = image, let data = image.pngData() {
                        result(FlutterStandardTypedData(bytes: data))
                    } else {
                        result(FlutterError(code: "SCREENSHOT_FAILED", message: "Could not capture screenshot", details: nil))
                    }
                }

            case "dispose":
                self.arView.session.pause()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Wall Coloring

    private func setWallColor(anchorId: UUID, hex: String) {
        let color = colorFromHex(hex).withAlphaComponent(0.80)
        wallColors[anchorId] = color
        rebuildOverlay(for: anchorId)
    }

    private func clearWallColor(anchorId: UUID) {
        wallColors.removeValue(forKey: anchorId)
        removeOverlayEntity(for: anchorId)
    }

    private func clearAllColors() {
        let ids = Array(wallColors.keys)
        wallColors.removeAll()
        for id in ids {
            removeOverlayEntity(for: id)
        }
    }

    private func removeOverlayEntity(for anchorId: UUID) {
        if let entity = wallEntities[anchorId] {
            arView.scene.removeAnchor(entity)
            wallEntities.removeValue(forKey: anchorId)
        }
    }

    // MARK: - Build Wall Color Overlay Entity

    private func rebuildOverlay(for anchorId: UUID) {
        guard let color = wallColors[anchorId] else { return }
        removeOverlayEntity(for: anchorId)

        guard let frame = arView.session.currentFrame else { return }

        for anchor in frame.anchors {
            guard anchor.identifier == anchorId,
                  let planeAnchor = anchor as? ARPlaneAnchor,
                  planeAnchor.alignment == .vertical else { continue }

            addColorOverlay(for: planeAnchor, color: color)
        }
    }

    private func addColorOverlay(for planeAnchor: ARPlaneAnchor, color: UIColor) {
        let extent = planeAnchor.extent
        let center = planeAnchor.center

        // Generate a plane mesh matching the detected wall extent
        let mesh = MeshResource.generatePlane(width: extent.x, depth: extent.z)

        // Semi-transparent color material
        var material = SimpleMaterial()
        material.color = .init(tint: color)
        material.metallic = .init(floatLiteral: 0.0)
        material.roughness = .init(floatLiteral: 0.9)

        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        // Position the entity at the plane's center offset relative to the anchor
        modelEntity.position = SIMD3<Float>(center.x, center.y, center.z)

        // Attach to the existing AR plane anchor
        let anchorEntity = AnchorEntity(.anchor(identifier: planeAnchor.identifier))
        anchorEntity.addChild(modelEntity)

        arView.scene.addAnchor(anchorEntity)
        wallEntities[planeAnchor.identifier] = anchorEntity
    }

    // MARK: - Tap Handling

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)

        // First try: existing plane geometry (most accurate)
        if let query = arView.makeRaycastQuery(
            from: location,
            allowing: .existingPlaneGeometry,
            alignment: .vertical
        ) {
            let results = arView.session.raycast(query)
            if let hit = results.first, let anchor = hit.anchor {
                channel.invokeMethod("onWallTapped", arguments: [
                    "anchorId": anchor.identifier.uuidString,
                    "isLidar": true,
                ])
                return
            }
        }

        // Fallback: estimated plane
        if let query = arView.makeRaycastQuery(
            from: location,
            allowing: .estimatedPlane,
            alignment: .vertical
        ) {
            let results = arView.session.raycast(query)
            if let hit = results.first, let anchor = hit.anchor {
                channel.invokeMethod("onWallTapped", arguments: [
                    "anchorId": anchor.identifier.uuidString,
                    "isLidar": true,
                ])
                return
            }
        }
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                // If this wall already has a color assigned, add the overlay
                if let color = wallColors[planeAnchor.identifier] {
                    addColorOverlay(for: planeAnchor, color: color)
                }
                updateWallCount()
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                // Rebuild the overlay if this wall has a color (plane extent may have changed)
                if wallColors[planeAnchor.identifier] != nil {
                    rebuildOverlay(for: planeAnchor.identifier)
                }
                updateWallCount()
            }
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            wallColors.removeValue(forKey: anchor.identifier)
            removeOverlayEntity(for: anchor.identifier)
        }
        updateWallCount()
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state: String
        switch camera.trackingState {
        case .normal:
            state = "normal"
        case .limited(let reason):
            switch reason {
            case .initializing:           state = "initializing"
            case .excessiveMotion:        state = "excessiveMotion"
            case .insufficientFeatures:   state = "insufficientFeatures"
            case .relocalizing:           state = "relocalizing"
            @unknown default:             state = "limited"
            }
        case .notAvailable:
            state = "notAvailable"
        }
        channel.invokeMethod("onTrackingStateChanged", arguments: ["state": state])
    }

    // MARK: - Helpers

    private func updateWallCount() {
        let count = arView.session.currentFrame?.anchors
            .compactMap { $0 as? ARPlaneAnchor }
            .filter { $0.alignment == .vertical }
            .count ?? 0
        if count != lastWallCount {
            lastWallCount = count
            channel.invokeMethod("onWallsDetected", arguments: ["count": count])
        }
    }

    private func colorFromHex(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6,
              let rgb = UInt64(hexSanitized, radix: 16) else { return .white }
        return UIColor(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
