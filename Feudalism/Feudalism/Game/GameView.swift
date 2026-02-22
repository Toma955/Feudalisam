//
//  GameView.swift
//  Feudalism
//
//  SpriteKit scenu prikazuje u SwiftUI (macOS). Renderiranje ide preko Metal (GPU).
//  Prima showGrid i postavke kamere iz GameState.
//

import SwiftUI
import SpriteKit
import QuartzCore
import AppKit

/// SKView koji prima tipke (WASD, strelice) i prosljeđuje keyDown/keyUp sceni za glatko pomicanje.
private final class KeyableSKView: SKView {
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
    override func rightMouseDown(with event: NSEvent) {
        (scene as? GameScene)?.handleRightOrMiddleMouseDown(with: event)
    }
    override func rightMouseDragged(with event: NSEvent) {
        (scene as? GameScene)?.handleRightOrMiddleMouseDragged(with: event)
    }
    override func rightMouseUp(with event: NSEvent) {
        (scene as? GameScene)?.handleRightOrMiddleMouseUp(with: event)
    }
    override func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 {
            (scene as? GameScene)?.handleRightOrMiddleMouseDown(with: event)
        } else {
            super.otherMouseDown(with: event)
        }
    }
    override func otherMouseDragged(with event: NSEvent) {
        if event.buttonNumber == 2 {
            (scene as? GameScene)?.handleRightOrMiddleMouseDragged(with: event)
        } else {
            super.otherMouseDragged(with: event)
        }
    }
    override func otherMouseUp(with event: NSEvent) {
        if event.buttonNumber == 2 {
            (scene as? GameScene)?.handleRightOrMiddleMouseUp(with: event)
        } else {
            super.otherMouseUp(with: event)
        }
    }
    override func keyDown(with event: NSEvent) {
        scene?.keyDown(with: event)
    }
    override func keyUp(with event: NSEvent) {
        (scene as? GameScene)?.keyUp(with: event)
    }
}

/// Nagib samo preko sublayerTransform – ne dira se anchorPoint ni layer.transform (izbjegava skakanje/offset).
/// tiltAngle u radijanima; perspektiva m34 = -1/800.
private func applyCameraTilt(to layer: CALayer?, tiltAngle: CGFloat) {
    guard let layer else { return }
    var t = CATransform3DIdentity
    t.m34 = -1.0 / 800.0
    t = CATransform3DRotate(t, -tiltAngle, 1, 0, 0)
    layer.sublayerTransform = t
}

/// Projektira točku iz view koordinata (prije tilta) na poziciju gdje se vidi nakon perspektive (isti m34 i kut kao tilt).
private func projectPointForTilt(_ p: CGPoint, viewSize: CGSize, tiltAngle: CGFloat) -> CGPoint {
    let w = viewSize.width
    let h = viewSize.height
    let cx = w / 2
    let cy = h / 2
    let relX = p.x - cx
    let relY = p.y - cy
    let c = cos(tiltAngle)
    let s = sin(tiltAngle)
    let depth = relY * s
    let persp = 1.0 / (1.0 - depth / 800.0)
    return CGPoint(x: cx + relX * persp, y: cy + relY * c * persp)
}

/// Crtanje stupova 90° na mapu – overlay IZVAN nagnutog containera, uvijek okomito prema gore.
private final class CornerPillarsOverlay: NSView {
    var cornerPositions: [CGPoint] = []
    var tiltAngle: CGFloat = 0
    var viewSize: CGSize = .zero
    private let lineLength: CGFloat = 140
    private let lineColor = NSColor(white: 0.15, alpha: 1.0)
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard cornerPositions.count == 4, viewSize.width > 0, viewSize.height > 0 else { return }
        let sz = viewSize
        let h = sz.height
        for pt in cornerPositions {
            let base = projectPointForTilt(pt, viewSize: sz, tiltAngle: tiltAngle)
            let y1 = h - base.y
            let path = NSBezierPath()
            path.move(to: NSPoint(x: base.x, y: y1))
            path.line(to: NSPoint(x: base.x, y: y1 - lineLength))
            lineColor.setStroke()
            path.lineWidth = 4
            path.stroke()
        }
    }
}

/// View koji drži SKView; 3D nagib se primjenjuje na njega. SKView = cijeli bounds da se cijela mapa vidi (zoom out = cijela na ekranu).
private final class CameraTiltContainer: NSView {
    var skView: KeyableSKView?
    var tiltAngle: CGFloat = 20 * .pi / 180
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
        layer?.masksToBounds = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        skView?.frame = bounds
        applyCameraTilt(to: layer, tiltAngle: tiltAngle)
    }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point), let sk = skView else { return super.hitTest(point) }
        let pt = convert(point, to: sk)
        return sk.bounds.contains(pt) ? sk : super.hitTest(point)
    }
}

/// Wrapper: nagnuti container (mapa) + overlay za stupove (nije nagnut, 90° na mapu).
private final class MapWithPillarsWrapper: NSView {
    var tiltContainer: CameraTiltContainer!
    var pillarOverlay: CornerPillarsOverlay!
    override func layout() {
        super.layout()
        tiltContainer?.frame = bounds
        pillarOverlay?.frame = bounds
    }
}

struct GameView: NSViewRepresentable {
    @EnvironmentObject private var gameState: GameState
    var showGrid: Bool = true
    @Binding var handPanMode: Bool
    /// Map Editor: true = klik briše objekt na ćeliji.
    var isEraseMode: Bool = false
    /// Map Editor: callback kad korisnik klikne na ćeliju u erase modu.
    var onRemoveAt: ((Int, Int) -> Void)? = nil

    func makeNSView(context: Context) -> NSView {
        let wrapper = MapWithPillarsWrapper()
        let container = CameraTiltContainer()
        let overlay = CornerPillarsOverlay()
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = .clear
        wrapper.addSubview(container)
        wrapper.addSubview(overlay)
        wrapper.tiltContainer = container
        wrapper.pillarOverlay = overlay

        let view = KeyableSKView()
        container.skView = view
        container.addSubview(view)
        view.wantsLayer = true
        if let l = view.layer {
            l.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            l.magnificationFilter = .nearest
            l.minificationFilter = .nearest
            l.masksToBounds = false
        }
        view.ignoresSiblingOrder = true
        view.showsFPS = false
        view.showsNodeCount = false
        view.preferredFramesPerSecond = 60
        view.allowsTransparency = false
        var sz = view.bounds.size
        if sz.width <= 0 || sz.height <= 0 { sz = CGSize(width: 1024, height: 768) }
        let scene = GameScene(size: sz)
        scene.scaleMode = .aspectFit
        scene.showGrid = showGrid
        scene.cameraSettings = gameState.mapCameraSettings
        scene.selectedObjectId = gameState.selectedPlacementObjectId
        scene.onPlaceAt = { [gameState] row, col in _ = gameState.placeSelectedObjectAt(row: row, col: col) }
        scene.isEraseMode = isEraseMode
        scene.onRemoveAt = onRemoveAt
        scene.onTiltDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.tiltAngle = min(MapCameraSettings.tiltMax, max(MapCameraSettings.tiltMin, s.tiltAngle + delta))
            gameState.mapCameraSettings = s
        }
        scene.onZoomDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.stepZoomPhaseByScroll(zoomIn: delta > 0)
            gameState.mapCameraSettings = s
        }
        scene.onPanChange = { [gameState] screenDelta in
            var s = gameState.mapCameraSettings
            let z = max(0.001, s.currentZoom)
            let a = s.mapRotation
            let dx = (screenDelta.x * cos(-a) - screenDelta.y * sin(-a)) / z
            let dy = (screenDelta.x * sin(-a) + screenDelta.y * cos(-a)) / z
            s.panOffset.x -= dx
            s.panOffset.y -= dy
            gameState.mapCameraSettings = s
        }
        scene.onCornerPositionsInView = { [weak overlay] points, viewSize in
            guard let overlay = overlay else { return }
            DispatchQueue.main.async {
                overlay.cornerPositions = points
                overlay.viewSize = viewSize
                overlay.setNeedsDisplay(overlay.bounds)
            }
        }
        scene.placements = gameState.gameMap.placements
        scene.onLevelReady = { [gameState] in
            DispatchQueue.main.async { gameState.isLevelReady = true }
        }
        view.presentScene(scene)
        container.tiltAngle = gameState.mapCameraSettings.tiltAngle
        applyCameraTilt(to: container.layer, tiltAngle: container.tiltAngle)
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return wrapper
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let wrapper = nsView as? MapWithPillarsWrapper, let container = wrapper.tiltContainer, let skView = container.skView else { return }
        container.tiltAngle = gameState.mapCameraSettings.tiltAngle
        wrapper.pillarOverlay?.tiltAngle = gameState.mapCameraSettings.tiltAngle
        wrapper.pillarOverlay?.setNeedsDisplay(wrapper.pillarOverlay?.bounds ?? .zero)
        guard let scene = skView.scene as? GameScene else { return }
        let newSize = skView.bounds.size
        let sizeChanged = newSize.width > 0 && newSize.height > 0 && (abs(scene.size.width - newSize.width) > 2 || abs(scene.size.height - newSize.height) > 2)
        if sizeChanged {
            scene.size = newSize
            scene.refreshCamera()
        }
        if scene.showGrid != showGrid { scene.showGrid = showGrid }
        scene.handPanMode = handPanMode
        let p = gameState.mapCameraSettings.panOffset
        let sp = scene.cameraSettings.panOffset
        if scene.cameraSettings.initialZoom != gameState.mapCameraSettings.initialZoom
            || scene.cameraSettings.tiltAngle != gameState.mapCameraSettings.tiltAngle
            || scene.cameraSettings.panSpeed != gameState.mapCameraSettings.panSpeed
            || scene.cameraSettings.currentZoom != gameState.mapCameraSettings.currentZoom
            || scene.cameraSettings.mapRotation != gameState.mapCameraSettings.mapRotation
            || sp.x != p.x || sp.y != p.y {
            scene.cameraSettings = gameState.mapCameraSettings
            applyCameraTilt(to: container.layer, tiltAngle: container.tiltAngle)
            wrapper.pillarOverlay?.tiltAngle = gameState.mapCameraSettings.tiltAngle
            wrapper.pillarOverlay?.setNeedsDisplay(wrapper.pillarOverlay?.bounds ?? .zero)
        }
        scene.onPanChange = { [gameState] screenDelta in
            var s = gameState.mapCameraSettings
            let z = max(0.001, s.currentZoom)
            let a = s.mapRotation
            let dx = (screenDelta.x * cos(-a) - screenDelta.y * sin(-a)) / z
            let dy = (screenDelta.x * sin(-a) + screenDelta.y * cos(-a)) / z
            s.panOffset.x -= dx
            s.panOffset.y -= dy
            gameState.mapCameraSettings = s
        }
        scene.selectedObjectId = gameState.selectedPlacementObjectId
        scene.onPlaceAt = { [gameState] row, col in _ = gameState.placeSelectedObjectAt(row: row, col: col) }
        scene.isEraseMode = isEraseMode
        scene.onRemoveAt = onRemoveAt
        let newPlacements = gameState.gameMap.placements
        if scene.placements.count != newPlacements.count {
            scene.placements = newPlacements
        }
    }
}
