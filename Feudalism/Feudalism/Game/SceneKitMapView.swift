//
//  SceneKitMapView.swift
//  Feudalism
//
//  Zamjenjuje GameView+GameScene: prikaz mape preko SceneKit (prava 3D kamera, hitTest, bez skewa).
//

import SwiftUI
import SceneKit
import SpriteKit
import AppKit

private let mapRows = 100
private let mapCols = 100
private let mapWorldW: CGFloat = 4000
private let mapWorldH: CGFloat = 4000
private let cellSizeW: CGFloat = mapWorldW / CGFloat(mapCols)
private let cellSizeH: CGFloat = mapWorldH / CGFloat(mapRows)

// MARK: - Terrain texture (procedural, isto kao SpriteKit)
/// Fallback boja terena kad proceduralna tekstura nije dostupna (nikad ne ostavljamo bijelo).
private let terrainFallbackColor = NSColor(red: 0.65, green: 0.55, blue: 0.42, alpha: 1.0)

/// Piksela po logičkoj ćeliji – veće = oštrija tekstura pri zumiranju (24 = 2400×2400 px).
private let terrainTextureScale = 24

private func makeTerrainCGImage() -> CGImage? {
    let scale = terrainTextureScale
    let w = mapCols * scale
    let h = mapRows * scale
    let terrainPalette: [(CGFloat, CGFloat, CGFloat)] = [
        (0.76, 0.70, 0.55), (0.72, 0.65, 0.48), (0.68, 0.58, 0.42),
        (0.55, 0.42, 0.30), (0.50, 0.38, 0.28), (0.45, 0.35, 0.26),
        (0.58, 0.50, 0.42), (0.82, 0.78, 0.72), (0.78, 0.74, 0.68),
        (0.72, 0.68, 0.62), (0.70, 0.62, 0.50),
    ]
    func terrainColor(row: Int, col: Int) -> (CGFloat, CGFloat, CGFloat) {
        let n = (row &* 31 &+ col) % 997
        let idx = (n &+ (col &* 17) % 311) % terrainPalette.count
        return terrainPalette[idx]
    }
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                             space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    for row in 0..<mapRows {
        for col in 0..<mapCols {
            let c = terrainColor(row: row, col: col)
            ctx.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: 0.92)
            let y = mapRows - 1 - row
            ctx.fill(CGRect(x: col * scale, y: y * scale, width: scale, height: scale))
        }
    }
    return ctx.makeImage()
}

/// Tekstura terena s .nearest da pri zumiranju ostane oštra (bez razmazivanja).
private func makeTerrainTexture() -> Any? {
    guard let cg = makeTerrainCGImage() else { return terrainFallbackColor }
    let skTex = SKTexture(cgImage: cg)
    skTex.filteringMode = .nearest
    return skTex
}

// MARK: - NSView wrapper za SCNView (miš, tipke)
private final class SceneKitMapNSView: NSView {
    var scnView: SCNView?
    var onPanChange: ((CGPoint) -> Void)?
    var onZoomDelta: ((CGFloat) -> Void)?
    var onTiltDelta: ((CGFloat) -> Void)?
    var onClick: ((Int, Int) -> Void)?
    var isPanning = false
    var lastPanLocation: NSPoint = .zero
    var handPanMode = false
    var isEraseMode = false
    var hasObjectSelected: Bool = false
    /// World koordinata → (row, col) za hit na terenu (poziv iz hit testa).
    var onCellHit: ((SCNVector3) -> (row: Int, col: Int)?)?

    override func layout() {
        super.layout()
        if let sv = scnView, bounds.width > 0, bounds.height > 0 {
            sv.frame = bounds
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastPanLocation = convert(event.locationInWindow, from: nil)
        if handPanMode {
            isPanning = true
            NSCursor.closedHand.push()
            return
        }
        guard !isPanning,
              let hit = scnView?.hitTest(lastPanLocation, options: nil).first,
              hit.node.name == "terrain",
              let convert = onCellHit,
              let (row, col) = convert(hit.worldCoordinates) else { return }
        onClick?(row, col)
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let dx = loc.x - lastPanLocation.x
        let dy = loc.y - lastPanLocation.y
        if !isPanning {
            if handPanMode || hypot(dx, dy) > 3 {
                isPanning = true
                NSCursor.closedHand.push()
            } else {
                return
            }
        }
        lastPanLocation = loc
        onPanChange?(CGPoint(x: -dx, y: -dy))
    }

    override func mouseUp(with event: NSEvent) {
        if isPanning {
            isPanning = false
            NSCursor.closedHand.pop()
            NSCursor.openHand.push()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let dy = event.scrollingDeltaY
        if dy != 0 { onZoomDelta?(dy > 0 ? CGFloat(0.15) : CGFloat(-0.15)) }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: onTiltDelta?(0.06)
        case 125: onTiltDelta?(-0.06)
        case 24:  onZoomDelta?(0.15)
        case 27:  onZoomDelta?(-0.15)
        case 0x0D: onPanChange?(CGPoint(x: 0, y: 28))
        case 0x01: onPanChange?(CGPoint(x: 0, y: -28))
        case 0x00: onPanChange?(CGPoint(x: -28, y: 0))
        case 0x02: onPanChange?(CGPoint(x: 28, y: 0))
        default: break
        }
    }
}

/// Ponovno gradi linije rešetke: pozicije (x,z) uvijek iste (ćelije na mjestu), samo debljina linija ovisi o zoomu.
private func refreshGrid(gridNode: SCNNode, zoom: CGFloat) {
    gridNode.childNodes.forEach { $0.removeFromParentNode() }
    let lineColor = NSColor.black.withAlphaComponent(0.85)
    let baseW: CGFloat = 2.5
    let baseH: CGFloat = 8
    let z = max(0.1, min(50, zoom))
    let lineW = baseW / z
    let lineH = baseH / z
    let halfW = mapWorldW / 2
    let halfH = mapWorldH / 2
    var x = -halfW
    while x <= halfW {
        let box = SCNBox(width: lineW, height: lineH, length: mapWorldH, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = lineColor
        box.firstMaterial?.isDoubleSided = true
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        n.position = SCNVector3(x, lineH / 2, 0)
        gridNode.addChildNode(n)
        x += cellSizeW
    }
    var zCoord = -halfH
    while zCoord <= halfH {
        let box = SCNBox(width: mapWorldW, height: lineH, length: lineW, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = lineColor
        box.firstMaterial?.isDoubleSided = true
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        n.position = SCNVector3(0, lineH / 2, zCoord)
        gridNode.addChildNode(n)
        zCoord += cellSizeH
    }
}

/// Iz world pozicije na terenu (teren je u root na 0,0,0) vraća (row, col) ili nil.
private func cellFromMapLocalPosition(_ localPos: SCNVector3) -> (row: Int, col: Int)? {
    let halfW = mapWorldW / 2
    let halfH = mapWorldH / 2
    let col = Int((CGFloat(localPos.x) + halfW) / cellSizeW)
    let row = Int((CGFloat(localPos.z) + halfH) / cellSizeH)
    guard row >= 0, row < mapRows, col >= 0, col < mapCols else { return nil }
    return (row, col)
}

// MARK: - SceneKitMapView (SwiftUI)
struct SceneKitMapView: NSViewRepresentable {
    @EnvironmentObject private var gameState: GameState
    var showGrid: Bool = true
    @Binding var handPanMode: Bool
    var showPivotIndicator: Bool = false
    var isEraseMode: Bool = false
    var onRemoveAt: ((Int, Int) -> Void)?
    var isPlaceMode: Bool { gameState.selectedPlacementObjectId != nil }

    func makeNSView(context: Context) -> NSView {
        let container = SceneKitMapNSView()
        container.wantsLayer = true
        let scnView = SCNView()
        scnView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scnView)
        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: container.topAnchor),
            scnView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scnView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        container.scnView = scnView

        scnView.wantsLayer = true
        scnView.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        scnView.backgroundColor = NSColor(white: 0.15, alpha: 1)
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X

        let halfW = mapWorldW / 2
        let halfH = mapWorldH / 2

        let scene = SCNScene()

        // Mapa: teren, grid, placements – FIKSNI u sceni, NIKAD im ne mijenjamo position/rotation (samo u makeNSView)
        scene.rootNode.position = SCNVector3Zero
        scene.rootNode.eulerAngles = SCNVector3Zero
        let plane = SCNPlane(width: mapWorldW, height: mapWorldH)
        let terrainMat = SCNMaterial()
        terrainMat.diffuse.contents = makeTerrainTexture()
        terrainMat.isDoubleSided = true
        terrainMat.lightingModel = .constant
        plane.materials = [terrainMat]
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.position = SCNVector3(0, 0, 0)
        planeNode.name = "terrain"
        scene.rootNode.addChildNode(planeNode)

        let gridNode = SCNNode()
        gridNode.name = "grid"
        gridNode.position = SCNVector3Zero
        gridNode.eulerAngles = SCNVector3Zero
        refreshGrid(gridNode: gridNode, zoom: gameState.mapCameraSettings.currentZoom)
        scene.rootNode.addChildNode(gridNode)

        let placementsNode = SCNNode()
        placementsNode.name = "placements"
        placementsNode.position = SCNVector3Zero
        placementsNode.eulerAngles = SCNVector3Zero
        scene.rootNode.addChildNode(placementsNode)

        // Samo kamera (i njen target) se pomiče pri panu; mapa je fiksna u sceni
        let cam = SCNCamera()
        cam.zNear = 0.1
        cam.zFar = 500000
        let cameraNode = SCNNode()
        cameraNode.camera = cam
        cameraNode.name = "camera"
        let cameraTarget = SCNNode()
        cameraTarget.name = "cameraTarget"
        cameraTarget.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(cameraTarget)

        let pivotIndicator = makePivotIndicatorNode()
        pivotIndicator.name = "pivotIndicator"
        scene.rootNode.addChildNode(pivotIndicator)

        scene.rootNode.addChildNode(cameraNode)
        let lookAt = SCNLookAtConstraint(target: cameraTarget)
        lookAt.isGimbalLockEnabled = true
        lookAt.worldUp = SCNVector3(0, 1, 0)
        cameraNode.constraints = [lookAt]
        scnView.pointOfView = cameraNode

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .directional
        light.eulerAngles.x = .pi / 2
        light.position = SCNVector3(halfW, 3000, halfH)
        scene.rootNode.addChildNode(light)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        scene.rootNode.addChildNode(ambient)

        context.coordinator.scene = scene
        context.coordinator.placementsNode = placementsNode
        context.coordinator.cameraNode = cameraNode
        context.coordinator.cameraTarget = cameraTarget
        context.coordinator.pivotIndicatorNode = pivotIndicator
        context.coordinator.gridNode = gridNode
        context.coordinator.lastGridZoom = CGFloat(gameState.mapCameraSettings.currentZoom)

        container.onCellHit = { worldPos in
            cellFromMapLocalPosition(worldPos)
        }

        scnView.scene = scene
        applyCamera(cameraNode: cameraNode, targetNode: cameraTarget, settings: gameState.mapCameraSettings)
        gridNode.isHidden = !showGrid
        refreshPlacements(placementsNode, placements: gameState.gameMap.placements)
        DispatchQueue.main.async { gameState.isLevelReady = true }

        container.onPanChange = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.panOffset.x -= delta.x
            s.panOffset.y -= delta.y
            gameState.mapCameraSettings = s
        }
        container.onZoomDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.currentZoom = min(s.zoomMax, max(s.zoomMin, s.currentZoom + delta))
            gameState.mapCameraSettings = s
        }
        container.onTiltDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.tiltAngle = min(MapCameraSettings.tiltMax, max(MapCameraSettings.tiltMin, s.tiltAngle + delta))
            gameState.mapCameraSettings = s
        }
        container.onClick = { [gameState] row, col in
            if isEraseMode, let onRemoveAt = onRemoveAt {
                onRemoveAt(row, col)
                return
            }
            if isPlaceMode {
                _ = gameState.placeSelectedObjectAt(row: row, col: col)
            }
        }
        container.handPanMode = handPanMode
        container.isEraseMode = isEraseMode
        container.hasObjectSelected = isPlaceMode

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let container = nsView as? SceneKitMapNSView,
              let scnView = container.scnView else { return }

        container.handPanMode = handPanMode
        container.isEraseMode = isEraseMode
        container.hasObjectSelected = isPlaceMode

        let coord = context.coordinator
        // Mapa (rootNode, teren, grid, placements) se NIKAD ne dira – samo kamera i target.

        if let cam = coord.cameraNode, let target = coord.cameraTarget {
            applyCamera(cameraNode: cam, targetNode: target, settings: gameState.mapCameraSettings)
        }
        if let pivot = coord.pivotIndicatorNode {
            pivot.position = coord.cameraTarget?.position ?? SCNVector3(
                gameState.mapCameraSettings.panOffset.x,
                0,
                gameState.mapCameraSettings.panOffset.y
            )
            pivot.isHidden = !showPivotIndicator
        }
        if let grid = coord.gridNode {
            grid.isHidden = !showGrid
            let zoom = gameState.mapCameraSettings.currentZoom
            if abs(CGFloat(zoom) - coord.lastGridZoom) > 0.01 {
                coord.lastGridZoom = CGFloat(zoom)
                refreshGrid(gridNode: grid, zoom: zoom)
            }
        }

        refreshPlacements(coord.placementsNode, placements: gameState.gameMap.placements)
    }

    /// Vizualni čvor na mjestu pivota (gdje kamera gleda) – mali disk + križ.
    private func makePivotIndicatorNode() -> SCNNode {
        let container = SCNNode()
        let radius: CGFloat = 120
        let cyl = SCNCylinder(radius: radius, height: 4)
        cyl.firstMaterial?.diffuse.contents = NSColor.systemYellow
        cyl.firstMaterial?.emission.contents = NSColor.systemYellow.withAlphaComponent(0.5)
        cyl.firstMaterial?.isDoubleSided = true
        cyl.firstMaterial?.lightingModel = .constant
        let disk = SCNNode(geometry: cyl)
        disk.position = SCNVector3(0, 2, 0)
        disk.eulerAngles.x = -.pi / 2
        container.addChildNode(disk)
        let barW: CGFloat = 8
        let barLen: CGFloat = radius * 1.6
        let bar = SCNBox(width: barLen, height: barW, length: barW, chamferRadius: 0)
        bar.firstMaterial?.diffuse.contents = NSColor.systemYellow
        bar.firstMaterial?.lightingModel = .constant
        let h = SCNNode(geometry: bar)
        h.position = SCNVector3(0, 4, 0)
        container.addChildNode(h)
        let v = SCNNode(geometry: bar)
        v.position = SCNVector3(0, 4, 0)
        v.eulerAngles.z = .pi / 2
        container.addChildNode(v)
        return container
    }

    /// Samo kamera i target se pomiču. Mapa se NIKAD ne dira.
    /// Kamera: orbita na visini h, radius h, uvijek gleda pivot; 4 strane = puni krug 360°.
    private func applyCamera(cameraNode: SCNNode, targetNode: SCNNode, settings: MapCameraSettings) {
        let baseHeight: CGFloat = 2800
        let h = baseHeight / settings.currentZoom
        let px = settings.panOffset.x
        let pz = settings.panOffset.y
        let rot = CGFloat(-settings.mapRotation)
        let orbitRadius = h
        targetNode.position = SCNVector3(px, 0, pz)
        cameraNode.position = SCNVector3(
            px + sin(rot) * orbitRadius,
            h,
            pz + cos(rot) * orbitRadius
        )
    }

    private func refreshPlacements(_ node: SCNNode?, placements: [Placement]) {
        guard let node = node else { return }
        node.childNodes.forEach { $0.removeFromParentNode() }
        let wallColor = NSColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 0.95)
        let halfW = mapWorldW / 2
        let halfH = mapWorldH / 2
        for p in placements {
            for r in p.row..<(p.row + p.height) {
                for c in p.col..<(p.col + p.width) {
                    let box = SCNBox(width: cellSizeW, height: 8, length: cellSizeH, chamferRadius: 0)
                    box.firstMaterial?.diffuse.contents = wallColor
                    let n = SCNNode(geometry: box)
                    n.position = SCNVector3(
                        CGFloat(c) * cellSizeW - halfW + cellSizeW / 2,
                        4,
                        CGFloat(r) * cellSizeH - halfH + cellSizeH / 2
                    )
                    node.addChildNode(n)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var scene: SCNScene?
        var placementsNode: SCNNode?
        var cameraNode: SCNNode?
        var cameraTarget: SCNNode?
        var pivotIndicatorNode: SCNNode?
        var gridNode: SCNNode?
        var lastGridZoom: CGFloat = 1
    }
}
