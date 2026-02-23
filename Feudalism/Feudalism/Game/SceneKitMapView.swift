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

/// Orijentacija terena: ravnina u XZ (width = X, height = Z), usklađeno s mrežom za crtanje objekata.
private let terrainPlaneRotationX: CGFloat = -.pi / 2

/// Proceduralni teren (ravnina + tekstura) – koristi se kad nema učitane .scn mape ili kad .scn nema node "terrain".
/// Ako je `terrainTexture` predan (npr. iz GameAssetLoader cachea), koristi ga umjesto generiranja.
/// Nikad ne ostavlja bijelu boju: ako tekstura nije dostupna, koristi terrainFallbackColor.
private func makeProceduralTerrainNode(terrainTexture: Any? = nil) -> SCNNode {
    let plane = SCNPlane(width: mapWorldW, height: mapWorldH)
    let terrainMat = SCNMaterial()
    let tex = terrainTexture ?? makeTerrainTexture()
    terrainMat.diffuse.contents = tex ?? terrainFallbackColor
    terrainMat.ambient.contents = NSColor.black
    terrainMat.specular.contents = NSColor.black
    terrainMat.isDoubleSided = true
    terrainMat.lightingModel = .constant
    plane.materials = [terrainMat]
    let planeNode = SCNNode(geometry: plane)
    planeNode.eulerAngles.x = terrainPlaneRotationX
    planeNode.position = SCNVector3(0, 0, 0)
    planeNode.name = "terrain"
    planeNode.categoryBitMask = 1
    return planeNode
}

/// Učitani teren iz .scn ponekad ima krivu orijentaciju ili bijeli materijal – ispravi na XZ ravninu i boju zemlje.
private func fixLoadedTerrainOrientationAndMaterial(_ root: SCNNode) {
    guard let terrain = findTerrainInHierarchy(root) else { return }
    terrain.eulerAngles.x = terrainPlaneRotationX
    terrain.eulerAngles.y = 0
    terrain.eulerAngles.z = 0
    guard let geo = terrain.geometry, let mat = geo.materials.first else { return }
    mat.ambient.contents = NSColor.black
    mat.specular.contents = NSColor.black
    if mat.diffuse.contents == nil || isTerrainMaterialWhiteOrEmpty(mat.diffuse.contents) {
        mat.diffuse.contents = makeTerrainTexture() ?? terrainFallbackColor
    }
}

private func findTerrainInHierarchy(_ node: SCNNode) -> SCNNode? {
    if node.name == "terrain" { return node }
    for child in node.childNodes {
        if let t = findTerrainInHierarchy(child) { return t }
    }
    return nil
}

private func isTerrainMaterialWhiteOrEmpty(_ contents: Any?) -> Bool {
    guard let c = contents else { return true }
    if let color = c as? NSColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > 0.95 && g > 0.95 && b > 0.95
    }
    return false
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

    /// Vraća proceduralnu teksturu terena za pred-učitavanje (paralelni loader). Može se zvati s background threada.
    static func createTerrainTextureForPreload() -> Any? {
        makeTerrainTexture()
    }

    /// Spremi proceduralnu teksturu terena (pustinjske boje) u PNG na zadani URL. Koristi se pri spremanju SoloLevel.scn da se tekstura uključi u mapu.
    static func exportTerrainTexture(to url: URL) -> Bool {
        guard let cg = makeTerrainCGImage() else { return false }
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = NSSize(width: cg.width, height: cg.height)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    /// Pred-učitanje (legacy) – preferiraj GameAssetLoader.loadAll() koji radi paralelno s progressom.
    static func preloadGameAssets() {
        Task { await GameAssetLoader.shared.loadAllIfNeeded() }
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
        scene.rootNode.position = SCNVector3Zero
        scene.rootNode.eulerAngles = SCNVector3Zero

        // Koristi pred-učitane assete ako je loader završio (IntroView); inače učitaj/generiraj na zahtjev.
        let loader = GameAssetLoader.shared
        // Teksturu terena uvijek gradimo na main threadu – SKTexture s pozadinskog threada (cache) u SceneKitu često daje bijelu površinu.
        let terrainTextureOnMainThread = makeTerrainTexture()

        // Solo mod: učitaj postojeću mapu (bundle ili spremljeni SoloLevel.scn) ili generiraj, spremi i učitaj
        let rows = gameState.gameMap.rows
        let cols = gameState.gameMap.cols
        var level: LoadedLevel?
        if gameState.isSoloMode {
            if loader.isLoaded, let cached = loader.cachedLevel() {
                level = cached
            } else {
                level = SceneKitLevelLoader.loadForSoloMode(bundleLevelName: gameState.currentLevelName, bundle: .main)
                if level == nil {
                    gameState.levelLoadingMessage = "Generiranje mape (\(rows)×\(cols))…"
                    gameState.objectWillChange.send()
                    let proceduralTerrain = makeProceduralTerrainNode(terrainTexture: terrainTextureOnMainThread)
                    level = SceneKitLevelLoader.generateAndSaveSoloLevel(terrainNode: proceduralTerrain)
                }
            }
        } else {
            level = gameState.currentLevelName.flatMap { SceneKitLevelLoader.load(name: $0, bundle: .main) }
        }
        if let level = level {
            level.levelRoot.position = SCNVector3Zero
            level.levelRoot.eulerAngles = SCNVector3Zero
            fixLoadedTerrainOrientationAndMaterial(level.levelRoot)
            scene.rootNode.addChildNode(level.levelRoot)
            if level.terrainNode == nil {
                let fallbackPlane = makeProceduralTerrainNode(terrainTexture: terrainTextureOnMainThread)
                scene.rootNode.addChildNode(fallbackPlane)
            }
        } else {
            let planeNode = makeProceduralTerrainNode(terrainTexture: terrainTextureOnMainThread)
            scene.rootNode.addChildNode(planeNode)
        }

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
        // Template i ghost po objectId – jedan izvor (SceneKitPlacementRegistry); koristi cache ako je loader završio (klon da se ne mutira cache).
        for config in SceneKitPlacementRegistry.allConfigs {
            let cachedRaw = loader.isLoaded ? loader.cachedPlacementNode(objectId: config.objectId) : nil
            let cachedNode = cachedRaw?.clone()
            let (template, ghost) = makeTemplateAndGhost(config: config, cachedNode: cachedNode)
            if let t = template {
                coord.placementTemplates[config.objectId] = t
            }
            coord.ghostNodes[config.objectId] = ghost
            ghost.isHidden = true
            ghost.categoryBitMask = 0
            ghost.childNodes.forEach { $0.categoryBitMask = 0 }
            scene.rootNode.addChildNode(ghost)
        }

        coord.lastGridZoom = CGFloat(gameState.mapCameraSettings.currentZoom)

        container.onCellHit = { worldPos in
            cellFromMapLocalPosition(worldPos)
        }

        container.onMouseMove = { [gameState] loc in
            let objId = gameState.selectedPlacementObjectId
            coord.ghostNodes.values.forEach { $0.isHidden = true }
            guard let objectId = objId, SceneKitPlacementRegistry.placeableObjectIds.contains(objectId),
                  let ghost = coord.ghostNodes[objectId],
                  let config = SceneKitPlacementRegistry.config(for: objectId) else { return }
            guard let sv = container.scnView, sv.bounds.contains(container.convert(loc, to: sv)) else { return }
            let hitOptions: [SCNHitTestOption: Any] = [.searchMode: SCNHitTestSearchMode.all.rawValue, .categoryBitMask: 1]
            let hits = sv.hitTest(container.convert(loc, to: sv), options: hitOptions)
            guard let hit = hits.first(where: { $0.node.name == "terrain" }),
                  let (row, col) = cellFromMapLocalPosition(hit.worldCoordinates) else { return }
            let ghostColor = NSColor(red: 0.15, green: 0.95, blue: 0.25, alpha: 1)
            applyGhostColorRecursive(ghost, color: ghostColor, transparency: 0.55)
            let (centerRow, centerCol): (Int, Int) = config.cellW == 1 && config.cellH == 1
                ? (row, col)
                : (row + config.cellH / 2, col + config.cellW / 2)
            let pos = worldPositionAtCell(row: centerRow, col: centerCol)
            var (minB, _) = ghost.boundingBox
            let y = -CGFloat(minB.y) + config.yOffset
            ghost.position = SCNVector3(pos.x, y, pos.z)
            ghost.isHidden = false
        }

        scnView.scene = scene
        coord.gameState = gameState
        coord.animatedZoom = CGFloat(gameState.mapCameraSettings.currentZoom)
        scnView.delegate = coord
        applyCamera(cameraNode: cameraNode, targetNode: cameraTarget, settings: gameState.mapCameraSettings)
        gridNode.isHidden = !showGrid
        refreshPlacements(placementsNode, placements: gameState.gameMap.placements, templates: coord.placementTemplates)
        DispatchQueue.main.async {
            gameState.levelLoadingMessage = nil
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
                    refreshPlacements(node, placements: gameState.gameMap.placements, templates: coord.placementTemplates)
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
                    refreshPlacements(node, placements: gameState.gameMap.placements, templates: coord.placementTemplates)
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
        let selectedId = gameState.selectedPlacementObjectId
        for (objectId, ghost) in coord.ghostNodes {
            ghost.isHidden = selectedId != objectId
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

    private func refreshPlacements(_ node: SCNNode?, placements: [Placement], templates: [String: SCNNode]) {
        guard let node = node else { return }
        node.childNodes.forEach { $0.removeFromParentNode() }
        node.isHidden = false
        let boxFallback = makePlacementBoxNode()
        boxFallback.categoryBitMask = 0
        for p in placements {
            guard let config = SceneKitPlacementRegistry.config(for: p.objectId) else {
                addFallbackBoxes(for: p, to: node, fallback: boxFallback)
                continue
            }
            if let template = templates[p.objectId]?.clone(), !template.childNodes.isEmpty {
                template.isHidden = false
                template.categoryBitMask = 0
                template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
                if config.cellW == 1 && config.cellH == 1 {
                    for r in p.row..<(p.row + p.height) {
                        for c in p.col..<(p.col + p.width) {
                            let pos = worldPositionAtCell(row: r, col: c)
                            let instance = template.clone()
                            var (minB, _) = instance.boundingBox
                            instance.position = SCNVector3(pos.x, -CGFloat(minB.y), pos.z)
                            _ = SceneKitPlacementRegistry.reapplyTexture(objectId: p.objectId, to: instance, bundle: .main)
                            node.addChildNode(instance)
                        }
                    }
                } else {
                    let centerRow = p.row + p.height / 2
                    let centerCol = p.col + p.width / 2
                    let pos = worldPositionAtCell(row: centerRow, col: centerCol)
                    var (minB, _) = template.boundingBox
                    template.position = SCNVector3(pos.x, -CGFloat(minB.y) + config.yOffset, pos.z)
                    _ = SceneKitPlacementRegistry.reapplyTexture(objectId: p.objectId, to: template, bundle: .main)
                    node.addChildNode(template)
                }
            } else {
                addFallbackBoxes(for: p, to: node, fallback: boxFallback)
            }
        }
    }

    private func addFallbackBoxes(for p: Placement, to node: SCNNode, fallback: SCNNode) {
        for r in p.row..<(p.row + p.height) {
            for c in p.col..<(p.col + p.width) {
                let pos = worldPositionAtCell(row: r, col: c)
                let n = fallback.clone()
                n.position = pos
                n.isHidden = false
                n.categoryBitMask = 0
                node.addChildNode(n)
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

    /// Za jedan objectId: učitaj model (ili koristi `cachedNode`), skaliaj na cellW×cellH, vrati (template, ghost). Ako model nije učitan, ghost = fallback box.
    private func makeTemplateAndGhost(config: SceneKitPlacementConfig, cachedNode: SCNNode? = nil) -> (template: SCNNode?, ghost: SCNNode) {
        let cw = CGFloat(config.cellW)
        let ch = CGFloat(config.cellH)
        let placementNode = cachedNode ?? SceneKitPlacementRegistry.loadSceneKitNode(objectId: config.objectId, bundle: .main)
        guard let placementNode = placementNode else {
            let fallbackGhost = makeGhostFarmObjNode(cellW: config.cellW, cellH: config.cellH)
            return (nil, fallbackGhost)
        }
        let templateContainer = SCNNode()
        placementNode.position = SCNVector3Zero
        templateContainer.addChildNode(placementNode)
        var (minB, maxB) = templateContainer.boundingBox
        let dx = max(CGFloat(maxB.x - minB.x), 0.1)
        let dz = max(CGFloat(maxB.z - minB.z), 0.1)
        let scaleX = (cw * cellSizeW) / dx
        let scaleZ = (ch * cellSizeH) / dz
        let scaleY = min(scaleX, scaleZ)
        placementNode.scale = SCNVector3(scaleX, scaleY, scaleZ)
        let ghostNode = templateContainer.clone()
        duplicateMaterialsRecursive(ghostNode)
        ghostNode.name = "ghost_\(config.objectId)"
        ghostNode.isHidden = true
        ghostNode.categoryBitMask = 0
        ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
        applyTransparencyRecursive(0.6, to: ghostNode)
        return (templateContainer, ghostNode)
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
        /// Template po objectId – za kloniranje pri refreshPlacements.
        var placementTemplates: [String: SCNNode] = [:]
        /// Ghost čvor po objectId – prikazuje se pri pomicanju miša kad je objekt odabran.
        var ghostNodes: [String: SCNNode] = [:]
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

    /// Ghost box za objekte kad 3D model nije učitan (fallback u makeTemplateAndGhost).
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
