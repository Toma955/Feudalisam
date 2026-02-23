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

/// Učita sliku za kursor iz Icons ili bundlea po imenu (bez ekstenzije).
private func loadCursorImage(named name: String) -> NSImage? {
    if let img = NSImage(named: name) { return img }
    for sub in ["Icons", "icons", "Feudalism/Icons", "Feudalism/icons", nil] as [String?] {
        let url: URL? = sub != nil
            ? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: sub)
            : Bundle.main.url(forResource: name, withExtension: "png")
        if let url = url, let img = NSImage(contentsOf: url) { return img }
    }
    return nil
}

/// Veličina kursora u pikselima (ista za mač i buzdovan).
private let gameCursorSize: CGFloat = 32

/// Crtaj sliku u 32×32 s opcionalnom rotacijom 90° udesno; hot spot u centru.
private func makeCursorImage(from src: NSImage, rotate90Clockwise: Bool) -> NSCursor {
    guard src.isValid, src.size.width > 0, src.size.height > 0 else { return .arrow }
    let srcSize = src.size
    let scale = min(gameCursorSize / srcSize.width, gameCursorSize / srcSize.height)
    let scaledW = srcSize.width * scale
    let scaledH = srcSize.height * scale

    let out = NSImage(size: NSSize(width: gameCursorSize, height: gameCursorSize))
    out.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    let ctx = NSGraphicsContext.current?.cgContext
    if rotate90Clockwise {
        ctx?.translateBy(x: gameCursorSize / 2, y: gameCursorSize / 2)
        ctx?.rotate(by: .pi / 2)
        ctx?.translateBy(x: -scaledW / 2, y: -scaledH / 2)
    } else {
        ctx?.translateBy(x: (gameCursorSize - scaledW) / 2, y: (gameCursorSize - scaledH) / 2)
    }
    src.draw(in: CGRect(x: 0, y: 0, width: scaledW, height: scaledH),
             from: CGRect(origin: .zero, size: srcSize),
             operation: .sourceOver,
             fraction: 1)
    out.unlockFocus()

    let hotSpot = NSPoint(x: gameCursorSize / 2, y: gameCursorSize / 2)
    return NSCursor(image: out, hotSpot: hotSpot)
}

/// Kursor mača: sword_mouse.png, 32×32, rotiran 90° udesno.
private func makeSwordCursor() -> NSCursor {
    guard let src = loadCursorImage(named: "sword_mouse") else { return .arrow }
    return makeCursorImage(from: src, rotate90Clockwise: true)
}

/// Kursor buzdovana: mace_mouse.png, iste dimenzije (32×32), bez rotacije.
private func makeMaceCursor() -> NSCursor {
    guard let src = loadCursorImage(named: "mace_mouse") else { return .arrow }
    return makeCursorImage(from: src, rotate90Clockwise: false)
}

// MARK: - NSView wrapper za SCNView (miš, tipke)
private final class SceneKitMapNSView: NSView {
    var scnView: SCNView?
    var onPanChange: ((CGPoint) -> Void)?
    var onZoomDelta: ((CGFloat) -> Void)?
    var onRotationDelta: ((CGFloat) -> Void)?
    var onTiltDelta: ((CGFloat) -> Void)?
    var onClick: ((Int, Int) -> Void)?
    var isPanning = false
    var lastPanLocation: NSPoint = .zero
    var handPanMode = false
    var isEraseMode = false
    var hasObjectSelected: Bool = false
    /// World koordinata → (row, col) za hit na terenu (poziv iz hit testa).
    var onCellHit: ((SCNVector3) -> (row: Int, col: Int)?)?
    /// Poziva se pri pomicanju miša – za ghost objekta (npr. zid) na kursoru.
    var onMouseMove: ((NSPoint) -> Void)?
    /// Desni klik (npr. otkaz place mode) – ne postavlja objekt.
    var onRightClick: (() -> Void)?
    /// Poziva se nakon uspješnog place da se odmah osvježe čvorovi na sceni (ne čeka updateNSView).
    var onPlacementsDidChange: (() -> Void)?
    private var keyMonitor: Any?
    private var rightClickMonitor: Any?
    private var trackingArea: NSTrackingArea?
    /// Lijevi klik: hit test na mouseDown, poziv onClick tek na mouseUp ako nije bilo pomicanja (da se ne pomiješa s panom).
    private var pendingClickCell: (row: Int, col: Int)?
    private static let clickDragThreshold: CGFloat = 6
    private var mouseDownLocation: NSPoint = .zero
    /// Kad true: dva prsta = pan, pinch = zoom, rotacija = mapRotation. Kad false: miš (povuci = pan, scroll = zoom).
    var useTrackpad: Bool = true
    private var magnifyMonitor: Any?
    private var rotateMonitor: Any?
    /// Jedna gesta pinch = jedan korak zooma; akumuliramo dok traje gesta, na .ended šaljemo jedan korak.
    private var magnifyAccumulator: CGFloat = 0
    private static let magnifyThreshold: CGFloat = 0.02
    /// Jedna gesta rotacije = jedna strana svijeta (kao klik na kompas); akumuliramo kut, na .ended šaljemo ±90°.
    private var rotateAccumulator: CGFloat = 0
    private static let rotateThreshold: CGFloat = 0.15

    private static let swordCursor: NSCursor = makeSwordCursor()
    private static let maceCursor: NSCursor = makeMaceCursor()

    /// Odabrani alat u panelu Alati ("sword", "mace", …). Određuje koji kursor se prikazuje (mač ili buzdovan).
    var selectedToolsPanelItem: String?

    override func resetCursorRects() {
        super.resetCursorRects()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if handPanMode {
            addCursorRect(bounds, cursor: .openHand)
        } else {
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    override func layout() {
        super.layout()
        if let sv = scnView, bounds.width > 0, bounds.height > 0 {
            sv.frame = bounds
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            removeTrackingArea(ta)
            trackingArea = nil
        }
        guard bounds.width > 0, bounds.height > 0 else { return }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        onMouseMove?(loc)
    }

    override func rotate(with event: NSEvent) {
        let phase = event.phase
        if phase.contains(.began) { rotateAccumulator = 0 }
        if phase.contains(.changed) { rotateAccumulator += CGFloat(event.rotation) * .pi / 180 }
        if phase.contains(.ended) || phase.contains(.cancelled) {
            if rotateAccumulator > Self.rotateThreshold {
                onRotationDelta?(.pi / 2)
            } else if rotateAccumulator < -Self.rotateThreshold {
                onRotationDelta?(-.pi / 2)
            }
            rotateAccumulator = 0
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
            installKeyMonitor()
            installRightClickMonitor()
            installTrackpadMonitorsIfNeeded()
        } else {
            removeKeyMonitor()
            removeRightClickMonitor()
            removeTrackpadMonitors()
        }
    }

    func installTrackpadMonitorsIfNeeded() {
        guard useTrackpad, window != nil, magnifyMonitor == nil else { return }
        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let self = self, self.window?.isKeyWindow == true else { return event }
            let phase = event.phase
            if phase.contains(.began) { self.magnifyAccumulator = 0 }
            if phase.contains(.changed) { self.magnifyAccumulator += event.magnification }
            if phase.contains(.ended) || phase.contains(.cancelled) {
                if self.magnifyAccumulator > Self.magnifyThreshold {
                    self.onZoomDelta?(1)
                } else if self.magnifyAccumulator < -Self.magnifyThreshold {
                    self.onZoomDelta?(-1)
                }
                self.magnifyAccumulator = 0
            }
            return nil
        }
        // Rotaciju ne hvatimo monitorom (može blokirati isporuku); view prima rotate(with:) iz responder lanca.
        rotateMonitor = nil
    }

    func removeTrackpadMonitors() {
        if let m = magnifyMonitor { NSEvent.removeMonitor(m); magnifyMonitor = nil }
        if let m = rotateMonitor { NSEvent.removeMonitor(m); rotateMonitor = nil }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil, window != nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window != nil, self.window!.isKeyWindow else { return event }
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
    }

    private func installRightClickMonitor() {
        guard rightClickMonitor == nil, window != nil else { return }
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self = self, self.window == event.window else { return event }
            let locInView = self.convert(event.locationInWindow, from: nil)
            if self.bounds.contains(locInView) {
                self.onRightClick?()
                return nil
            }
            return event
        }
    }

    private func removeRightClickMonitor() {
        if let m = rightClickMonitor {
            NSEvent.removeMonitor(m)
            rightClickMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: onRightClick?(); return true
        case 126: onTiltDelta?(0.06); return true
        case 125: onTiltDelta?(-0.06); return true
        case 0x0D: onPanChange?(CGPoint(x: 0, y: 28)); return true
        case 0x01: onPanChange?(CGPoint(x: 0, y: -28)); return true
        case 0x00: onPanChange?(CGPoint(x: -28, y: 0)); return true
        case 0x02: onPanChange?(CGPoint(x: 28, y: 0)); return true
        default: return false
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }
    override func resignFirstResponder() -> Bool { true }

    /// Donji bar (Nazad, Zid, Tržnica) mora primati klikove – vrati nil za područje bara da SwiftUI gumbi rade.
    private static let bottomBarHitTestHeight: CGFloat = 140

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        // Ispod ove visine je donji bar; ne uzimaj hit da Nazad, Zid i Market primaju klik.
        if point.y < Self.bottomBarHitTestHeight { return nil }
        return self
    }

    /// Kad hit test ne uspije, postavi ovu poruku da parent može prikazati alert (opcionalno).
    var onPlacementError: ((String) -> Void)?
    /// Kopija odabranog objekta za postavljanje (ažurira se u updateNSView) da klik uvijek vidi aktualnu vrijednost.
    var currentSelectedPlacementObjectId: String?

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastPanLocation = convert(event.locationInWindow, from: nil)
        mouseDownLocation = lastPanLocation
        pendingClickCell = nil
        guard event.buttonNumber == 0 else { return }
        if handPanMode {
            isPanning = true
            NSCursor.closedHand.push()
            return
        }
        if isPanning { return }
        guard let sv = scnView else {
            onPlacementError?("Scena nije spremna (scnView je nil).")
            return
        }
        let hitPointInView = convert(lastPanLocation, to: sv)
        guard sv.bounds.contains(hitPointInView) else {
            onPlacementError?("Klik izvan područja mape.")
            return
        }
        let hitOptions: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .categoryBitMask: 1
        ]
        let hits = sv.hitTest(hitPointInView, options: hitOptions)
        // Samo teren – da klik preko zida/tržnice pogodi ćeliju ispod, ne 3D model (placements imaju categoryBitMask 0).
        guard let hit = hits.first(where: { $0.node.name == "terrain" }),
              let convert = onCellHit,
              let (row, col) = convert(hit.worldCoordinates) else {
            if hits.isEmpty { onPlacementError?("Klik nije pogodio teren.") }
            return
        }
        pendingClickCell = (row, col)
    }

    override func rightMouseDown(with event: NSEvent) {
        pendingClickCell = nil
        onRightClick?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 0 else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let dx = loc.x - lastPanLocation.x
        let dy = loc.y - lastPanLocation.y
        if !isPanning {
            let dist = hypot(loc.x - mouseDownLocation.x, loc.y - mouseDownLocation.y)
            if dist > Self.clickDragThreshold { pendingClickCell = nil }
            if handPanMode || dist > Self.clickDragThreshold {
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
        if event.buttonNumber == 0, !isPanning, let cell = pendingClickCell {
            onClick?(cell.row, cell.col)
        }
        pendingClickCell = nil
        if isPanning {
            isPanning = false
            NSCursor.closedHand.pop()
            NSCursor.openHand.push()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if useTrackpad {
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            if dx != 0 || dy != 0 {
                onPanChange?(CGPoint(x: -dx, y: -dy))
            }
        } else {
            let dy = event.scrollingDeltaY
            if dy != 0 { onZoomDelta?(dy > 0 ? CGFloat(0.15) : CGFloat(-0.15)) }
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onRightClick?()
        case 126: onTiltDelta?(0.06)
        case 125: onTiltDelta?(-0.06)
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

/// Sredina ćelije (row, col) u world koordinatama (y = 4 kao placements).
private func worldPositionAtCell(row: Int, col: Int) -> SCNVector3 {
    let halfW = mapWorldW / 2
    let halfH = mapWorldH / 2
    let x = CGFloat(col) * cellSizeW - halfW + cellSizeW / 2
    let z = CGFloat(row) * cellSizeH - halfH + cellSizeH / 2
    return SCNVector3(x, 4, z)
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

    /// Pred-učitanje resursa igre tijekom početne animacije (teren, zid .obj). Pozovi iz IntroView.onAppear.
    static func preloadGameAssets() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = makeTerrainTexture()
            DispatchQueue.main.async {
                _ = Wall.loadSceneKitNode(from: .main)
            }
        }
    }

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
        planeNode.categoryBitMask = 1
        scene.rootNode.addChildNode(planeNode)

        let gridNode = SCNNode()
        gridNode.name = "grid"
        gridNode.categoryBitMask = 1
        gridNode.position = SCNVector3Zero
        gridNode.eulerAngles = SCNVector3Zero
        refreshGrid(gridNode: gridNode, zoom: gameState.mapCameraSettings.currentZoom)
        scene.rootNode.addChildNode(gridNode)

        // categoryBitMask 0 da klikovi prolaze kroz postavljenje (zid, tržnica) i pogode teren – inače ne možeš graditi drugi objekt na praznu ćeliju kad klikneš preko postojećeg.
        let placementsNode = SCNNode()
        placementsNode.name = "placements"
        placementsNode.position = SCNVector3Zero
        placementsNode.eulerAngles = SCNVector3Zero
        placementsNode.categoryBitMask = 0
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

        let coord = context.coordinator
        coord.scene = scene
        coord.placementsNode = placementsNode
        coord.cameraNode = cameraNode
        coord.cameraTarget = cameraTarget
        coord.pivotIndicatorNode = pivotIndicator
        coord.gridNode = gridNode
        // Template za postavljeni zid (1×1) – širina/dubina na ćeliju, visina iz omjera modela.
        if let placementWallNode = Wall.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            placementWallNode.position = SCNVector3Zero
            templateContainer.addChildNode(placementWallNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = cellSizeW / dx
            let scaleZ = cellSizeH / dz
            let scaleY = min(scaleX, scaleZ)
            placementWallNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.wallPlacementTemplate = templateContainer
            // Ghost = klon templatea da bude ista veličina kao postavljeni zid. Dupliciraj materijale da zelena
            // ostane samo na ghostu, a postavljeni zidovi (klonovi templatea) ostanu u originalnoj teksturi.
            let ghostNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostNode)
            ghostNode.name = "ghostPlacement"
            ghostNode.isHidden = true
            ghostNode.categoryBitMask = 0
            ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostNode)
            scene.rootNode.addChildNode(ghostNode)
            coord.ghostPlacementNode = ghostNode
        } else {
            let ghostNode = makeGhostWallNode()
            ghostNode.name = "ghostPlacement"
            ghostNode.isHidden = true
            ghostNode.categoryBitMask = 0
            ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
            scene.rootNode.addChildNode(ghostNode)
            coord.ghostPlacementNode = ghostNode
        }
        // Template i ghost za Tržnicu (Market) – 3×3 ćelije; zeleni duh pri pomicanju, puni model pri kliku.
        let marketCellSize = 3
        if let placementMarketNode = Market.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            placementMarketNode.position = SCNVector3Zero
            templateContainer.addChildNode(placementMarketNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(marketCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(marketCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            placementMarketNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.marketPlacementTemplate = templateContainer
            let ghostNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostNode)
            ghostNode.name = "ghostMarket"
            ghostNode.isHidden = true
            ghostNode.categoryBitMask = 0
            ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostNode)
            scene.rootNode.addChildNode(ghostNode)
            coord.ghostMarketNode = ghostNode
        } else {
            let ghostNode = makeGhostMarketNode()
            ghostNode.name = "ghostMarket"
            ghostNode.isHidden = true
            ghostNode.categoryBitMask = 0
            ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
            scene.rootNode.addChildNode(ghostNode)
            coord.ghostMarketNode = ghostNode
        }
        // Template i ghost za Mlin (Windmill) – 3×3 ćelije; zeleni duh pri pomicanju.
        let windmillCellSize = 3
        if let placementWindmillNode = Windmill.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            placementWindmillNode.position = SCNVector3Zero
            templateContainer.addChildNode(placementWindmillNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(windmillCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(windmillCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            placementWindmillNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.windmillPlacementTemplate = templateContainer
            let ghostNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostNode)
            ghostNode.name = "ghostWindmill"
            ghostNode.isHidden = true
            ghostNode.categoryBitMask = 0
            ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostNode)
            scene.rootNode.addChildNode(ghostNode)
            coord.ghostWindmillNode = ghostNode
        } else {
            let ghostNode = makeGhostWindmillNode()
            ghostNode.name = "ghostWindmill"
            ghostNode.isHidden = true
            ghostNode.categoryBitMask = 0
            ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
            scene.rootNode.addChildNode(ghostNode)
            coord.ghostWindmillNode = ghostNode
        }
        // Template i ghost za Pekaru (Bakery) – 2×2 ćelije.
        let bakeryCellSize = 2
        if let bakeryNode = Bakery.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            bakeryNode.position = SCNVector3Zero
            templateContainer.addChildNode(bakeryNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(bakeryCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(bakeryCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            bakeryNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.bakeryPlacementTemplate = templateContainer
            let ghostBakeryNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostBakeryNode)
            ghostBakeryNode.name = "ghostBakery"
            ghostBakeryNode.isHidden = true
            ghostBakeryNode.categoryBitMask = 0
            ghostBakeryNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostBakeryNode)
            scene.rootNode.addChildNode(ghostBakeryNode)
            coord.ghostBakeryNode = ghostBakeryNode
        } else {
            let ghostBakeryNode = makeGhostBakeryNode()
            ghostBakeryNode.name = "ghostBakery"
            ghostBakeryNode.isHidden = true
            ghostBakeryNode.categoryBitMask = 0
            ghostBakeryNode.childNodes.forEach { $0.categoryBitMask = 0 }
            scene.rootNode.addChildNode(ghostBakeryNode)
            coord.ghostBakeryNode = ghostBakeryNode
        }

        // Template i ghost za Kokošinjac (Chicken) i Kukuruz (Corn) – 2×2 ćelije.
        let farmObjCellSize = 2
        if let chickenNode = Chicken.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            chickenNode.position = SCNVector3Zero
            templateContainer.addChildNode(chickenNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(farmObjCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(farmObjCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            chickenNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.chickenPlacementTemplate = templateContainer
            let ghostChicken = templateContainer.clone()
            duplicateMaterialsRecursive(ghostChicken)
            ghostChicken.name = "ghostChicken"
            ghostChicken.isHidden = true
            ghostChicken.categoryBitMask = 0
            ghostChicken.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostChicken)
            scene.rootNode.addChildNode(ghostChicken)
            coord.ghostChickenNode = ghostChicken
        } else {
            let ghostChicken = makeGhostFarmObjNode(cellW: farmObjCellSize, cellH: farmObjCellSize)
            ghostChicken.name = "ghostChicken"
            ghostChicken.isHidden = true
            ghostChicken.categoryBitMask = 0
            scene.rootNode.addChildNode(ghostChicken)
            coord.ghostChickenNode = ghostChicken
        }
        if let cornNode = Corn.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            cornNode.position = SCNVector3Zero
            templateContainer.addChildNode(cornNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(farmObjCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(farmObjCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            cornNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.cornPlacementTemplate = templateContainer
            let ghostCorn = templateContainer.clone()
            duplicateMaterialsRecursive(ghostCorn)
            ghostCorn.name = "ghostCorn"
            ghostCorn.isHidden = true
            ghostCorn.categoryBitMask = 0
            ghostCorn.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostCorn)
            scene.rootNode.addChildNode(ghostCorn)
            coord.ghostCornNode = ghostCorn
        } else {
            let ghostCorn = makeGhostFarmObjNode(cellW: farmObjCellSize, cellH: farmObjCellSize)
            ghostCorn.name = "ghostCorn"
            ghostCorn.isHidden = true
            ghostCorn.categoryBitMask = 0
            scene.rootNode.addChildNode(ghostCorn)
            coord.ghostCornNode = ghostCorn
        }

        // Template i ghost za Smočnicu (Granary) – 2×2 ćelije.
        let granaryCellSize = 2
        if let granaryNode = Granary.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            granaryNode.position = SCNVector3Zero
            templateContainer.addChildNode(granaryNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(granaryCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(granaryCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            granaryNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.granaryPlacementTemplate = templateContainer
            let ghostGranaryNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostGranaryNode)
            ghostGranaryNode.name = "ghostGranary"
            ghostGranaryNode.isHidden = true
            ghostGranaryNode.categoryBitMask = 0
            ghostGranaryNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostGranaryNode)
            scene.rootNode.addChildNode(ghostGranaryNode)
            coord.ghostGranaryNode = ghostGranaryNode
        } else {
            let ghostGranaryNode = makeGhostFarmObjNode(cellW: granaryCellSize, cellH: granaryCellSize)
            ghostGranaryNode.name = "ghostGranary"
            ghostGranaryNode.isHidden = true
            ghostGranaryNode.categoryBitMask = 0
            scene.rootNode.addChildNode(ghostGranaryNode)
            coord.ghostGranaryNode = ghostGranaryNode
        }

        // Template i ghost za Zdenac (Well) i Hotel – 2×2 ćelije (House button).
        let houseObjCellSize = 2
        if let wellNode = Well.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            wellNode.position = SCNVector3Zero
            templateContainer.addChildNode(wellNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(houseObjCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(houseObjCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            wellNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.wellPlacementTemplate = templateContainer
            let ghostWellNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostWellNode)
            ghostWellNode.name = "ghostWell"
            ghostWellNode.isHidden = true
            ghostWellNode.categoryBitMask = 0
            ghostWellNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostWellNode)
            scene.rootNode.addChildNode(ghostWellNode)
            coord.ghostWellNode = ghostWellNode
        } else {
            let ghostWellNode = makeGhostFarmObjNode(cellW: houseObjCellSize, cellH: houseObjCellSize)
            ghostWellNode.name = "ghostWell"
            ghostWellNode.isHidden = true
            ghostWellNode.categoryBitMask = 0
            scene.rootNode.addChildNode(ghostWellNode)
            coord.ghostWellNode = ghostWellNode
        }
        if let hotelNode = Hotel.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            hotelNode.position = SCNVector3Zero
            templateContainer.addChildNode(hotelNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(houseObjCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(houseObjCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            hotelNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.hotelPlacementTemplate = templateContainer
            let ghostHotelNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostHotelNode)
            ghostHotelNode.name = "ghostHotel"
            ghostHotelNode.isHidden = true
            ghostHotelNode.categoryBitMask = 0
            ghostHotelNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostHotelNode)
            scene.rootNode.addChildNode(ghostHotelNode)
            coord.ghostHotelNode = ghostHotelNode
        } else {
            let ghostHotelNode = makeGhostFarmObjNode(cellW: houseObjCellSize, cellH: houseObjCellSize)
            ghostHotelNode.name = "ghostHotel"
            ghostHotelNode.isHidden = true
            ghostHotelNode.categoryBitMask = 0
            scene.rootNode.addChildNode(ghostHotelNode)
            coord.ghostHotelNode = ghostHotelNode
        }

        // Template i ghost za Željezaru (Iron) i Kamenolom (Stone) – 2×2 ćelije (Rudnik/Industrija).
        let industryObjCellSize = 2
        if let ironNode = Iron.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            ironNode.position = SCNVector3Zero
            templateContainer.addChildNode(ironNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(industryObjCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(industryObjCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            ironNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.ironPlacementTemplate = templateContainer
            let ghostIronNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostIronNode)
            ghostIronNode.name = "ghostIron"
            ghostIronNode.isHidden = true
            ghostIronNode.categoryBitMask = 0
            ghostIronNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostIronNode)
            scene.rootNode.addChildNode(ghostIronNode)
            coord.ghostIronNode = ghostIronNode
        } else {
            let ghostIronNode = makeGhostFarmObjNode(cellW: industryObjCellSize, cellH: industryObjCellSize)
            ghostIronNode.name = "ghostIron"
            ghostIronNode.isHidden = true
            ghostIronNode.categoryBitMask = 0
            scene.rootNode.addChildNode(ghostIronNode)
            coord.ghostIronNode = ghostIronNode
        }
        if let stoneNode = Stone.loadSceneKitNode(from: .main) {
            let templateContainer = SCNNode()
            stoneNode.position = SCNVector3Zero
            templateContainer.addChildNode(stoneNode)
            var (minB, maxB) = templateContainer.boundingBox
            let dx = max(CGFloat(maxB.x - minB.x), 0.1)
            let dz = max(CGFloat(maxB.z - minB.z), 0.1)
            let scaleX = (CGFloat(industryObjCellSize) * cellSizeW) / dx
            let scaleZ = (CGFloat(industryObjCellSize) * cellSizeH) / dz
            let scaleY = min(scaleX, scaleZ)
            stoneNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
            coord.stonePlacementTemplate = templateContainer
            let ghostStoneNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostStoneNode)
            ghostStoneNode.name = "ghostStone"
            ghostStoneNode.isHidden = true
            ghostStoneNode.categoryBitMask = 0
            ghostStoneNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostStoneNode)
            scene.rootNode.addChildNode(ghostStoneNode)
            coord.ghostStoneNode = ghostStoneNode
        } else {
            let ghostStoneNode = makeGhostFarmObjNode(cellW: industryObjCellSize, cellH: industryObjCellSize)
            ghostStoneNode.name = "ghostStone"
            ghostStoneNode.isHidden = true
            ghostStoneNode.categoryBitMask = 0
            scene.rootNode.addChildNode(ghostStoneNode)
            coord.ghostStoneNode = ghostStoneNode
        }

        coord.lastGridZoom = CGFloat(gameState.mapCameraSettings.currentZoom)

        container.onCellHit = { worldPos in
            cellFromMapLocalPosition(worldPos)
        }

        container.onMouseMove = { [gameState] loc in
            let objId = gameState.selectedPlacementObjectId
            let isWall = objId == Wall.objectId
            let isMarket = objId == Market.objectId
            let isWindmill = objId == Windmill.objectId
            let isBakery = objId == Bakery.objectId
            let isGranary = objId == Granary.objectId
            let isWell = objId == Well.objectId
            let isHotel = objId == Hotel.objectId
            let isIron = objId == Iron.objectId
            let isStone = objId == Stone.objectId
            let isChicken = objId == Chicken.objectId
            let isCorn = objId == Corn.objectId
            guard isWall || isMarket || isWindmill || isBakery || isGranary || isWell || isHotel || isIron || isStone || isChicken || isCorn else {
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
                return
            }
            guard let sv = container.scnView else {
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
                return
            }
            let hitPointInView = container.convert(loc, to: sv)
            guard sv.bounds.contains(hitPointInView) else {
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
                return
            }
            let hitOptions: [SCNHitTestOption: Any] = [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .categoryBitMask: 1
            ]
            let hits = sv.hitTest(hitPointInView, options: hitOptions)
            guard let hit = hits.first(where: { $0.node.name == "terrain" }),
                  let (row, col) = cellFromMapLocalPosition(hit.worldCoordinates) else {
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
                return
            }
            let ghostColor = NSColor(red: 0.15, green: 0.95, blue: 0.25, alpha: 1)
            // Y pozicija: dno modela na terenu (y=0) – koristimo -boundingBox.min.y kao za postavljene objekte.
            if isWall, let ghost = coord.ghostPlacementNode {
                let pos = worldPositionAtCell(row: row, col: col)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostPlacementNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostPlacementNode?.isHidden = false
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isMarket, let ghost = coord.ghostMarketNode {
                let centerRow = row + 3 / 2
                let centerCol = col + 3 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostMarketNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostMarketNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isWindmill, let ghost = coord.ghostWindmillNode {
                let centerRow = row + 3 / 2
                let centerCol = col + 3 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let windmillYOffset: CGFloat = 8
                let y = -CGFloat(minB.y) + windmillYOffset
                applyGhostColorRecursive(coord.ghostWindmillNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostWindmillNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isBakery, let ghost = coord.ghostBakeryNode {
                // Pekara 2×2 – centar bloka
                let centerRow = row + 2 / 2
                let centerCol = col + 2 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostBakeryNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostBakeryNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isGranary, let ghost = coord.ghostGranaryNode {
                let centerRow = row + 2 / 2
                let centerCol = col + 2 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostGranaryNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostGranaryNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isWell, let ghost = coord.ghostWellNode {
                let centerRow = row + 2 / 2
                let centerCol = col + 2 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostWellNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostWellNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isHotel, let ghost = coord.ghostHotelNode {
                let centerRow = row + 2 / 2
                let centerCol = col + 2 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostHotelNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostHotelNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isIron, let ghost = coord.ghostIronNode {
                let centerRow = row + 2 / 2
                let centerCol = col + 2 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostIronNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostIronNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isStone, let ghost = coord.ghostStoneNode {
                let centerRow = row + 2 / 2
                let centerCol = col + 2 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostStoneNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostStoneNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isChicken, let ghost = coord.ghostChickenNode {
                let centerRow = row + 2 / 2
                let centerCol = col + 2 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostChickenNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostChickenNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostCornNode?.isHidden = true
            } else if isCorn, let ghost = coord.ghostCornNode {
                let centerRow = row + 2 / 2
                let centerCol = col + 2 / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = ghost.boundingBox
                let y = -CGFloat(minB.y)
                applyGhostColorRecursive(coord.ghostCornNode, color: ghostColor, transparency: 0.55)
                ghost.position = SCNVector3(pos.x, y, pos.z)
                coord.ghostCornNode?.isHidden = false
                coord.ghostPlacementNode?.isHidden = true
                coord.ghostMarketNode?.isHidden = true
                coord.ghostWindmillNode?.isHidden = true
                coord.ghostBakeryNode?.isHidden = true
                coord.ghostGranaryNode?.isHidden = true
                coord.ghostWellNode?.isHidden = true
                coord.ghostHotelNode?.isHidden = true
                coord.ghostIronNode?.isHidden = true
                coord.ghostStoneNode?.isHidden = true
                coord.ghostChickenNode?.isHidden = true
            }
        }

        scnView.scene = scene
        coord.gameState = gameState
        coord.animatedZoom = CGFloat(gameState.mapCameraSettings.currentZoom)
        scnView.delegate = coord
        applyCamera(cameraNode: cameraNode, targetNode: cameraTarget, settings: gameState.mapCameraSettings)
        gridNode.isHidden = !showGrid
        refreshPlacements(placementsNode, placements: gameState.gameMap.placements, wallTemplate: coord.wallPlacementTemplate, marketTemplate: coord.marketPlacementTemplate, windmillTemplate: coord.windmillPlacementTemplate, bakeryTemplate: coord.bakeryPlacementTemplate, granaryTemplate: coord.granaryPlacementTemplate, wellTemplate: coord.wellPlacementTemplate, hotelTemplate: coord.hotelPlacementTemplate, ironTemplate: coord.ironPlacementTemplate, stoneTemplate: coord.stonePlacementTemplate, chickenTemplate: coord.chickenPlacementTemplate, cornTemplate: coord.cornPlacementTemplate)
        DispatchQueue.main.async {
            gameState.isLevelReady = true
            gameState.runSoloResourceAnimationIfNeeded()
        }

        container.onPanChange = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.panOffset.x -= delta.x
            s.panOffset.y -= delta.y
            gameState.mapCameraSettings = s
        }
        container.onZoomDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.stepZoomPhaseByScroll(zoomIn: delta > 0)
            gameState.mapCameraSettings = s
        }
        container.onTiltDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.tiltAngle = min(MapCameraSettings.tiltMax, max(MapCameraSettings.tiltMin, s.tiltAngle + delta))
            gameState.mapCameraSettings = s
        }
        container.onRotationDelta = { [gameState] delta in
            var s = gameState.mapCameraSettings
            s.mapRotation += delta
            gameState.mapCameraSettings = s
        }
        container.useTrackpad = gameState.inputDevice == .trackpad
        container.installTrackpadMonitorsIfNeeded()
        container.onClick = { [weak container, gameState, coord] row, col in
            guard let container else { return }
                if container.isEraseMode, let onRemoveAt = onRemoveAt {
                onRemoveAt(row, col)
                if let node = coord.placementsNode {
                    refreshPlacements(node, placements: gameState.gameMap.placements, wallTemplate: coord.wallPlacementTemplate, marketTemplate: coord.marketPlacementTemplate, windmillTemplate: coord.windmillPlacementTemplate, bakeryTemplate: coord.bakeryPlacementTemplate, granaryTemplate: coord.granaryPlacementTemplate, wellTemplate: coord.wellPlacementTemplate, hotelTemplate: coord.hotelPlacementTemplate, ironTemplate: coord.ironPlacementTemplate, stoneTemplate: coord.stonePlacementTemplate, chickenTemplate: coord.chickenPlacementTemplate, cornTemplate: coord.cornPlacementTemplate)
                }
                return
            }
            let objectId = container.currentSelectedPlacementObjectId ?? gameState.selectedPlacementObjectId
            guard let objId = objectId, !objId.isEmpty else {
                let msg = "Objekt nije odabran. Odaberi Zid/Tržnicu (Dvor), Mlin/Pekaru (Hrana) ili Kokošinjac/Kukuruz (Farma) u donjem baru."
                DispatchQueue.main.async { gameState.placementError = msg }
                return
            }
            DispatchQueue.main.async {
                if gameState.selectedPlacementObjectId != objId {
                    gameState.selectedPlacementObjectId = objId
                }
                let ok = gameState.placeSelectedObjectAt(row: row, col: col)
                if ok, let node = coord.placementsNode {
                    refreshPlacements(node, placements: gameState.gameMap.placements, wallTemplate: coord.wallPlacementTemplate, marketTemplate: coord.marketPlacementTemplate, windmillTemplate: coord.windmillPlacementTemplate, bakeryTemplate: coord.bakeryPlacementTemplate, granaryTemplate: coord.granaryPlacementTemplate, wellTemplate: coord.wellPlacementTemplate, hotelTemplate: coord.hotelPlacementTemplate, ironTemplate: coord.ironPlacementTemplate, stoneTemplate: coord.stonePlacementTemplate, chickenTemplate: coord.chickenPlacementTemplate, cornTemplate: coord.cornPlacementTemplate)
                }
            }
        }
        container.onRightClick = { [gameState] in
            DispatchQueue.main.async { gameState.selectedPlacementObjectId = nil }
        }
        container.onPlacementError = { [gameState] msg in
            DispatchQueue.main.async { gameState.placementError = msg }
        }
        container.handPanMode = handPanMode
        container.isEraseMode = isEraseMode
        container.hasObjectSelected = isPlaceMode
        container.currentSelectedPlacementObjectId = gameState.selectedPlacementObjectId
        container.useTrackpad = gameState.inputDevice == .trackpad
        if container.useTrackpad {
            container.installTrackpadMonitorsIfNeeded()
        } else {
            container.removeTrackpadMonitors()
        }
        container.selectedToolsPanelItem = gameState.selectedToolsPanelItem

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let container = nsView as? SceneKitMapNSView,
              container.scnView != nil else { return }

        container.handPanMode = handPanMode
        container.isEraseMode = isEraseMode
        container.hasObjectSelected = isPlaceMode
        container.currentSelectedPlacementObjectId = gameState.selectedPlacementObjectId
        container.selectedToolsPanelItem = gameState.selectedToolsPanelItem
        container.window?.invalidateCursorRects(for: container)

        if let w = container.window, w.isKeyWindow, w.firstResponder != container {
            w.makeFirstResponder(container)
        }

        let coord = context.coordinator
        // Mapa (rootNode, teren, grid, placements) se NIKAD ne dira – samo kamera i target.

        // Odmah primijeni kameru (pan, rotacija) kad se stanje promijeni iz UI (npr. klik na kompas); zoom ostaje glatko u delegateu.
        if let cam = coord.cameraNode, let target = coord.cameraTarget {
            let s = gameState.mapCameraSettings
            let h = Self.cameraBaseHeight / coord.animatedZoom
            let r = CGFloat(-s.mapRotation)
            target.position = SCNVector3(s.panOffset.x, 0, s.panOffset.y)
            cam.position = SCNVector3(
                s.panOffset.x + sin(r) * h,
                h,
                s.panOffset.y + cos(r) * h
            )
        }

        // Pivot, ghost, grid
        if let pivot = coord.pivotIndicatorNode {
            pivot.position = coord.cameraTarget?.position ?? SCNVector3(
                gameState.mapCameraSettings.panOffset.x,
                0,
                gameState.mapCameraSettings.panOffset.y
            )
            pivot.isHidden = !showPivotIndicator
        }
        if let ghost = coord.ghostPlacementNode {
            ghost.isHidden = gameState.selectedPlacementObjectId != Wall.objectId
        }
        if let ghostMarket = coord.ghostMarketNode {
            ghostMarket.isHidden = gameState.selectedPlacementObjectId != Market.objectId
        }
        if let ghostWindmill = coord.ghostWindmillNode {
            ghostWindmill.isHidden = gameState.selectedPlacementObjectId != Windmill.objectId
        }
        if let ghostBakery = coord.ghostBakeryNode {
            ghostBakery.isHidden = gameState.selectedPlacementObjectId != Bakery.objectId
        }
        if let ghostGranary = coord.ghostGranaryNode {
            ghostGranary.isHidden = gameState.selectedPlacementObjectId != Granary.objectId
        }
        if let ghostWell = coord.ghostWellNode {
            ghostWell.isHidden = gameState.selectedPlacementObjectId != Well.objectId
        }
        if let ghostHotel = coord.ghostHotelNode {
            ghostHotel.isHidden = gameState.selectedPlacementObjectId != Hotel.objectId
        }
        if let ghostIron = coord.ghostIronNode {
            ghostIron.isHidden = gameState.selectedPlacementObjectId != Iron.objectId
        }
        if let ghostStone = coord.ghostStoneNode {
            ghostStone.isHidden = gameState.selectedPlacementObjectId != Stone.objectId
        }
        if let ghostChicken = coord.ghostChickenNode {
            ghostChicken.isHidden = gameState.selectedPlacementObjectId != Chicken.objectId
        }
        if let ghostCorn = coord.ghostCornNode {
            ghostCorn.isHidden = gameState.selectedPlacementObjectId != Corn.objectId
        }
        if let grid = coord.gridNode {
            grid.isHidden = !showGrid
            let zoom = gameState.mapCameraSettings.currentZoom
            if abs(CGFloat(zoom) - coord.lastGridZoom) > 0.01 {
                coord.lastGridZoom = CGFloat(zoom)
                refreshGrid(gridNode: grid, zoom: zoom)
            }
        }
        // Ne osvježavaj placements ovdje – inače se pri svakom updateNSView (rotacija, zoom) cijela scena zidova gradi iznova (39 MB .obj + reapplyTexture) → pad FPS. Osvježavanje samo u onClick (place) i nakon onRemoveAt (erase).
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

    private func refreshPlacements(_ node: SCNNode?, placements: [Placement], wallTemplate: SCNNode?, marketTemplate: SCNNode?, windmillTemplate: SCNNode?, bakeryTemplate: SCNNode?, granaryTemplate: SCNNode?, wellTemplate: SCNNode?, hotelTemplate: SCNNode?, ironTemplate: SCNNode?, stoneTemplate: SCNNode?, chickenTemplate: SCNNode?, cornTemplate: SCNNode?) {
        guard let node = node else { return }
        node.childNodes.forEach { $0.removeFromParentNode() }
        node.isHidden = false
        let wallBoxFallback = makePlacementBoxNode()
        wallBoxFallback.categoryBitMask = 0
        for p in placements {
            if p.objectId == Market.objectId, let template = marketTemplate?.clone(), !template.childNodes.isEmpty {
                // Tržnica 3×3 – jedan čvor na centru bloka
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach {
                    $0.categoryBitMask = 0
                    $0.isHidden = false
                }
                _ = Market.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            if p.objectId == Windmill.objectId, let template = windmillTemplate?.clone(), !template.childNodes.isEmpty {
                // Mlin 3×3 – jedan čvor na centru bloka (malo povišen)
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                let windmillYOffset: CGFloat = 8
                template.position = SCNVector3(pos.x, -CGFloat(minB.y) + windmillYOffset, pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach {
                    $0.categoryBitMask = 0
                    $0.isHidden = false
                }
                _ = Windmill.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            if p.objectId == Bakery.objectId, let template = bakeryTemplate?.clone(), !template.childNodes.isEmpty {
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
                _ = Bakery.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            if p.objectId == Granary.objectId, let template = granaryTemplate?.clone(), !template.childNodes.isEmpty {
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
                _ = Granary.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            if p.objectId == Well.objectId, let template = wellTemplate?.clone(), !template.childNodes.isEmpty {
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
                _ = Well.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            if p.objectId == Hotel.objectId, let template = hotelTemplate?.clone(), !template.childNodes.isEmpty {
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
                _ = Hotel.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            if p.objectId == Iron.objectId, let template = ironTemplate?.clone(), !template.childNodes.isEmpty {
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
                _ = Iron.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            if p.objectId == Stone.objectId, let template = stoneTemplate?.clone(), !template.childNodes.isEmpty {
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
                _ = Stone.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            if p.objectId == Chicken.objectId, let template = chickenTemplate?.clone(), !template.childNodes.isEmpty {
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
                _ = Chicken.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            if p.objectId == Corn.objectId, let template = cornTemplate?.clone(), !template.childNodes.isEmpty {
                let centerRow = p.row + p.height / 2
                let centerCol = p.col + p.width / 2
                let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                var (minB, _) = template.boundingBox
                template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
                _ = Corn.reapplyTexture(to: template, bundle: .main)
                node.addChildNode(template)
                continue
            }
            for r in p.row..<(p.row + p.height) {
                for c in p.col..<(p.col + p.width) {
                    let pos = worldPositionAtCell(row: r, col: c)
                    if p.objectId == Wall.objectId, let template = wallTemplate?.clone(), !template.childNodes.isEmpty {
                        var (minB, _) = template.boundingBox
                        template.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                        template.isHidden = false
                        template.categoryBitMask = 0
                        template.childNodes.forEach {
                            $0.categoryBitMask = 0
                            $0.isHidden = false
                        }
                        _ = Wall.reapplyTexture(to: template, bundle: .main)
                        node.addChildNode(template)
                    } else {
                        let n = wallBoxFallback.clone()
                        n.position = pos
                        n.isHidden = false
                        n.categoryBitMask = 0
                        node.addChildNode(n)
                    }
                }
            }
        }
    }

    private func makePlacementBoxNode() -> SCNNode {
        let wallColor = NSColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 0.95)
        let box = SCNBox(width: cellSizeW, height: 8, length: cellSizeH, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = wallColor
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        return n
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private static let zoomLerpFactor: CGFloat = 0.18
    private static let cameraBaseHeight: CGFloat = 2800

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var scene: SCNScene?
        var placementsNode: SCNNode?
        var cameraNode: SCNNode?
        var cameraTarget: SCNNode?
        var pivotIndicatorNode: SCNNode?
        var gridNode: SCNNode?
        var ghostPlacementNode: SCNNode?
        var ghostMarketNode: SCNNode?
        var ghostWindmillNode: SCNNode?
        var ghostBakeryNode: SCNNode?
        var bakeryPlacementTemplate: SCNNode?
        var ghostGranaryNode: SCNNode?
        var granaryPlacementTemplate: SCNNode?
        var ghostWellNode: SCNNode?
        var wellPlacementTemplate: SCNNode?
        var ghostHotelNode: SCNNode?
        var hotelPlacementTemplate: SCNNode?
        var ghostIronNode: SCNNode?
        var ironPlacementTemplate: SCNNode?
        var ghostStoneNode: SCNNode?
        var stonePlacementTemplate: SCNNode?
        var ghostChickenNode: SCNNode?
        var ghostCornNode: SCNNode?
        var wallPlacementTemplate: SCNNode?
        var marketPlacementTemplate: SCNNode?
        var windmillPlacementTemplate: SCNNode?
        var chickenPlacementTemplate: SCNNode?
        var cornPlacementTemplate: SCNNode?
        var lastGridZoom: CGFloat = 1
        weak var gameState: GameState?
        /// Glatka animacija: interpolira se prema target zoomu (iz gameState).
        var animatedZoom: CGFloat = 8

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let cam = cameraNode, let target = cameraTarget else { return }
            let targetZoom: CGFloat
            let pan: CGPoint
            let rot: CGFloat
            if let gs = gameState {
                targetZoom = gs.mapCameraSettings.currentZoom
                pan = gs.mapCameraSettings.panOffset
                rot = gs.mapCameraSettings.mapRotation
            } else {
                targetZoom = animatedZoom
                pan = .zero
                rot = .pi
            }
            animatedZoom += (targetZoom - animatedZoom) * SceneKitMapView.zoomLerpFactor
            let h = SceneKitMapView.cameraBaseHeight / animatedZoom
            let orbitRadius = h
            let r = CGFloat(-rot)
            target.position = SCNVector3(pan.x, 0, pan.y)
            cam.position = SCNVector3(
                pan.x + sin(r) * orbitRadius,
                h,
                pan.y + cos(r) * orbitRadius
            )
        }
    }

    /// Ghost 3D zid – 1×1 ćelija, skaliran iz omjera modela, poluproziran.
    private func makeGhostWallNode() -> SCNNode {
        let container = SCNNode()
        guard let wallNode = Wall.loadSceneKitNode(from: .main) else {
            return container
        }
        wallNode.position = SCNVector3Zero
        container.addChildNode(wallNode)
        var (minB, maxB) = container.boundingBox
        let dx = max(CGFloat(maxB.x - minB.x), 0.1)
        let dz = max(CGFloat(maxB.z - minB.z), 0.1)
        let scaleX = cellSizeW / dx
        let scaleZ = cellSizeH / dz
        let scaleY = min(scaleX, scaleZ)
        wallNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
        applyTransparencyRecursive(0.6, to: container)
        return container
    }

    /// Ghost 3D tržnice – skaliran na 3×3 ćelije, poluproziran (zelena pri pomicanju).
    private func makeGhostMarketNode() -> SCNNode {
        let container = SCNNode()
        guard let marketNode = Market.loadSceneKitNode(from: .main) else {
            return container
        }
        marketNode.position = SCNVector3Zero
        container.addChildNode(marketNode)
        var (minB, maxB) = container.boundingBox
        let dx = max(CGFloat(maxB.x - minB.x), 0.1)
        let dz = max(CGFloat(maxB.z - minB.z), 0.1)
        let marketCellSize: CGFloat = 3
        let scaleX = (marketCellSize * cellSizeW) / dx
        let scaleZ = (marketCellSize * cellSizeH) / dz
        let scaleY = min(scaleX, scaleZ)
        marketNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
        applyTransparencyRecursive(0.6, to: container)
        return container
    }

    /// Ghost 3D mlina – skaliran na 3×3 ćelije, poluproziran (zelena pri pomicanju).
    private func makeGhostWindmillNode() -> SCNNode {
        let container = SCNNode()
        guard let windmillNode = Windmill.loadSceneKitNode(from: .main) else {
            return container
        }
        windmillNode.position = SCNVector3Zero
        container.addChildNode(windmillNode)
        var (minB, maxB) = container.boundingBox
        let dx = max(CGFloat(maxB.x - minB.x), 0.1)
        let dz = max(CGFloat(maxB.z - minB.z), 0.1)
        let windmillCellSize: CGFloat = 3
        let scaleX = (windmillCellSize * cellSizeW) / dx
        let scaleZ = (windmillCellSize * cellSizeH) / dz
        let scaleY = min(scaleX, scaleZ)
        windmillNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
        applyTransparencyRecursive(0.6, to: container)
        return container
    }

    /// Ghost za Pekaru – 2×2 box (nema 3D modela); zelena boja se aplicira u onMouseMove.
    private func makeGhostBakeryNode() -> SCNNode {
        makeGhostFarmObjNode(cellW: 2, cellH: 2)
    }

    /// Ghost box za farm objekte (npr. Chicken/Corn fallback kad model nije učitan).
    private func makeGhostFarmObjNode(cellW: Int, cellH: Int) -> SCNNode {
        let w = CGFloat(cellW) * cellSizeW
        let h = CGFloat(cellH) * cellSizeH
        let box = SCNBox(width: w, height: 8, length: h, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = NSColor.white
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        applyTransparencyRecursive(0.6, to: n)
        return n
    }

    private func applyTransparencyRecursive(_ value: CGFloat, to node: SCNNode) {
        node.geometry?.materials.forEach { $0.transparency = value }
        node.childNodes.forEach { applyTransparencyRecursive(value, to: $0) }
    }

    /// Ghost je klon templatea – SceneKit clone() dijeli geometry i materijale. Da zelena ostane samo na ghostu,
    /// ghost mora imati vlastitu kopiju geometryja i materijala (inače mijenjamo i template i već postavljene zidove).
    private func duplicateMaterialsRecursive(_ node: SCNNode) {
        if let geo = node.geometry, !geo.materials.isEmpty, let newGeo = geo.copy() as? SCNGeometry {
            newGeo.materials = geo.materials.map { old in
                let m = SCNMaterial()
                m.diffuse.contents = old.diffuse.contents
                m.emission.contents = old.emission.contents
                m.ambient.contents = old.ambient.contents
                m.specular.contents = old.specular.contents
                m.transparency = old.transparency
                m.isDoubleSided = old.isDoubleSided
                m.lightingModel = old.lightingModel
                m.diffuse.wrapS = old.diffuse.wrapS
                m.diffuse.wrapT = old.diffuse.wrapT
                return m
            }
            node.geometry = newGeo
        }
        node.childNodes.forEach { duplicateMaterialsRecursive($0) }
    }

    /// Postavi boju ghost zida: zelena = dostupno (za sada uvijek zelena; kasnije + crvena kad ne može).
    private func applyGhostColorRecursive(_ node: SCNNode?, color: NSColor, transparency: CGFloat = 0.55) {
        guard let node = node else { return }
        node.geometry?.materials.forEach { mat in
            mat.diffuse.contents = color
            mat.emission.contents = NSColor(white: 0, alpha: 0)
            mat.transparency = transparency
            mat.lightingModel = .constant
        }
        node.childNodes.forEach { applyGhostColorRecursive($0, color: color, transparency: transparency) }
    }
}
