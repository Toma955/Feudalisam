//
//  GameScene.swift
//  Feudalism
//
//  SpriteKit scena – karta 100×100, 3D izgled (nagnuta), ćelije, ghost zida na mišu.
//  Renderiranje: SpriteKit koristi Metal (GPU) na macOSu.
//

import SpriteKit
import GameplayKit
import AppKit

final class GameScene: SKScene {

    private static let mapRows = 100
    private static let mapCols = 100
    /// Fiksna veličina mape u točkama – bez ograničenja: možeš zumirati i panati bilo gdje.
    private static let mapWorldW: CGFloat = 4000
    private static let mapWorldH: CGFloat = 4000

    private var mapNode: SKNode?
    private var gridCells: [[SKShapeNode]] = []
    private var cellSizeW: CGFloat = 0
    private var cellSizeH: CGFloat = 0
    private var totalMapW: CGFloat = 0
    private var totalMapH: CGFloat = 0
    /// true = teren kao jedna tekstura (1 draw call), inače 10k ćelija.
    private static let useTextureTerrain = true
    private var ghostWallNode: SKShapeNode?
    /// Kad je teren tekstura: container s vertikalnim i horizontalnim linijama preko cijele mape.
    private var gridOverlayNode: SKShapeNode?
    private var gridOverlayContainer: SKNode?
    private var cornerVerticalsContainer: SKNode?
    private var lastHoverCol: Int = -1
    private var lastHoverRow: Int = -1

    /// Postupno učitavanje mreže po batch-evima da ne blokira main thread (manje trokiranja).
    private static let gridBatchSize = 250
    private var gridBuildNextRow = 0
    private var gridBuildTotalW: CGFloat = 0
    private var gridBuildTotalH: CGFloat = 0
    private var gridBuildContainer: SKNode?
    private var gridBuildAction: SKAction?

    /// Pivot u centru mape – rotacija se primjenjuje na njega; kamera je dijete, pan je offset od pivota.
    private let cameraPivot = SKNode()
    /// Kamera – dijete pivot čvora; zumira se ovdje, rotacija je na pivotu.
    private let cam = SKCameraNode()

    /// Postavke kamere (zoom, nagib, brzina) – iz postavki; primjenjuje se pri buildu i može se ažurirati.
    var cameraSettings: MapCameraSettings = MapCameraSettings() {
        didSet { applyCameraToMap() }
    }
    /// Kad korisnik povlači mapu mišem, poziva se s delta za pan (mapa miruje, kamera se pomiče).
    var onPanChange: ((CGPoint) -> Void)?
    /// Držane tipke za glatko pomicanje (keyDown/keyUp).
    private var keysHeld: Set<UInt16> = []
    private var lastUpdateTime: TimeInterval = 0
    var showGrid: Bool = true {
        didSet { updateGridVisibility() }
    }

    /// true = način „ruka” – klik i povlačenje pomiče kameru, kurzor ruka.
    var handPanMode: Bool = false
    private var isPanning = false
    private var isRightOrMiddleMousePan = false
    private var lastPanLocation: CGPoint = .zero

    /// Odabrani objekt za postavljanje (npr. Wall.objectId); ghost se prikazuje samo kad je Zid odabran.
    var selectedObjectId: String?
    /// Poziva se kad igrač klikne na ćeliju – (row, col). Koristi za postavljanje zida.
    var onPlaceAt: ((Int, Int) -> Void)?
    /// Map Editor: true = klik uklanja placement na toj koordinati.
    var isEraseMode: Bool = false
    /// Map Editor: poziva se kad je isEraseMode i igrač klikne na ćeliju – ukloni placement koji je tu.
    var onRemoveAt: ((Int, Int) -> Void)?
    /// Postavljeni objekti na mapi – za bojanje ćelija (zid = smeđe). Osvježava pri svakoj promjeni (i kad se zamijeni jedan zid).
    var placements: [Placement] = [] {
        didSet { refreshPlacementsVisual() }
    }

    /// Strelice gore/dolje pozivaju ovu promjenu nagiba (delta u radijanima; + = više nagnuto).
    var onTiltDelta: ((CGFloat) -> Void)?
    /// Tipke +/− pozivaju ovu promjenu zooma (delta; pozitivno = zumiraj).
    var onZoomDelta: ((CGFloat) -> Void)?
    /// Kad se ažuriraju stupovi: 4 kuta u VIEW koordinatama + veličina viewa, za overlay izvan tilta – stupovi 90° na mapu.
    var onCornerPositionsInView: (([CGPoint], CGSize) -> Void)?
    /// Poziva se kad je level (teren, mreža) učitan i spreman za igru.
    var onLevelReady: (() -> Void)?

    override func didMove(to view: SKView) {
        backgroundColor = .white
        // Veličina scene = veličina viewa (resizeFill); ako view još nema bounds, koristi fallback.
        if view.bounds.width > 0, view.bounds.height > 0 {
            size = view.bounds.size
        } else {
            let safeSize = CGSize(width: size.width > 0 ? size.width : 1024, height: size.height > 0 ? size.height : 768)
            if size.width <= 0 || size.height <= 0 { size = safeSize }
        }
        camera = cam
        addChild(cameraPivot)
        cameraPivot.addChild(cam)
        setupMapGrid()
        setupGhostWall()
        updateGridVisibility()
        applyCameraToMap()
        setupTrackingArea(for: view)
    }

    /// Ponovno gradi rešetku i ghost kad se veličina scene promijeni (npr. kad NSView dobije stvarnu veličinu).
    func rebuildGrid() {
        guard size.width > 0, size.height > 0 else { return }
        if let old = mapNode {
            old.removeFromParent()
            mapNode = nil
        }
        gridCells = []
        ghostWallNode = nil
        setupMapGrid()
        setupGhostWall()
        updateGridVisibility()
        applyCameraToMap()
    }

    /// Ažurira prikaz kamere (poziva se i kad se view resizea). Javno da ga GameView može pozvati.
    func refreshCamera() { applyCameraToMap() }

    /// Primjena zoom, pomaka i rotacije: pivot u centru mape, rotacija na pivotu, kamera kao dijete (pan = offset).
    private func applyCameraToMap() {
        guard let map = mapNode else { return }
        let fitScale = min(size.width / totalMapW, size.height / totalMapH)
        map.position = CGPoint(x: size.width / 2, y: size.height / 2)
        map.setScale(fitScale)
        map.zRotation = 0
        let cx = size.width / 2
        let cy = size.height / 2
        cameraPivot.position = CGPoint(x: cx, y: cy)
        cameraPivot.zRotation = cameraSettings.mapRotation
        let p = cameraSettings.panOffset
        let r = cameraSettings.mapRotation
        cam.position = CGPoint(
            x: p.x * cos(-r) - p.y * sin(-r),
            y: p.x * sin(-r) + p.y * cos(-r)
        )
        cam.zRotation = 0
        cam.setScale(1.0 / max(0.001, cameraSettings.currentZoom))
        updateCornerVerticalPositions()
    }

    private func setupTrackingArea(for view: SKView) {
        guard let nsView = view as? NSView else { return }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .inVisibleRect]
        let area = NSTrackingArea(rect: .zero, options: options, owner: nsView, userInfo: nil)
        nsView.addTrackingArea(area)
    }

    /// Paleta boja terena: pustinja (pijesak), kava (smeđe), šporko bijela – nasumično po poljima.
    private static let terrainPalette: [SKColor] = [
        SKColor(red: 0.76, green: 0.70, blue: 0.55, alpha: 0.92), // pustinja / pijesak
        SKColor(red: 0.72, green: 0.65, blue: 0.48, alpha: 0.92),
        SKColor(red: 0.68, green: 0.58, blue: 0.42, alpha: 0.92),
        SKColor(red: 0.55, green: 0.42, blue: 0.30, alpha: 0.92), // kava
        SKColor(red: 0.50, green: 0.38, blue: 0.28, alpha: 0.92),
        SKColor(red: 0.45, green: 0.35, blue: 0.26, alpha: 0.92),
        SKColor(red: 0.58, green: 0.50, blue: 0.42, alpha: 0.92),
        SKColor(red: 0.82, green: 0.78, blue: 0.72, alpha: 0.92), // šporko bijela
        SKColor(red: 0.78, green: 0.74, blue: 0.68, alpha: 0.92),
        SKColor(red: 0.72, green: 0.68, blue: 0.62, alpha: 0.92),
        SKColor(red: 0.70, green: 0.62, blue: 0.50, alpha: 0.92),
    ]

    /// Jedinstvena boja terena za (row, col) – deterministički „random” da mapa ostane ista.
    private static func terrainColor(row: Int, col: Int) -> SKColor {
        let n = (row &* 31 &+ col) % 997
        let idx = (n &+ (col &* 17) % 311) % terrainPalette.count
        return terrainPalette[idx]
    }

    private func setupMapGrid() {
        totalMapW = Self.mapWorldW
        totalMapH = Self.mapWorldH
        cellSizeW = totalMapW / CGFloat(Self.mapCols)
        cellSizeH = totalMapH / CGFloat(Self.mapRows)
        let totalW = totalMapW
        let totalH = totalMapH

        // Scena: (0,0) = donji lijevi kut; mapa fiksne veličine, centrirana u viewu, pan/zoom bez ograničenja.
        let container = SKNode()
        container.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(container)
        mapNode = container

        if Self.useTextureTerrain {
            if let texture = makeTerrainTexture() {
                let terrain = SKSpriteNode(texture: texture, size: CGSize(width: totalW, height: totalH))
                terrain.position = .zero
                terrain.name = "terrain"
                terrain.zPosition = 0
                container.addChild(terrain)
            }
            setupGridOverlay()
            refreshPlacementsVisual()
            DispatchQueue.main.async { [weak self] in self?.onLevelReady?() }
        } else {
            gridCells = (0..<Self.mapRows).map { _ in [] }
            gridBuildTotalW = totalW
            gridBuildTotalH = totalH
            gridBuildContainer = container
            gridBuildNextRow = 0
            let rowsPerBatch = max(1, Self.gridBatchSize / Self.mapCols)
            let wait = SKAction.wait(forDuration: 1.0 / 60.0)
            let addBatch = SKAction.run { [weak self] in self?.addNextGridBatch(rowsPerBatch: rowsPerBatch) }
            gridBuildAction = SKAction.repeat(SKAction.sequence([addBatch, wait]), count: (Self.mapRows + rowsPerBatch - 1) / rowsPerBatch)
            run(gridBuildAction!, withKey: "gridBuild")
        }
        setupGhostWall()
        setupCornerVerticalLines()
        updateGridVisibility()
        applyCameraToMap()
    }

    /// Povećanje rezolucije teksture terena (piksela po logičkoj ćeliji) – kristalno oštro pri zumiranju.
    private static let terrainTextureScale = 8

    private func makeTerrainTexture() -> SKTexture? {
        let scale = Self.terrainTextureScale
        let w = Self.mapCols * scale
        let h = Self.mapRows * scale
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        for row in 0..<Self.mapRows {
            for col in 0..<Self.mapCols {
                let c = Self.terrainColor(row: row, col: col)
                ctx.setFillColor(c.cgColor)
                let y = Self.mapRows - 1 - row
                ctx.fill(CGRect(x: col * scale, y: y * scale, width: scale, height: scale))
            }
        }
        guard let cgImage = ctx.makeImage() else { return nil }
        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .nearest
        return texture
    }

    private func addNextGridBatch(rowsPerBatch: Int) {
        guard let container = gridBuildContainer else { return }
        let totalW = gridBuildTotalW
        let totalH = gridBuildTotalH
        let startRow = gridBuildNextRow
        let endRow = min(startRow + rowsPerBatch, Self.mapRows)
        for row in startRow..<endRow {
            for col in 0..<Self.mapCols {
                let rect = SKShapeNode(rectOf: CGSize(width: cellSizeW, height: cellSizeH), cornerRadius: 0)
                let x = CGFloat(col) * cellSizeW - totalW / 2 + cellSizeW / 2
                let y = CGFloat(row) * cellSizeH - totalH / 2 + cellSizeH / 2
                rect.position = CGPoint(x: x, y: y)
                rect.strokeColor = .clear
                rect.fillColor = Self.terrainColor(row: row, col: col)
                rect.name = "cell_\(col)_\(row)"
                rect.lineWidth = 0
                rect.isAntialiased = false
                container.addChild(rect)
                if row < gridCells.count { gridCells[row].append(rect) }
            }
        }
        gridBuildNextRow = endRow
        if gridBuildNextRow >= Self.mapRows {
            removeAction(forKey: "gridBuild")
            gridBuildAction = nil
            gridBuildContainer = nil
            updateGridVisibility()
            applyCameraToMap()
            DispatchQueue.main.async { [weak self] in self?.onLevelReady?() }
        }
    }

    /// Mreža poravnata s ćelijama mape – linije na rubovima ćelija (ne od proizvoljnog -extent).
    private func setupGridOverlay() {
        guard let map = mapNode, cellSizeW > 0, cellSizeH > 0 else { return }
        gridOverlayContainer?.removeFromParent()
        gridOverlayContainer = nil
        let container = SKNode()
        container.name = "grid_overlay_container"
        container.zPosition = 5
        let halfW = totalMapW / 2
        let halfH = totalMapH / 2
        let lineColor = SKColor.black.withAlphaComponent(0.55)
        var x = -halfW
        while x <= halfW {
            let line = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: x, y: -halfH))
            p.addLine(to: CGPoint(x: x, y: halfH))
            line.path = p
            line.strokeColor = lineColor
            line.lineWidth = 1.2
            line.isAntialiased = false
            container.addChild(line)
            x += cellSizeW
        }
        var y = -halfH
        while y <= halfH {
            let line = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -halfW, y: y))
            p.addLine(to: CGPoint(x: halfW, y: y))
            line.path = p
            line.strokeColor = lineColor
            line.lineWidth = 1.2
            line.isAntialiased = false
            container.addChild(line)
            y += cellSizeH
        }
        map.addChild(container)
        gridOverlayNode = nil
        gridOverlayContainer = container
        gridOverlayContainer?.isHidden = !showGrid
    }

    /// Kutovi mape u lokalnim koordinatama map nodea.
    private func mapCornerPoints() -> [CGPoint] {
        let halfW = totalMapW / 2
        let halfH = totalMapH / 2
        return [
            CGPoint(x: -halfW, y: -halfH),
            CGPoint(x: halfW, y: -halfH),
            CGPoint(x: -halfW, y: halfH),
            CGPoint(x: halfW, y: halfH),
        ]
    }

    /// Stupovi 90° na mapu: šalju se 4 kuta u VIEW koordinatama overlayu koji nije nagnut (izvan tilt containera).
    private func setupCornerVerticalLines() {
        cornerVerticalsContainer?.removeFromParent()
        cornerVerticalsContainer = nil
        updateCornerVerticalPositions()
    }

    /// Računa 4 kuta mape u VIEW koordinatama (aspectFit) i šalje callbacku za overlay.
    private func updateCornerVerticalPositions() {
        guard let map = mapNode, let v = view, v.bounds.width > 0, v.bounds.height > 0 else { return }
        let cornersInMap = mapCornerPoints()
        let scenePts = cornersInMap.map { map.convert($0, to: self) }
        let vw = v.bounds.width
        let vh = v.bounds.height
        let sw = size.width
        let sh = size.height
        guard sw > 0, sh > 0 else { return }
        let scale = min(vw / sw, vh / sh)
        let ox = (vw - sw * scale) / 2
        let oy = (vh - sh * scale) / 2
        let viewPts = scenePts.map { CGPoint(x: ox + $0.x * scale, y: oy + $0.y * scale) }
        onCornerPositionsInView?(viewPts, CGSize(width: vw, height: vh))
    }

    private func setupGhostWall() {
        let ghost = SKShapeNode(rectOf: CGSize(width: cellSizeW, height: cellSizeH), cornerRadius: 0)
        ghost.fillColor = SKColor.white.withAlphaComponent(0.22)
        ghost.strokeColor = .white
        ghost.lineWidth = 1.5
        ghost.name = "ghost_wall"
        ghost.zPosition = 10
        ghost.isHidden = true
        ghost.isAntialiased = false
        mapNode?.addChild(ghost)
        ghostWallNode = ghost
    }

    /// Kad je grid uključen: teren tekstura = overlay s bijelim linijama; inače ćelije dobivaju obrub.
    func updateGridVisibility() {
        guard let map = mapNode else { return }
        if Self.useTextureTerrain {
            gridOverlayContainer?.isHidden = !showGrid
            return
        }
        let showLines = showGrid
        map.enumerateChildNodes(withName: "cell_*") { node, _ in
            guard let cell = node as? SKShapeNode else { return }
            cell.isHidden = false
            if showLines {
                cell.strokeColor = SKColor.black.withAlphaComponent(0.12)
                cell.lineWidth = 0.25
            } else {
                cell.strokeColor = .clear
                cell.lineWidth = 0
            }
        }
    }

    /// Osvježi prikaz zidova: kod teksture ukloni/ dodaj overlay čvorove, inače bojaj ćelije.
    private func refreshPlacementsVisual() {
        guard let map = mapNode else { return }
        let wallColor = SKColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 0.95)
        if Self.useTextureTerrain {
            map.enumerateChildNodes(withName: "wall_*") { node, _ in node.removeFromParent() }
            for row in 0..<Self.mapRows {
                for col in 0..<Self.mapCols {
                    let coord = MapCoordinate(row: row, col: col)
                    guard placements.contains(where: { $0.contains(coord) }) else { continue }
                    let x = CGFloat(col) * cellSizeW - totalMapW / 2 + cellSizeW / 2
                    let y = CGFloat(row) * cellSizeH - totalMapH / 2 + cellSizeH / 2
                    let rect = SKShapeNode(rectOf: CGSize(width: cellSizeW, height: cellSizeH), cornerRadius: 0)
                    rect.position = CGPoint(x: x, y: y)
                    rect.fillColor = wallColor
                    rect.strokeColor = .clear
                    rect.lineWidth = 0
                    rect.name = "wall_\(col)_\(row)"
                    rect.zPosition = 1
                    rect.isAntialiased = false
                    map.addChild(rect)
                }
            }
        } else {
            for row in 0..<Self.mapRows {
                for col in 0..<Self.mapCols {
                    let coord = MapCoordinate(row: row, col: col)
                    let hasWall = placements.contains { $0.contains(coord) }
                    if let cell = map.childNode(withName: "cell_\(col)_\(row)") as? SKShapeNode {
                        cell.fillColor = hasWall ? wallColor : Self.terrainColor(row: row, col: col)
                    }
                }
            }
        }
    }

    /// Koordinata miša u prostoru mape (map node ima position + scale + rotation).
    /// Scene → map lokalne koordinate; inverzna rotacija (unrotate) za točan col/row na rotiranoj mapi.
    private func scenePointToMapSpace(_ location: CGPoint) -> CGPoint? {
        guard let map = mapNode else { return nil }
        let dx = location.x - map.position.x
        let dy = location.y - map.position.y
        let a = map.zRotation
        let cosA = cos(a), sinA = sin(a)
        let rx = dx * cosA - dy * sinA
        let ry = dx * sinA + dy * cosA
        let scale = map.xScale
        guard scale > 0 else { return nil }
        return CGPoint(x: rx / scale, y: ry / scale)
    }

    private func cellColRow(at location: CGPoint) -> (col: Int, row: Int)? {
        guard cellSizeW > 0, cellSizeH > 0,
              let locInMap = scenePointToMapSpace(location) else { return nil }
        let col = Int((locInMap.x + totalMapW / 2) / cellSizeW)
        let row = Int((locInMap.y + totalMapH / 2) / cellSizeH)
        guard col >= 0, col < Self.mapCols, row >= 0, row < Self.mapRows else { return nil }
        return (col, row)
    }

    private func positionOfCell(col: Int, row: Int) -> CGPoint? {
        guard let map = mapNode else { return nil }
        let x = CGFloat(col) * cellSizeW - totalMapW / 2 + cellSizeW / 2
        let y = CGFloat(row) * cellSizeH - totalMapH / 2 + cellSizeH / 2
        return map.convert(CGPoint(x: x, y: y), to: self)
    }

    override func mouseMoved(with event: NSEvent) {
        if handPanMode, !isPanning { NSCursor.openHand.set() }
        let location = event.location(in: self)
        guard let ghost = ghostWallNode, let map = mapNode else { return }
        let showGhost = !isEraseMode && (selectedObjectId == Wall.objectId) && !handPanMode
        if showGhost, let (col, row) = cellColRow(at: location) {
            let x = CGFloat(col) * cellSizeW - totalMapW / 2 + cellSizeW / 2
            let y = CGFloat(row) * cellSizeH - totalMapH / 2 + cellSizeH / 2
            ghost.position = CGPoint(x: x, y: y)
            ghost.isHidden = false
            lastHoverCol = col
            lastHoverRow = row
        } else {
            ghost.isHidden = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        lastPanLocation = location
        if handPanMode {
            isPanning = true
            NSCursor.closedHand.push()
            return
        }
        guard let map = mapNode else { return }
        guard let (col, row) = cellColRow(at: location) else { return }
        if isEraseMode, let onRemoveAt = onRemoveAt {
            onRemoveAt(row, col)
            return
        }
        if selectedObjectId != nil, let onPlaceAt = onPlaceAt {
            onPlaceAt(row, col)
            return
        }
        if let shape = map.childNode(withName: "cell_\(col)_\(row)") as? SKShapeNode {
            shape.run(SKAction.sequence([
                SKAction.run { shape.fillColor = SKColor(white: 0.35, alpha: 0.9) },
                SKAction.wait(forDuration: 0.15),
                SKAction.run { [weak self] in
                    let hasWall = self?.placements.contains { $0.contains(MapCoordinate(row: row, col: col)) } ?? false
                    shape.fillColor = hasWall ? SKColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 0.95) : Self.terrainColor(row: row, col: col)
                }
            ]))
        } else {
            // Teren kao tekstura: nema cell_* čvorova – kratki flash overlay na ćeliji
            let x = CGFloat(col) * cellSizeW - totalMapW / 2 + cellSizeW / 2
            let y = CGFloat(row) * cellSizeH - totalMapH / 2 + cellSizeH / 2
            let flash = SKShapeNode(rectOf: CGSize(width: cellSizeW, height: cellSizeH), cornerRadius: 0)
            flash.position = CGPoint(x: x, y: y)
            flash.fillColor = SKColor(white: 0.35, alpha: 0.9)
            flash.strokeColor = .clear
            flash.zPosition = 5
            flash.isAntialiased = false
            map.addChild(flash)
            flash.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.15),
                SKAction.removeFromParent()
            ]))
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = event.location(in: self)
        let dx = loc.x - lastPanLocation.x
        let dy = loc.y - lastPanLocation.y
        if !isPanning {
            if hypot(dx, dy) > 3 {
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
            NSCursor.openHand.set()
        }
    }

    func handleRightOrMiddleMouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        isRightOrMiddleMousePan = true
        isPanning = true
        lastPanLocation = location
        NSCursor.closedHand.push()
    }

    func handleRightOrMiddleMouseDragged(with event: NSEvent) {
        guard isRightOrMiddleMousePan, isPanning else { return }
        let loc = event.location(in: self)
        let dx = loc.x - lastPanLocation.x
        let dy = loc.y - lastPanLocation.y
        lastPanLocation = loc
        onPanChange?(CGPoint(x: -dx, y: -dy))
    }

    func handleRightOrMiddleMouseUp(with event: NSEvent) {
        guard isRightOrMiddleMousePan else { return }
        isRightOrMiddleMousePan = false
        isPanning = false
        NSCursor.closedHand.pop()
        NSCursor.openHand.set()
    }

    override func keyDown(with event: NSEvent) {
        let code = event.keyCode
        if keysHeld.contains(code) { return }
        keysHeld.insert(code)
        // Jednokratne akcije (tilt, zoom) odmah
        switch code {
        case 126: onTiltDelta?(0.06)
        case 125: onTiltDelta?(-0.06)
        case 24:  onZoomDelta?(cameraSettings.zoomStep)
        case 27:  onZoomDelta?(-cameraSettings.zoomStep)
        default: break
        }
    }

    override func keyUp(with event: NSEvent) {
        keysHeld.remove(event.keyCode)
    }

    override func update(_ currentTime: TimeInterval) {
        // Uskladi veličinu scene s viewom; mapa je fiksne veličine – samo kamera, ne rebuild.
        if let v = view, v.bounds.width > 0, v.bounds.height > 0,
           abs(size.width - v.bounds.width) > 1 || abs(size.height - v.bounds.height) > 1 {
            size = v.bounds.size
            applyCameraToMap()
        }
        let dt = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime
        guard dt > 0, dt < 0.25 else { return }
        let speed = cameraSettings.panSpeed * 8 * CGFloat(dt)
        var panDelta = CGPoint.zero
        for code in keysHeld {
            switch code {
            case 0x0D: panDelta.y += speed   // W – gore
            case 0x01: panDelta.y -= speed  // S – dolje
            case 0x00: panDelta.x -= speed  // A – lijevo
            case 0x02: panDelta.x += speed  // D – desno
            case 123: panDelta.x -= speed   // Left
            case 124: panDelta.x += speed   // Right
            default: break
            }
        }
        if panDelta.x != 0 || panDelta.y != 0 {
            onPanChange?(panDelta)
        }
    }

}
