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
import CoreGraphics

/// World veličine mape iz MapScale (1 ćelija = 1 objektna kocka = 40 world jedinica).
private var worldUnitsPerCell: CGFloat { MapScale.worldUnitsPerMapCell }
private func effectiveMapWorldW(cols: Int) -> CGFloat { MapScale.worldWidth(cols: cols) }
private func effectiveMapWorldH(rows: Int) -> CGFloat { MapScale.worldHeight(rows: rows) }

// MARK: - Pravila mreže (samo prikaz – koji grid crtati)
/// Najmanja prostorna jedinica = MapScale.smallSpatialUnitWorldUnits (10×10). Pravilo za gradnju = 40×40 (1 ćelija).
/// Broj podjela: 40×40 = jedna linija po granici ćelije; 10×10 = jedna linija po najmanjoj jedinici.

/// Broj podjela za mrežu „40×40” (pravilo gradnje: jedna linija po ćeliji). step = 40 world jedinica.
private func gridDivisionsBuilding(rows: Int, cols: Int) -> Int { cols }

/// Broj podjela za mrežu „10×10” (najmanja jedinica: linija svakih 10 world jedinica).
private func gridDivisionsDisplay(rows: Int, cols: Int) -> Int {
    let smallPerSide = MapScale.smallCellsPerObjectCubeSide
    return smallPerSide * cols
}

/// Razina mreže i tla – ispod y=0 se ništa ne gradi i ne smiju biti objekti.
private let groundLevelY: CGFloat = 0

// MARK: - Terrain texture (procedural, isto kao SpriteKit)
/// Pozadina mape: tamnija siva. Fallback boja terena kad tekstura nije dostupna.
private let terrainFallbackColor = NSColor(white: 0.42, alpha: 1)
private let placementDebugLogs = true
private func placementDebug(_ msg: String) {
    guard placementDebugLogs else { return }
    placementDebugLog(msg)
}

/// Piksela po logičkoj ćeliji – veće = oštrija tekstura (max 24). Za velike mape smanjujemo da CGContext ne padne.
private let terrainTextureScaleBase = 24
/// Maksimalna stranica composite slike da ne alociramo previše (npr. 200×24 = 4800 → preveliko).
private let terrainTextureMaxSide = 2048

private func terrainTextureScale(rows: Int, cols: Int) -> Int {
    let side = max(rows, cols, 1)
    let scale = terrainTextureScaleBase
    if side * scale <= terrainTextureMaxSide { return scale }
    return max(1, terrainTextureMaxSide / side)
}

/// Proceduralna tekstura (siva pozadina). Koristi capped scale za velike mape.
private func makeTerrainCGImage(rows: Int? = nil, cols: Int? = nil) -> CGImage? {
    let c = cols ?? 200
    let r = rows ?? 200
    let scale = terrainTextureScale(rows: r, cols: c)
    let w = c * scale
    let h = r * scale
    guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                             space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let gray: CGFloat = 0.42
    ctx.setFillColor(red: gray, green: gray, blue: gray, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()
}

/// Gradi teksturu terena iz GameMap: svaka ćelija dobiva tile prema cell.terrain. Scale se ograniči da 200×200 ne napravi 4800×4800 (preveliko).
private func makeTerrainCGImage(gameMap: GameMap, tileImages: [TerrainType: CGImage]) -> CGImage? {
    let rows = gameMap.rows
    let cols = gameMap.cols
    let scale = terrainTextureScale(rows: rows, cols: cols)
    let w = cols * scale
    let h = rows * scale
    guard w > 0, h > 0, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                             space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let gray: CGFloat = 0.42
    let fallbackColor = (gray, gray, gray)
    for row in 0..<rows {
        for col in 0..<cols {
            let terrain = gameMap.cell(row: row, col: col)?.terrain ?? .grass
            let y = rows - 1 - row
            let rect = CGRect(x: col * scale, y: y * scale, width: scale, height: scale)
            if let tile = tileImages[terrain] {
                ctx.draw(tile, in: rect)
            } else {
                ctx.setFillColor(red: fallbackColor.0, green: fallbackColor.1, blue: fallbackColor.2, alpha: 1)
                ctx.fill(rect)
            }
        }
    }
    return ctx.makeImage()
}

/// Tekstura terena: kao Wall – NSImage za diffuse. Composite iz tilea; za velike mape scale je ograničen da ne padne.
private func makeTerrainTexture(gameMap: GameMap? = nil, useWhiteBackground: Bool = false) -> Any? {
    if useWhiteBackground {
        let rows = gameMap?.rows ?? 200
        let cols = gameMap?.cols ?? 200
        guard let cg = makeTerrainCGImage(rows: rows, cols: cols) else { return terrainFallbackColor }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
    let tiles = TerrainTextureLoader.shared.tileImages(bundle: .main)
    if let map = gameMap, map.rows > 0, map.cols > 0 {
        if let cg = makeTerrainCGImage(gameMap: map, tileImages: tiles) {
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
        /// Ako composite nije uspio (npr. memorija), ispuni tilanjem ground tilea da ne ostane siva.
        if let grassTile = tiles[.grass], let cg = makeTiledGroundImage(tile: grassTile, size: terrainTextureMaxSide) {
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }
    let rows = gameMap?.rows ?? 200
    let cols = gameMap?.cols ?? 200
    guard let cg = makeTerrainCGImage(rows: rows, cols: cols) else { return terrainFallbackColor }
    return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
}

/// Ispuni kvadratnu sliku ponavljanjem jednog tilea (fallback kad composite prevelike mape padne).
private func makeTiledGroundImage(tile: CGImage, size: Int) -> CGImage? {
    let tw = tile.width
    let th = tile.height
    guard tw > 0, th > 0, size > 0, size <= 2048 else { return nil }
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    for y in stride(from: 0, to: size, by: th) {
        for x in stride(from: 0, to: size, by: tw) {
            ctx.draw(tile, in: CGRect(x: x, y: y, width: tw, height: th))
        }
    }
    return ctx.makeImage()
}

/// Orijentacija terena: ravnina u XZ (width = X, height = Z), usklađeno s mrežom za crtanje objekata.
private let terrainPlaneRotationX: CGFloat = -.pi / 2

/// Boja bočnih strana i donje plohe podignutih kocki (bijela).
private let terrainSideColor = NSColor.white

/// Brzi checksum visina terena – da se mesh ne gradi svaki frame, samo kad se elevacija promijeni (ćelije + vertex visine).
private func terrainHeightsChecksum(gameMap: GameMap) -> Double {
    var sum: Double = 0
    for cell in gameMap.cells.values { sum += Double(cell.height) }
    for (_, h) in gameMap.vertexHeights { sum += Double(h) }
    return sum
}

/// Mesh terena: gornja ploča po ćeliji (4 vrha po ćeliji – vertex visine). Svaka ćelija ima UV 0–1 da dobije jednu tilabilnu ground teksturu.
private func makeTerrainGeometryWithHeights(gameMap: GameMap) -> SCNGeometry? {
    let rows = gameMap.rows
    let cols = gameMap.cols
    guard rows > 0, cols > 0 else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let stepW = worldUnitsPerCell
    let stepH = worldUnitsPerCell
    let baseZ: CGFloat = 0
    var vertices: [SCNVector3] = []
    var uvs: [CGPoint] = []
    var topIndices: [Int32] = []
    for r in 0..<rows {
        for c in 0..<cols {
            let h00 = gameMap.vertexHeightAt(vertexRow: r, vertexCol: c)
            let h01 = gameMap.vertexHeightAt(vertexRow: r, vertexCol: c + 1)
            let h10 = gameMap.vertexHeightAt(vertexRow: r + 1, vertexCol: c)
            let h11 = gameMap.vertexHeightAt(vertexRow: r + 1, vertexCol: c + 1)
            let x0 = -halfW + CGFloat(c) * stepW
            let x1 = -halfW + CGFloat(c + 1) * stepW
            let z0 = -halfH + CGFloat(r) * stepH
            let z1 = -halfH + CGFloat(r + 1) * stepH
            let base = Int32(vertices.count)
            vertices.append(SCNVector3(x0, -z0, h00))
            vertices.append(SCNVector3(x1, -z0, h01))
            vertices.append(SCNVector3(x1, -z1, h11))
            vertices.append(SCNVector3(x0, -z1, h10))
            // Svaka ćelija = jedan tile teksture (UV 0–1 po kocki).
            uvs.append(CGPoint(x: 0, y: 0))
            uvs.append(CGPoint(x: 1, y: 0))
            uvs.append(CGPoint(x: 1, y: 1))
            uvs.append(CGPoint(x: 0, y: 1))
            topIndices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
        }
    }
    func triNormal(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3) -> SCNVector3 {
        let e1 = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
        let e2 = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
        let nx = e1.y * e2.z - e1.z * e2.y
        let ny = e1.z * e2.x - e1.x * e2.z
        let nz = e1.x * e2.y - e1.y * e2.x
        let len = sqrt(nx * nx + ny * ny + nz * nz)
        guard len > 1e-6 else { return SCNVector3(0, 1, 0) }
        return SCNVector3(nx / len, ny / len, nz / len)
    }
    var normals: [SCNVector3] = Array(repeating: SCNVector3(0, 0, 0), count: vertices.count)
    for i in stride(from: 0, to: topIndices.count, by: 3) {
        let ia = Int(topIndices[i]), ib = Int(topIndices[i + 1]), ic = Int(topIndices[i + 2])
        let n = triNormal(vertices[ia], vertices[ib], vertices[ic])
        normals[ia].x += n.x; normals[ia].y += n.y; normals[ia].z += n.z
        normals[ib].x += n.x; normals[ib].y += n.y; normals[ib].z += n.z
        normals[ic].x += n.x; normals[ic].y += n.y; normals[ic].z += n.z
    }
    var sideBottomIndices: [Int32] = []
    for r in 0..<rows {
        for c in 0..<cols {
            let h00 = gameMap.vertexHeightAt(vertexRow: r, vertexCol: c)
            let h01 = gameMap.vertexHeightAt(vertexRow: r, vertexCol: c + 1)
            let h10 = gameMap.vertexHeightAt(vertexRow: r + 1, vertexCol: c)
            let h11 = gameMap.vertexHeightAt(vertexRow: r + 1, vertexCol: c + 1)
            let maxH = max(h00, h01, h10, h11)
            guard maxH > 0 else { continue }
            let x0 = -halfW + CGFloat(c) * stepW
            let x1 = -halfW + CGFloat(c + 1) * stepW
            let z0 = -halfH + CGFloat(r) * stepH
            let z1 = -halfH + CGFloat(r + 1) * stepH
            func addQuad(_ v: [SCNVector3], _ n: SCNVector3, winding: [Int]) {
                let b = Int32(vertices.count)
                vertices.append(contentsOf: v)
                for _ in 0..<4 { normals.append(n) }
                uvs.append(CGPoint(x: 0, y: 0))
                uvs.append(CGPoint(x: 1, y: 0))
                uvs.append(CGPoint(x: 1, y: 1))
                uvs.append(CGPoint(x: 0, y: 1))
                sideBottomIndices.append(contentsOf: [b + Int32(winding[0]), b + Int32(winding[1]), b + Int32(winding[2]), b + Int32(winding[0]), b + Int32(winding[2]), b + Int32(winding[3])])
            }
            // Donja ploča (z = baseZ), normala (0,0,-1)
            addQuad([SCNVector3(x0, -z0, baseZ), SCNVector3(x1, -z0, baseZ), SCNVector3(x1, -z1, baseZ), SCNVector3(x0, -z1, baseZ)], SCNVector3(0, 0, -1), winding: [0, 2, 1, 3])
            // 4 bočne strane (gornji rub po vertex visinama)
            addQuad([SCNVector3(x0, -z0, baseZ), SCNVector3(x1, -z0, baseZ), SCNVector3(x1, -z0, h01), SCNVector3(x0, -z0, h00)], SCNVector3(0, -1, 0), winding: [0, 1, 2, 3])
            addQuad([SCNVector3(x0, -z1, baseZ), SCNVector3(x1, -z1, baseZ), SCNVector3(x1, -z1, h11), SCNVector3(x0, -z1, h10)], SCNVector3(0, 1, 0), winding: [0, 2, 1, 3])
            addQuad([SCNVector3(x0, -z0, baseZ), SCNVector3(x0, -z1, baseZ), SCNVector3(x0, -z1, h10), SCNVector3(x0, -z0, h00)], SCNVector3(-1, 0, 0), winding: [0, 2, 1, 3])
            addQuad([SCNVector3(x1, -z0, baseZ), SCNVector3(x1, -z1, baseZ), SCNVector3(x1, -z1, h11), SCNVector3(x1, -z0, h01)], SCNVector3(1, 0, 0), winding: [0, 1, 2, 3])
        }
    }
    let normalsN = normals.map { n -> SCNVector3 in
        let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
        guard len > 1e-6 else { return SCNVector3(0, 1, 0) }
        return SCNVector3(n.x / len, n.y / len, n.z / len)
    }
    let vertexSource = SCNGeometrySource(vertices: vertices)
    let normalSource = SCNGeometrySource(normals: normalsN)
    let uvData = uvs.map { [Float($0.x), Float($0.y)] }.flatMap { $0 }
    let uvSource = SCNGeometrySource(
        data: Data(bytes: uvData, count: uvData.count * MemoryLayout<Float>.size),
        semantic: .texcoord,
        vectorCount: uvs.count,
        usesFloatComponents: true,
        componentsPerVector: 2,
        bytesPerComponent: MemoryLayout<Float>.size,
        dataOffset: 0,
        dataStride: MemoryLayout<Float>.size * 2
    )
    let topElement = SCNGeometryElement(indices: topIndices, primitiveType: .triangles)
    let elements: [SCNGeometryElement] = sideBottomIndices.isEmpty ? [topElement] : [topElement, SCNGeometryElement(indices: sideBottomIndices, primitiveType: .triangles)]
    return SCNGeometry(sources: [vertexSource, normalSource, uvSource], elements: elements)
}

/// Transformacija teksture: okreni V da se slika terena (row 0 na dnu) uskladi s world Z (row 0 = min Z).
private func terrainTextureFlipVTransform() -> SCNMatrix4 {
    var t = SCNMatrix4MakeTranslation(0, 1, 0)
    let s = SCNMatrix4MakeScale(1, -1, 1)
    return SCNMatrix4Mult(t, s)
}

/// Broj ponavljanja normal/roughness na terenu (tilable detalj, 3D osjećaj kao Wall).
private let terrainPBRTiling: CGFloat = 10

/// Postavi PBR na materijal gornje plohe terena: diffuse + normal + roughness, kao Wall.
private func applyTerrainPBR(to mat: SCNMaterial, diffuseContents: Any?) {
    mat.diffuse.contents = diffuseContents
    mat.diffuse.contentsTransform = terrainTextureFlipVTransform()
    mat.diffuse.wrapS = .clamp
    mat.diffuse.wrapT = .clamp
    mat.ambient.contents = NSColor.white
    mat.specular.contents = NSColor.darkGray
    mat.isDoubleSided = true
    mat.lightingModel = .physicallyBased
    if let normalCG = TerrainTextureLoader.shared.groundNormalImage(bundle: .main) {
        let normalImg = NSImage(cgImage: normalCG, size: NSSize(width: normalCG.width, height: normalCG.height))
        mat.normal.contents = normalImg
        mat.normal.intensity = 1.0
        mat.normal.wrapS = .repeat
        mat.normal.wrapT = .repeat
        mat.normal.contentsTransform = SCNMatrix4MakeScale(terrainPBRTiling, -terrainPBRTiling, 1)
        var tr = SCNMatrix4MakeTranslation(0, 1, 0)
        mat.normal.contentsTransform = SCNMatrix4Mult(tr, mat.normal.contentsTransform)
    }
    if let roughCG = TerrainTextureLoader.shared.groundRoughnessImage(bundle: .main) {
        let roughImg = NSImage(cgImage: roughCG, size: NSSize(width: roughCG.width, height: roughCG.height))
        mat.roughness.contents = roughImg
        mat.roughness.wrapS = .repeat
        mat.roughness.wrapT = .repeat
        mat.roughness.contentsTransform = SCNMatrix4MakeScale(terrainPBRTiling, -terrainPBRTiling, 1)
        var tr = SCNMatrix4MakeTranslation(0, 1, 0)
        mat.roughness.contentsTransform = SCNMatrix4Mult(tr, mat.roughness.contentsTransform)
    }
}

/// Jedna ground tekstura po ćeliji: diffuse = tilabilna slika, wrap repeat, UV 0–1 po kocki.
private func applyTerrainPBRTiled(to mat: SCNMaterial) {
    let groundTile = TerrainTextureLoader.shared.tileImage(for: .grass, bundle: .main)
    let diffuseContents: Any? = groundTile.flatMap { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
    mat.diffuse.contents = diffuseContents ?? terrainFallbackColor
    mat.diffuse.contentsTransform = terrainTextureFlipVTransform()
    mat.diffuse.wrapS = .repeat
    mat.diffuse.wrapT = .repeat
    mat.ambient.contents = NSColor.white
    mat.specular.contents = NSColor.darkGray
    mat.isDoubleSided = true
    mat.lightingModel = .physicallyBased
    if let normalCG = TerrainTextureLoader.shared.groundNormalImage(bundle: .main) {
        let normalImg = NSImage(cgImage: normalCG, size: NSSize(width: normalCG.width, height: normalCG.height))
        mat.normal.contents = normalImg
        mat.normal.intensity = 1.0
        mat.normal.wrapS = .repeat
        mat.normal.wrapT = .repeat
        mat.normal.contentsTransform = SCNMatrix4MakeScale(terrainPBRTiling, -terrainPBRTiling, 1)
        var tr = SCNMatrix4MakeTranslation(0, 1, 0)
        mat.normal.contentsTransform = SCNMatrix4Mult(tr, mat.normal.contentsTransform)
    }
    if let roughCG = TerrainTextureLoader.shared.groundRoughnessImage(bundle: .main) {
        let roughImg = NSImage(cgImage: roughCG, size: NSSize(width: roughCG.width, height: roughCG.height))
        mat.roughness.contents = roughImg
        mat.roughness.wrapS = .repeat
        mat.roughness.wrapT = .repeat
        mat.roughness.contentsTransform = SCNMatrix4MakeScale(terrainPBRTiling, -terrainPBRTiling, 1)
        var tr = SCNMatrix4MakeTranslation(0, 1, 0)
        mat.roughness.contentsTransform = SCNMatrix4Mult(tr, mat.roughness.contentsTransform)
    }
}

/// Ravnina terena kao mreža kvadova: jedan quad po ćeliji, UV 0–1 po ćeliji da svaka kocka ima svoju ground teksturu.
private func makeProceduralTerrainGrid(rows: Int, cols: Int) -> SCNGeometry? {
    guard rows > 0, cols > 0 else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let stepW = worldUnitsPerCell
    let stepH = worldUnitsPerCell
    var vertices: [SCNVector3] = []
    var uvs: [CGPoint] = []
    var indices: [Int32] = []
    for r in 0..<rows {
        for c in 0..<cols {
            let x0 = -halfW + CGFloat(c) * stepW
            let x1 = -halfW + CGFloat(c + 1) * stepW
            let z0 = -halfH + CGFloat(r) * stepH
            let z1 = -halfH + CGFloat(r + 1) * stepH
            let base = Int32(vertices.count)
            vertices.append(SCNVector3(x0, -z0, 0))
            vertices.append(SCNVector3(x1, -z0, 0))
            vertices.append(SCNVector3(x1, -z1, 0))
            vertices.append(SCNVector3(x0, -z1, 0))
            uvs.append(CGPoint(x: 0, y: 0))
            uvs.append(CGPoint(x: 1, y: 0))
            uvs.append(CGPoint(x: 1, y: 1))
            uvs.append(CGPoint(x: 0, y: 1))
            indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
        }
    }
    let normals = vertices.map { _ in SCNVector3(0, 0, 1) }
    let vertexSource = SCNGeometrySource(vertices: vertices)
    let normalSource = SCNGeometrySource(normals: normals)
    let uvData = uvs.map { [Float($0.x), Float($0.y)] }.flatMap { $0 }
    let uvSource = SCNGeometrySource(
        data: Data(bytes: uvData, count: uvData.count * MemoryLayout<Float>.size),
        semantic: .texcoord,
        vectorCount: uvs.count,
        usesFloatComponents: true,
        componentsPerVector: 2,
        bytesPerComponent: MemoryLayout<Float>.size,
        dataOffset: 0,
        dataStride: MemoryLayout<Float>.size * 2
    )
    let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
    return SCNGeometry(sources: [vertexSource, normalSource, uvSource], elements: [element])
}

/// Proceduralni teren: mreža kvadova (jedan po ćeliji), svaka ćelija s ground teksturom (UV 0–1).
/// width/height u world jedinicama: cols×40, rows×40.
private func makeProceduralTerrainNode(width: CGFloat, height: CGFloat, terrainTexture: Any? = nil) -> SCNNode {
    let cols = max(1, Int(round(width / worldUnitsPerCell)))
    let rows = max(1, Int(round(height / worldUnitsPerCell)))
    let terrainMat = SCNMaterial()
    applyTerrainPBRTiled(to: terrainMat)
    if let gridGeo = makeProceduralTerrainGrid(rows: rows, cols: cols) {
        gridGeo.materials = [terrainMat]
        let planeNode = SCNNode(geometry: gridGeo)
        planeNode.eulerAngles.x = terrainPlaneRotationX
        planeNode.position = SCNVector3(0, 0, 0)
        planeNode.name = "terrain"
        planeNode.categoryBitMask = 1
        planeNode.renderingOrder = -100
        return planeNode
    }
    let plane = SCNPlane(width: width, height: height)
    plane.materials = [terrainMat]
    let planeNode = SCNNode(geometry: plane)
    planeNode.eulerAngles.x = terrainPlaneRotationX
    planeNode.position = SCNVector3(0, 0, 0)
    planeNode.name = "terrain"
    planeNode.categoryBitMask = 1
    planeNode.renderingOrder = -100
    return planeNode
}

/// Učitani teren iz .scn: orijentacija XZ, PBR tiled (jedna ground tekstura po ćeliji), redoslijed crtanja.
private func fixLoadedTerrainOrientationAndMaterial(_ root: SCNNode) {
    guard let terrain = findTerrainInHierarchy(root) else { return }
    terrain.eulerAngles.x = terrainPlaneRotationX
    terrain.eulerAngles.y = 0
    terrain.eulerAngles.z = 0
    terrain.renderingOrder = -100
    guard let geo = terrain.geometry, let mat = geo.materials.first else { return }
    applyTerrainPBRTiled(to: mat)
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
    /// Poziva se kad se pokrene pan (klik u handPan ili povuci preko thresholda); argument = pozicija miša u viewu.
    var onPanStart: ((NSPoint) -> Void)?
    var onZoomDelta: ((CGFloat) -> Void)?
    var onRotationDelta: ((CGFloat) -> Void)?
    var onTiltDelta: ((CGFloat) -> Void)?
    var onClick: ((Int, Int) -> Void)?
    var onWallLinePreview: (([(Int, Int)]) -> Void)?
    var onWallLineCommit: (([(Int, Int)]) -> Void)?
    var isPanning = false
    var lastPanLocation: NSPoint = .zero
    var handPanMode = false
    var isEraseMode = false
    /// Map Editor – mod „Odabir ćelija”: klik označuje/uklanja ćeliju.
    var isCellSelectionMode = false
    var hasObjectSelected: Bool = false
    /// Pan kamere dozvoljen samo kad ništa nije označeno (nema objekta za postavljanje, nije Teren, nije Briši).
    var cameraPanAllowed: Bool = true
    /// World koordinata → (row, col) za hit na terenu (poziv iz hit testa).
    var onCellHit: ((SCNVector3) -> (row: Int, col: Int)?)?
    /// Klik na kuglu (točku sjecišta) – (vertexRow, vertexCol). Jedna kugla = jedan vrh.
    var onVertexDotSelected: ((Int, Int) -> Void)?
    /// Poziva se pri pomicanju miša – za ghost objekta (npr. zid) na kursoru.
    var onMouseMove: ((NSPoint) -> Void)?
    /// Ažuriraj ghost iz trenutne pozicije miša (poziva se iz renderera kad mouseMoved ne stiže).
    func updateGhostFromCurrentMouseLocation() {
        guard let win = window else { return }
        let loc = convert(win.mouseLocationOutsideOfEventStream, from: nil)
        onMouseMove?(loc)
    }
    /// Desni klik (npr. otkaz place mode) – ne postavlja objekt.
    var onRightClick: (() -> Void)?
    /// Poziva se nakon uspješnog place da se odmah osvježe čvorovi na sceni (ne čeka updateNSView).
    var onPlacementsDidChange: (() -> Void)?
    private var keyMonitor: Any?
    private var rightClickMonitor: Any?
    private var trackingArea: NSTrackingArea?
    /// Lijevi klik: hit test na mouseDown, poziv onClick tek na mouseUp ako nije bilo pomicanja (da se ne pomiješa s panom).
    private var pendingClickCell: (row: Int, col: Int)?
    /// Klik na kuglu – vertex (row, col) sjecišta; na mouseUp poziva se onVertexDotSelected.
    private var pendingVertexDot: (row: Int, col: Int)?
    private var wallLineStartCell: (row: Int, col: Int)?
    private var wallLineCells: [(Int, Int)] = []
    var isWallLineActive: Bool { wallLineStartCell != nil }
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
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
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

    override func mouseEntered(with event: NSEvent) {
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

    private func terrainCell(at pointInContainer: NSPoint) -> (row: Int, col: Int)? {
        guard let sv = scnView else { return nil }
        let hitPointInView = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(hitPointInView) else { return nil }
        let hitOptions: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .categoryBitMask: 1
        ]
        let hits = sv.hitTest(hitPointInView, options: hitOptions)
        guard let hit = hits.first(where: { $0.node.name == "terrain" }),
              let convertCell = onCellHit,
              let cell = convertCell(hit.worldCoordinates) else { return nil }
        return cell
    }

    /// Hit na kuglu (točku sjecišta). Vraća (vertexRow, vertexCol) ako je prvi pogodak čvor s imenom "dot_*".
    private func vertexDotHit(at pointInContainer: NSPoint) -> (row: Int, col: Int)? {
        guard let sv = scnView else { return nil }
        let hitPointInView = convert(pointInContainer, to: sv)
        guard sv.bounds.contains(hitPointInView) else { return nil }
        let hitOptions: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .categoryBitMask: 1
        ]
        let hits = sv.hitTest(hitPointInView, options: hitOptions)
        guard let hit = hits.first(where: { $0.node.name?.hasPrefix("dot_") == true }),
              let name = hit.node.name else { return nil }
        let parts = name.dropFirst(4).split(separator: "_")
        guard parts.count == 2, let r = Int(parts[0]), let c = Int(parts[1]) else { return nil }
        return (r, c)
    }

    private func buildStraightLineCells(from start: (row: Int, col: Int), to end: (row: Int, col: Int)) -> [(Int, Int)] {
        let dRow = end.row - start.row
        let dCol = end.col - start.col
        if dRow == 0 {
            let step = dCol >= 0 ? 1 : -1
            return stride(from: start.col, through: end.col, by: step).map { (start.row, $0) }
        }
        if dCol == 0 {
            let step = dRow >= 0 ? 1 : -1
            return stride(from: start.row, through: end.row, by: step).map { ($0, start.col) }
        }

        // Dominantna osa + progresivni "lom":
        // zadržava efekt 50/50 kod malog pomaka, a pri daljnjem pomicanju nastavlja stepenasto.
        if abs(dCol) >= abs(dRow) {
            let stepCol = dCol > 0 ? 1 : -1
            let count = abs(dCol)
            let rowSign = dRow > 0 ? 1 : -1
            return (0...count).map { i in
                let t = Double(i) / Double(max(1, count))
                let shiftedRows = Int((t * Double(abs(dRow))).rounded())
                return (start.row + rowSign * shiftedRows, start.col + i * stepCol)
            }
        } else {
            let stepRow = dRow > 0 ? 1 : -1
            let count = abs(dRow)
            let colSign = dCol > 0 ? 1 : -1
            return (0...count).map { i in
                let t = Double(i) / Double(max(1, count))
                let shiftedCols = Int((t * Double(abs(dCol))).rounded())
                return (start.row + i * stepRow, start.col + colSign * shiftedCols)
            }
        }
    }

    private func clearWallLineDraft() {
        wallLineStartCell = nil
        wallLineCells.removeAll(keepingCapacity: false)
        onWallLinePreview?([])
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastPanLocation = convert(event.locationInWindow, from: nil)
        mouseDownLocation = lastPanLocation
        pendingClickCell = nil
        pendingVertexDot = nil
        let mouseDownLog = "[Camera] mouseDown loc=(\(String(format: "%.0f", lastPanLocation.x)),\(String(format: "%.0f", lastPanLocation.y))) handPanMode=\(handPanMode)"
        print(mouseDownLog)
        Task { @MainActor in PlacementDebugConsole.shared.append(mouseDownLog) }
        guard event.buttonNumber == 0 else { return }
        if handPanMode, cameraPanAllowed {
            isPanning = true
            onPanStart?(mouseDownLocation)
            NSCursor.closedHand.push()
            return
        }
        if isPanning { return }
        if let vertex = vertexDotHit(at: lastPanLocation) {
            pendingVertexDot = vertex
            return
        }
        guard let (row, col) = terrainCell(at: lastPanLocation) else {
            onPlacementError?("Klik nije pogodio teren.")
            return
        }
        if !isEraseMode, let id = currentSelectedPlacementObjectId, WallParent.isWall(objectId: id) {
            wallLineStartCell = (row, col)
            wallLineCells = [(row, col)]
            onWallLinePreview?(wallLineCells)
            return
        }
        pendingClickCell = (row, col)
    }

    override func rightMouseDown(with event: NSEvent) {
        pendingClickCell = nil
        pendingVertexDot = nil
        clearWallLineDraft()
        onRightClick?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 0 else { return }
        let loc = convert(event.locationInWindow, from: nil)
        if let start = wallLineStartCell {
            if let end = terrainCell(at: loc) {
                let newCells = buildStraightLineCells(from: start, to: end)
                let changed = newCells.count != wallLineCells.count || zip(newCells, wallLineCells).contains { lhs, rhs in
                    lhs.0 != rhs.0 || lhs.1 != rhs.1
                }
                if changed {
                    wallLineCells = newCells
                    onWallLinePreview?(newCells)
                }
            }
            lastPanLocation = loc
            return
        }
        if !isPanning {
            let dist = hypot(loc.x - mouseDownLocation.x, loc.y - mouseDownLocation.y)
            if dist > Self.clickDragThreshold { pendingClickCell = nil; pendingVertexDot = nil }
            if cameraPanAllowed && (handPanMode || dist > Self.clickDragThreshold) {
                isPanning = true
                onPanStart?(mouseDownLocation)
                NSCursor.closedHand.push()
            } else {
                return
            }
        }
        guard cameraPanAllowed else { return }
        // Delta uvijek inkrementalno (u sve strane): loc - lastPanLocation. Na trackpadu ne warpamo
        // (warp + lastPanLocation=mouseDownLocation daje "samo jedan smjer" kad warp ne radi).
        let dx = loc.x - lastPanLocation.x
        let dy = loc.y - lastPanLocation.y
        onPanChange?(CGPoint(x: -dx, y: -dy))
        lastPanLocation = loc
        if !useTrackpad, let win = window {
            let windowPoint = convert(mouseDownLocation, to: nil)
            let screenRect = win.convertToScreen(NSRect(origin: windowPoint, size: .zero))
            let screenPoint = CGPoint(x: screenRect.origin.x, y: screenRect.origin.y)
            DispatchQueue.main.async {
                CGWarpMouseCursorPosition(screenPoint)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        if event.buttonNumber == 0, wallLineStartCell != nil {
            let commitCells = wallLineCells
            clearWallLineDraft()
            if !commitCells.isEmpty {
                onWallLineCommit?(commitCells)
            }
            return
        }
        if event.buttonNumber == 0, !isPanning {
            if let vertex = pendingVertexDot {
                onVertexDotSelected?(vertex.row, vertex.col)
            } else if let cell = pendingClickCell {
                onClick?(cell.row, cell.col)
            }
        }
        pendingClickCell = nil
        pendingVertexDot = nil
        if isPanning {
            isPanning = false
            NSCursor.closedHand.pop()
            NSCursor.openHand.push()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if useTrackpad, cameraPanAllowed {
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            if dx != 0 || dy != 0 {
                onPanChange?(CGPoint(x: -dx, y: -dy))
            }
        } else if !useTrackpad {
            let dy = event.scrollingDeltaY
            if dy != 0 { onZoomDelta?(dy > 0 ? CGFloat(0.15) : CGFloat(-0.15)) }
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onRightClick?()
        case 126: onTiltDelta?(0.06)
        case 125: onTiltDelta?(-0.06)
        case 0x0D: if cameraPanAllowed { onPanChange?(CGPoint(x: 0, y: 28)) }
        case 0x01: if cameraPanAllowed { onPanChange?(CGPoint(x: 0, y: -28)) }
        case 0x00: if cameraPanAllowed { onPanChange?(CGPoint(x: -28, y: 0)) }
        case 0x02: if cameraPanAllowed { onPanChange?(CGPoint(x: 28, y: 0)) }
        default: break
        }
    }
}

/// Boja linija i točaka: bijela za obje mreže (40×40 i 10×10). Točke na sjecištima služe za mikropodešavanja.
private func gridLineColor(isLargeGrid: Bool) -> NSColor {
    NSColor.white.withAlphaComponent(0.95)
}

/// Ponovno gradi linije rešetke. Mreža je uvijek ravna na fiksnoj visini – ne prati teren. Točke (vertex) će se drugi put implementirati iz Map Editora.
private func refreshGrid(gridNode: SCNNode, zoom: CGFloat, gridDivisions: Int, mapWidth: CGFloat, mapHeight: CGFloat, gameMap: GameMap? = nil, rows: Int? = nil, cols: Int? = nil, lineColor: NSColor? = nil) {
    gridNode.childNodes.forEach { $0.removeFromParentNode() }
    let divisionsForBuilding = Int(mapWidth / worldUnitsPerCell)
    let isLarge = (gridDivisions == divisionsForBuilding)
    let lineColor = lineColor ?? gridLineColor(isLargeGrid: isLarge)
    let baseW: CGFloat = 2.5
    let baseH: CGFloat = 8
    let z = max(0.1, min(50, zoom))
    let lineW = baseW / z
    let lineH = baseH / z
    let halfW = mapWidth / 2
    let halfH = mapHeight / 2
    let stepW = mapWidth / CGFloat(gridDivisions)
    let stepH = mapHeight / CGFloat(gridDivisions)
    let gridY = groundLevelY + lineH / 2
    var x = -halfW
    while x <= halfW {
        let box = SCNBox(width: lineW, height: lineH, length: mapHeight, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = lineColor
        box.firstMaterial?.isDoubleSided = true
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        n.position = SCNVector3(x, gridY, 0)
        gridNode.addChildNode(n)
        x += stepW
    }
    var zCoord = -halfH
    while zCoord <= halfH {
        let box = SCNBox(width: mapWidth, height: lineH, length: lineW, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = lineColor
        box.firstMaterial?.isDoubleSided = true
        box.firstMaterial?.lightingModel = .constant
        let n = SCNNode(geometry: box)
        n.position = SCNVector3(0, gridY, zCoord)
        gridNode.addChildNode(n)
        zCoord += stepH
    }
}

/// Iz world pozicije na terenu vraća (row, col) ili nil. 1 ćelija = 40 world jedinica.
private func cellFromMapLocalPosition(_ localPos: SCNVector3, rows: Int, cols: Int) -> (row: Int, col: Int)? {
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let col = Int((CGFloat(localPos.x) + halfW) / worldUnitsPerCell)
    let row = Int((CGFloat(localPos.z) + halfH) / worldUnitsPerCell)
    guard row >= 0, row < rows, col >= 0, col < cols else { return nil }
    return (row, col)
}

/// Visina terena u world (x, z); bilinearna interpolacija iz vertex visina (GameMap.vertexHeightAt). Koristi se da mreža prati deformaciju terena.
private func terrainHeightAtWorld(x: CGFloat, z: CGFloat, gameMap: GameMap, rows: Int, cols: Int) -> CGFloat {
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    let c_f = (x + halfW) / step
    let r_f = (z + halfH) / step
    let c0 = max(0, min(cols - 1, Int(floor(c_f))))
    let r0 = max(0, min(rows - 1, Int(floor(r_f))))
    let c1 = min(cols, c0 + 1)
    let r1 = min(rows, r0 + 1)
    let h00 = gameMap.vertexHeightAt(vertexRow: r0, vertexCol: c0)
    let h01 = c1 > c0 ? gameMap.vertexHeightAt(vertexRow: r0, vertexCol: c1) : h00
    let h10 = r1 > r0 ? gameMap.vertexHeightAt(vertexRow: r1, vertexCol: c0) : h00
    let h11 = (c1 > c0 && r1 > r0) ? gameMap.vertexHeightAt(vertexRow: r1, vertexCol: c1) : h00
    let tx = c_f - CGFloat(c0)
    let tz = r_f - CGFloat(r0)
    return (1 - tx) * (1 - tz) * h00 + tx * (1 - tz) * h01 + (1 - tx) * tz * h10 + tx * tz * h11
}

/// Zelena površina samo nad označenim ćelijama: ravni quad po ćeliji na visini te ćelije (Y = visina, horizontalno u XZ – ostale ćelije na miru).
private func makeGreenSurfaceGeometry(gameMap: GameMap, cells: Set<MapCoordinate>, rows: Int, cols: Int) -> SCNGeometry? {
    guard !cells.isEmpty else { return nil }
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let step = worldUnitsPerCell
    var vertices: [SCNVector3] = []
    var indices: [Int32] = []
    for coord in cells {
        let (r, c) = (coord.row, coord.col)
        guard r >= 0, r < rows, c >= 0, c < cols else { continue }
        let h = gameMap.cell(row: r, col: c)?.height ?? 0
        let x0 = CGFloat(c) * step - halfW
        let x1 = CGFloat(c + 1) * step - halfW
        let z0 = CGFloat(r) * step - halfH
        let z1 = CGFloat(r + 1) * step - halfH
        let base = Int32(vertices.count)
        vertices.append(SCNVector3(x0, h, z0))
        vertices.append(SCNVector3(x1, h, z0))
        vertices.append(SCNVector3(x1, h, z1))
        vertices.append(SCNVector3(x0, h, z1))
        indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
    }
    guard !vertices.isEmpty else { return nil }
    func triNormal(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3) -> SCNVector3 {
        let e1 = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
        let e2 = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
        let nx = e1.y * e2.z - e1.z * e2.y
        let ny = e1.z * e2.x - e1.x * e2.z
        let nz = e1.x * e2.y - e1.y * e2.x
        let len = sqrt(nx * nx + ny * ny + nz * nz)
        guard len > 1e-6 else { return SCNVector3(0, 1, 0) }
        return SCNVector3(nx / len, ny / len, nz / len)
    }
    var normalAccum = [SCNVector3](repeating: SCNVector3(0, 0, 0), count: vertices.count)
    for i in stride(from: 0, to: indices.count, by: 3) {
        let ia = Int(indices[i]), ib = Int(indices[i + 1]), ic = Int(indices[i + 2])
        let n = triNormal(vertices[ia], vertices[ib], vertices[ic])
        normalAccum[ia].x += n.x; normalAccum[ia].y += n.y; normalAccum[ia].z += n.z
        normalAccum[ib].x += n.x; normalAccum[ib].y += n.y; normalAccum[ib].z += n.z
        normalAccum[ic].x += n.x; normalAccum[ic].y += n.y; normalAccum[ic].z += n.z
    }
    let normals = normalAccum.map { n -> SCNVector3 in
        let len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
        guard len > 1e-6 else { return SCNVector3(0, 1, 0) }
        return SCNVector3(n.x / len, n.y / len, n.z / len)
    }
    let mat = SCNMaterial()
    mat.diffuse.contents = NSColor(red: 0.5, green: 0.98, blue: 0.55, alpha: 0.75)
    mat.emission.contents = NSColor(red: 0.55, green: 1.0, blue: 0.6, alpha: 0.6)
    mat.isDoubleSided = true
    mat.lightingModel = .constant
    let vertexSource = SCNGeometrySource(vertices: vertices)
    let normalSource = SCNGeometrySource(normals: normals)
    let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
    let geo = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
    geo.materials = [mat]
    return geo
}

/// Ćelije koje četkica pokriva (kockica: 1×1, 3×3, 6×6, 12×12).
private func brushCells(centerRow: Int, centerCol: Int, brushOption: TerrainBrushOption, rows: Int, cols: Int) -> Set<MapCoordinate> {
    let r = brushOption.radius
    var cells: Set<MapCoordinate> = []
    for dr in -r...r {
        for dc in -r...r {
            let row = centerRow + dr
            let col = centerCol + dc
            guard row >= 0, row < rows, col >= 0, col < cols else { continue }
            if !brushOption.isSquare, dr * dr + dc * dc > r * r { continue }
            cells.insert(MapCoordinate(row: row, col: col))
        }
    }
    return cells
}

/// Sredina ćelije (row, col) u world koordinatama. 1 ćelija = 40 world jedinica.
private func worldPositionAtCell(row: Int, col: Int, rows: Int, cols: Int) -> SCNVector3 {
    let halfW = effectiveMapWorldW(cols: cols) / 2
    let halfH = effectiveMapWorldH(rows: rows) / 2
    let x = CGFloat(col) * worldUnitsPerCell - halfW + worldUnitsPerCell / 2
    let z = CGFloat(row) * worldUnitsPerCell - halfH + worldUnitsPerCell / 2
    return SCNVector3(x, groundLevelY, z)
}

/// Označavanje odabranih ćelija: jedna zelena površina (3D) koja prati teren.
private func refreshCellSelectionOverlay(overlayNode: SCNNode, selectedCells: Set<MapCoordinate>, gameMap: GameMap, rows: Int, cols: Int) {
    overlayNode.childNodes.forEach { $0.removeFromParentNode() }
    guard !selectedCells.isEmpty else { return }
    if let geo = makeGreenSurfaceGeometry(gameMap: gameMap, cells: selectedCells, rows: rows, cols: cols) {
        let node = SCNNode(geometry: geo)
        node.name = "cellSelection"
        node.categoryBitMask = 0
        node.renderingOrder = 400
        overlayNode.addChildNode(node)
    }
}

// MARK: - SceneKitMapView (SwiftUI)
struct SceneKitMapView: NSViewRepresentable {
    @EnvironmentObject private var gameState: GameState
    var showGrid: Bool = true
    /// Map Editor: prikaži mrežu 10×10 (može zajedno s 40×40).
    var gridShow10: Bool = true
    /// Map Editor: prikaži mrežu 40×40 (može zajedno s 10×10).
    var gridShow40: Bool = false
    /// Map Editor: prikaži kugle na sjecištima (gumb Kugle).
    @Binding var handPanMode: Bool
    var showPivotIndicator: Bool = false
    var isEraseMode: Bool = false
    var onRemoveAt: ((Int, Int) -> Void)?
    /// Map Editor – alat Teren: kad true, klik primjenjuje elevaciju (Podigni za 5/10, Izravnaj).
    var isTerrainEditMode: Bool = false
    var terrainTool: TerrainToolOption? = nil
    var terrainBrushOption: TerrainBrushOption? = nil
    var onTerrainEdit: ((Int, Int) -> Void)? = nil
    /// Map Editor – klik primjenjuje četkicu (kockica 1×1, 3×3, 6×6, 12×12).
    var onTerrainAddBrushSelection: ((Int, Int) -> Void)? = nil
    /// Map Editor – mod „Odabir ćelija”: klik uključuje/isključuje ćeliju u označene (toggle).
    var onCellSelectionToggle: ((Int, Int) -> Void)? = nil
    /// Map Editor – mod „Odabir ćelija”: klik označuje/uklanja jednu ćeliju (precizno).
    var isCellSelectionMode: Bool = false
    /// Map Editor – klik na kuglu (točku sjecišta) označi taj vrh za gore/dolje (samo ta točka).
    var onVertexDotSelected: ((Int, Int) -> Void)? = nil
    /// Map Editor – dvoprstni/desni klik izlazi iz alata Teren (elevator).
    var onExitTerrainEditMode: (() -> Void)? = nil
    var isPlaceMode: Bool { gameState.selectedPlacementObjectId != nil }

    /// U Map Editoru: jedna ili obje mreže (10×10, 40×40); kad obje isključene, nema mreže.
    private var isMapEditorGridMode: Bool { gameState.isMapEditorMode }

    /// Vraća proceduralnu teksturu terena za pred-učitavanje (paralelni loader). Može se zvati s background threada.
    static func createTerrainTextureForPreload() -> Any? {
        makeTerrainTexture()
    }

    /// Spremi proceduralnu teksturu terena u PNG na zadani URL (fallback kad nema čvora).
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

    /// Spremi teksturu s teren čvora u PNG (voda/vegetacija/zemlja već na materijalu). Koristi se pri spremanju SoloLevel.scn.
    static func exportTerrainTextureFromNode(_ terrainNode: SCNNode, to url: URL) -> Bool {
        guard let mat = terrainNode.geometry?.materials.first,
              let contents = mat.diffuse.contents else { return exportTerrainTexture(to: url) }
        if let img = contents as? NSImage, let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = NSSize(width: cg.width, height: cg.height)
            guard let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { return false }
            do {
                try data.write(to: url)
                return true
            } catch {
                return false
            }
        }
        if let skTex = contents as? SKTexture {
            let cg = skTex.cgImage()
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = NSSize(width: cg.width, height: cg.height)
            guard let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { return false }
            do {
                try data.write(to: url)
                return true
            } catch {
                return false
            }
        }
        return exportTerrainTexture(to: url)
    }

    /// Pred-učitanje (legacy) – preferiraj GameAssetLoader.loadAll() koji radi paralelno s progressom.
    static func preloadGameAssets() {
        Task { await GameAssetLoader.shared.loadAllIfNeeded() }
    }

    private func setupSceneAndTerrain(into scene: SCNScene, loader: GameAssetLoader, terrainTexture: Any?) {
        let terrainTextureOnMainThread = terrainTexture
        let rows = gameState.gameMap.rows
        let cols = gameState.gameMap.cols
        var level: LoadedLevel?
        // Solo s mapom iz datoteke (Maps/…): teren iz gameMap (kao u Map Editoru).
        if gameState.isSoloMode && gameState.soloMapLoadedFromFile {
            DispatchQueue.main.async {
                gameState.levelLoadingMessage = "Učitavanje mape (\(gameState.gameMap.displayDimensionString))…"
                gameState.objectWillChange.send()
            }
            let w = effectiveMapWorldW(cols: cols)
            let h = effectiveMapWorldH(rows: rows)
            let proceduralTerrain = makeProceduralTerrainNode(width: w, height: h, terrainTexture: terrainTextureOnMainThread)
            proceduralTerrain.position = SCNVector3Zero
            scene.rootNode.addChildNode(proceduralTerrain)
            return
        }
        // Map Editor: nikad ne koristiti cache level – teren mora biti točno rows×cols s 40×40 world jedinicama po ćeliji.
        let useCachedLevel = gameState.isSoloMode && !gameState.isMapEditorMode
        if useCachedLevel {
            if loader.isLoaded, let cached = loader.cachedLevel() {
                level = cached
            } else {
                level = SceneKitLevelLoader.loadForSoloMode(bundleLevelName: gameState.currentLevelName, bundle: .main)
                if level == nil {
                    DispatchQueue.main.async {
                        gameState.levelLoadingMessage = "Generiranje mape (\(gameState.gameMap.displayDimensionString))…"
                        gameState.objectWillChange.send()
                    }
                    let w = effectiveMapWorldW(cols: cols)
                    let h = effectiveMapWorldH(rows: rows)
                    let proceduralTerrain = makeProceduralTerrainNode(width: w, height: h, terrainTexture: terrainTextureOnMainThread)
                    level = SceneKitLevelLoader.generateAndSaveSoloLevel(terrainNode: proceduralTerrain)
                }
            }
        } else if gameState.isMapEditorMode {
            // Uvijek proceduralni teren: cols×40 (X) × rows×40 (Z) world jedinica. 1 ćelija = 40×40.
            // Ne mijenjati eulerAngles – makeProceduralTerrainNode postavlja eulerAngles.x = -π/2 da ravnina leži u XZ (inače bi stajala pod 90°).
            DispatchQueue.main.async {
                gameState.levelLoadingMessage = "Generiranje mape (\(gameState.gameMap.displayDimensionString))…"
                gameState.objectWillChange.send()
            }
            let w = effectiveMapWorldW(cols: cols)
            let h = effectiveMapWorldH(rows: rows)
            let proceduralTerrain = makeProceduralTerrainNode(width: w, height: h, terrainTexture: terrainTextureOnMainThread)
            proceduralTerrain.position = SCNVector3Zero
            scene.rootNode.addChildNode(proceduralTerrain)
            return
        } else {
            level = gameState.currentLevelName.flatMap { SceneKitLevelLoader.load(name: $0, bundle: .main) }
        }
        if let level = level {
            level.levelRoot.position = SCNVector3Zero
            level.levelRoot.eulerAngles = SCNVector3Zero
            fixLoadedTerrainOrientationAndMaterial(level.levelRoot)
            scene.rootNode.addChildNode(level.levelRoot)
            if level.terrainNode == nil {
                let w = effectiveMapWorldW(cols: cols)
                let h = effectiveMapWorldH(rows: rows)
                let fallbackPlane = makeProceduralTerrainNode(width: w, height: h, terrainTexture: terrainTextureOnMainThread)
                scene.rootNode.addChildNode(fallbackPlane)
            }
        } else {
            let w = effectiveMapWorldW(cols: cols)
            let h = effectiveMapWorldH(rows: rows)
            let planeNode = makeProceduralTerrainNode(width: w, height: h, terrainTexture: terrainTextureOnMainThread)
            scene.rootNode.addChildNode(planeNode)
        }
    }

    private func setupGridNode(zoom: CGFloat, gridDivisions: Int, mapWidth: CGFloat, mapHeight: CGFloat, gameMap: GameMap? = nil, rows: Int? = nil, cols: Int? = nil) -> SCNNode {
        let gridNode = SCNNode()
        gridNode.name = "grid"
        gridNode.categoryBitMask = 1
        gridNode.position = SCNVector3Zero
        gridNode.eulerAngles = SCNVector3Zero
        /// Mreža se crta iznad terena da ne prekrije teksturu u Map Builderu.
        gridNode.renderingOrder = 100
        refreshGrid(gridNode: gridNode, zoom: zoom, gridDivisions: gridDivisions, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gameMap, rows: rows, cols: cols)
        return gridNode
    }

    private func setupCameraAndLights(in scene: SCNScene, halfW: CGFloat, halfH: CGFloat) -> (SCNNode, SCNNode, SCNNode) {
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

        return (cameraNode, cameraTarget, pivotIndicator)
    }

    private func setupPlacementTemplatesAndGhosts(coord: Coordinator, scene: SCNScene, loader: GameAssetLoader) {
        for config in SceneKitPlacementRegistry.allConfigs {
            // Wall uvijek gradimo svježe (bez cachea) da ne ostane stari minijaturni node.
            let useCache = !WallParent.isWall(objectId: config.objectId)
            let cachedRaw = (loader.isLoaded && useCache) ? loader.cachedPlacementNode(objectId: config.objectId) : nil
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

        let rows = gameState.gameMap.rows
        let cols = gameState.gameMap.cols
        let mapWidth = effectiveMapWorldW(cols: cols)
        let mapHeight = effectiveMapWorldH(rows: rows)
        let halfW = mapWidth / 2
        let halfH = mapHeight / 2

        let scene = SCNScene()
        scene.rootNode.position = SCNVector3Zero
        scene.rootNode.eulerAngles = SCNVector3Zero

        let loader = GameAssetLoader.shared
        let terrainTextureOnMainThread = makeTerrainTexture(gameMap: gameState.gameMap, useWhiteBackground: false)
        setupSceneAndTerrain(into: scene, loader: loader, terrainTexture: terrainTextureOnMainThread)

        let coord = context.coordinator
        let zoom = gameState.mapCameraSettings.currentZoom
        let div40 = gridDivisionsBuilding(rows: rows, cols: cols)
        let div10 = gridDivisionsDisplay(rows: rows, cols: cols)
        if isMapEditorGridMode {
            if gridShow10 {
                let n10 = setupGridNode(zoom: zoom, gridDivisions: div10, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gameState.gameMap, rows: rows, cols: cols)
                n10.name = "grid10"
                scene.rootNode.addChildNode(n10)
                coord.gridNode10 = n10
            } else { coord.gridNode10 = nil }
            if gridShow40 {
                let n40 = setupGridNode(zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gameState.gameMap, rows: rows, cols: cols)
                n40.name = "grid40"
                scene.rootNode.addChildNode(n40)
                coord.gridNode40 = n40
            } else { coord.gridNode40 = nil }
            coord.gridNode = nil
        } else {
            let gridNode = setupGridNode(zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gameState.gameMap, rows: rows, cols: cols)
            scene.rootNode.addChildNode(gridNode)
            coord.gridNode = gridNode
            coord.gridNode10 = nil
            coord.gridNode40 = nil
        }

        let placementsNode = SCNNode()
        placementsNode.name = "placements"
        placementsNode.position = SCNVector3Zero
        placementsNode.eulerAngles = SCNVector3Zero
        placementsNode.categoryBitMask = 0
        scene.rootNode.addChildNode(placementsNode)
        let wallLinePreviewNode = SCNNode()
        wallLinePreviewNode.name = "wallLinePreview"
        wallLinePreviewNode.position = SCNVector3Zero
        wallLinePreviewNode.eulerAngles = SCNVector3Zero
        wallLinePreviewNode.categoryBitMask = 0
        scene.rootNode.addChildNode(wallLinePreviewNode)

        let (cameraNode, cameraTarget, pivotIndicator) = setupCameraAndLights(in: scene, halfW: halfW, halfH: halfH)
        scnView.pointOfView = cameraNode

        coord.scene = scene
        coord.placementsNode = placementsNode
        coord.cameraNode = cameraNode
        coord.cameraTarget = cameraTarget
        coord.pivotIndicatorNode = pivotIndicator
        coord.wallLinePreviewNode = wallLinePreviewNode
        coord.mapRows = rows
        coord.mapCols = cols
        setupPlacementTemplatesAndGhosts(coord: coord, scene: scene, loader: loader)

        let opt = terrainBrushOption ?? .size1
        let brushPreviewOverlay = SCNNode()
        brushPreviewOverlay.name = "brushPreviewOverlay"
        brushPreviewOverlay.renderingOrder = 400
        scene.rootNode.addChildNode(brushPreviewOverlay)
        coord.brushPreviewOverlayNode = brushPreviewOverlay
        coord.terrainBrushOption = opt
        coord.isTerrainEditMode = isTerrainEditMode

        let cellSelectionOverlay = SCNNode()
        cellSelectionOverlay.name = "cellSelectionOverlay"
        scene.rootNode.addChildNode(cellSelectionOverlay)
        coord.cellSelectionOverlayNode = cellSelectionOverlay

        coord.lastGridZoom = CGFloat(gameState.mapCameraSettings.currentZoom)

        container.onCellHit = { [rows, cols] worldPos in
            cellFromMapLocalPosition(worldPos, rows: rows, cols: cols)
        }

        container.onMouseMove = { [weak container, gameState, rows, cols] loc in
            if coord.isTerrainEditMode, let overlayNode = coord.brushPreviewOverlayNode, let option = coord.terrainBrushOption, let container, let sv = container.scnView {
                let ptInView = container.convert(loc, to: sv)
                let inBounds = sv.bounds.contains(ptInView)
                var centerRow = rows / 2
                var centerCol = cols / 2
                if inBounds {
                    let hitOptions: [SCNHitTestOption: Any] = [.searchMode: SCNHitTestSearchMode.all.rawValue]
                    let hits = sv.hitTest(ptInView, options: hitOptions)
                    let terrainHit = hits.first(where: { $0.node.name == "terrain" })
                    if let hit = terrainHit, let cell = cellFromMapLocalPosition(hit.worldCoordinates, rows: rows, cols: cols) {
                        centerRow = cell.row
                        centerCol = cell.col
                    }
                }
                let cells = brushCells(centerRow: centerRow, centerCol: centerCol, brushOption: option, rows: rows, cols: cols)
                if let geo = makeGreenSurfaceGeometry(gameMap: gameState.gameMap, cells: cells, rows: rows, cols: cols) {
                    overlayNode.geometry = geo
                    overlayNode.isHidden = false
                } else {
                    overlayNode.geometry = nil
                    overlayNode.isHidden = true
                }
                return
            }
            coord.brushPreviewOverlayNode?.isHidden = true

            let objId = gameState.selectedPlacementObjectId
            coord.ghostNodes.values.forEach { $0.isHidden = true }
            guard let objectId = objId, SceneKitPlacementRegistry.placeableObjectIds.contains(objectId),
                  let ghost = coord.ghostNodes[objectId],
                  let config = SceneKitPlacementRegistry.config(for: objectId) else { return }
            guard let container else { return }
            if WallParent.isWall(objectId: objectId), container.isWallLineActive { return }
            guard let sv = container.scnView, sv.bounds.contains(container.convert(loc, to: sv)) else { return }
            let hitOptions: [SCNHitTestOption: Any] = [.searchMode: SCNHitTestSearchMode.all.rawValue, .categoryBitMask: 1]
            let hits = sv.hitTest(container.convert(loc, to: sv), options: hitOptions)
            guard let hit = hits.first(where: { $0.node.name == "terrain" }),
                  let (row, col) = cellFromMapLocalPosition(hit.worldCoordinates, rows: rows, cols: cols) else { return }
            let (centerRow, centerCol): (Int, Int) = config.cellW == 1 && config.cellH == 1
                ? (row, col)
                : (row + config.cellH / 2, col + config.cellW / 2)
            let cellsForConditions = [(centerRow, centerCol)]
            let canPlaceWall = !WallParent.isWall(objectId: objectId)
                || WallBuildConditions.wallBuildConditionsMet(gameState: gameState, objectId: objectId, cells: cellsForConditions)
            let ghostColor = canPlaceWall
                ? NSColor(red: 0.15, green: 0.95, blue: 0.25, alpha: 1)   // zelena = dozvoljeno
                : NSColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1)      // crvena = onemogućeno
            applyGhostColorRecursive(ghost, color: ghostColor, transparency: 0.55)
            let pos = worldPositionAtCell(row: centerRow, col: centerCol, rows: rows, cols: cols)
            var (minB, _) = ghost.boundingBox
            let y = max(groundLevelY, -CGFloat(minB.y) + config.yOffset)
            ghost.position = SCNVector3(pos.x, y, pos.z)
            ghost.isHidden = false
            if WallParent.isWall(objectId: objectId) {
                let last = coord.lastGhostCellByObject[objectId]
                if last?.0 != centerRow || last?.1 != centerCol {
                    coord.lastGhostCellByObject[objectId] = (centerRow, centerCol)
                    placementDebug("ghost Wall cell=(\(centerRow),\(centerCol)) pos=(\(Int(pos.x)),\(String(format: "%.2f", y)),\(Int(pos.z))) bboxMinY=\(String(format: "%.3f", CGFloat(minB.y)))")
                }
            }
        }

        container.onWallLinePreview = { [gameState] cells in
            let existingWalls = wallCellsSet(from: gameState.gameMap.placements)
            var wallObjectIds = wallCellToObjectId(from: gameState.gameMap.placements)
            let objectId = gameState.selectedPlacementObjectId ?? HugeWall.objectId
            for (row, col) in cells {
                wallObjectIds[MapCoordinate(row: row, col: col)] = objectId
            }
            refreshWallLinePreview(
                coord.wallLinePreviewNode,
                cells: cells,
                templates: coord.placementTemplates,
                existingWallCells: existingWalls,
                wallObjectIdPerCell: wallObjectIds,
                gameState: gameState,
                objectId: objectId,
                mapRows: rows,
                mapCols: cols
            )
        }
        container.onWallLineCommit = { [gameState, coord] cells in
            guard !cells.isEmpty else { return }
            DispatchQueue.main.async {
                let objectId = gameState.selectedPlacementObjectId ?? HugeWall.objectId
                if !WallParent.isWall(objectId: objectId) {
                    gameState.selectedPlacementObjectId = HugeWall.objectId
                }
                let objectIdForWall = gameState.selectedPlacementObjectId ?? HugeWall.objectId
                if WallParent.isWall(objectId: objectIdForWall), !WallBuildConditions.wallBuildConditionsMet(gameState: gameState, objectId: objectIdForWall, cells: cells) {
                    return
                }
                var placedAny = false
                for (row, col) in cells {
                    let ok = gameState.placeSelectedObjectAt(row: row, col: col, playSound: false)
                    if ok { placedAny = true }
                }
                if placedAny && gameState.playPlacementSound {
                    AudioManager.shared.playSound(named: "place", volume: gameState.audioSoundsVolume)
                }
                if placedAny, let node = coord.placementsNode {
                    refreshPlacements(node, placements: gameState.gameMap.placements, templates: coord.placementTemplates, mapRows: rows, mapCols: cols)
                }
            }
        }

        scnView.scene = scene
        coord.gameState = gameState
        coord.mapViewContainer = container
        coord.animatedZoom = CGFloat(gameState.mapCameraSettings.currentZoom)
        scnView.delegate = coord
        applyCamera(cameraNode: cameraNode, targetNode: cameraTarget, settings: gameState.mapCameraSettings)
        coord.gridNode?.isHidden = !showGrid
        coord.gridNode10?.isHidden = !showGrid || !gridShow10
        coord.gridNode40?.isHidden = !showGrid || !gridShow40
        refreshPlacements(placementsNode, placements: gameState.gameMap.placements, templates: coord.placementTemplates, mapRows: rows, mapCols: cols)
        DispatchQueue.main.async {
            gameState.levelLoadingMessage = nil
            gameState.isLevelReady = true
        }

        container.onPanStart = { [gameState] mouseLoc in
            let s = gameState.mapCameraSettings
            let msg = "[Camera] pan start miš(view)=(\(String(format: "%.1f", mouseLoc.x)),\(String(format: "%.1f", mouseLoc.y))) kamera panOffset=(\(String(format: "%.1f", s.panOffset.x)),\(String(format: "%.1f", s.panOffset.y))) mapRotation=\(String(format: "%.2f", s.mapRotation)) zoom=\(String(format: "%.1f", s.currentZoom))"
            print(msg)
            Task { @MainActor in PlacementDebugConsole.shared.append(msg) }
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
            if let cb = coord.onCellSelectionToggle {
                cb(row, col)
                DispatchQueue.main.async { gameState.objectWillChange.send() }
                return
            }
            if let cb = coord.onTerrainAddBrushSelection {
                cb(row, col)
                DispatchQueue.main.async { gameState.objectWillChange.send() }
                return
            }
            if coord.isTerrainEditMode, let cb = coord.onTerrainEdit {
                cb(row, col)
                return
            }
            if container.isEraseMode, let onRemoveAt = onRemoveAt {
                onRemoveAt(row, col)
                if let node = coord.placementsNode {
                    refreshPlacements(node, placements: gameState.gameMap.placements, templates: coord.placementTemplates, mapRows: coord.mapRows, mapCols: coord.mapCols)
                }
                return
            }
            let objectId = container.currentSelectedPlacementObjectId ?? gameState.selectedPlacementObjectId
            placementDebug("map click row=\(row) col=\(col) selected=\(objectId ?? "nil")")
            guard let objId = objectId, !objId.isEmpty else {
                let msg = "Objekt nije odabran. Odaberi Zid/Tržnicu (Dvor), Mlin/Pekaru (Hrana) ili Kokošinjac/Kukuruz (Farma) u donjem baru."
                DispatchQueue.main.async { gameState.placementError = msg }
                return
            }
            if WallParent.isWall(objectId: objId), !WallBuildConditions.wallBuildConditionsMet(gameState: gameState, objectId: objId, cells: [(row, col)]) {
                return
            }
            DispatchQueue.main.async {
                if gameState.selectedPlacementObjectId != objId {
                    gameState.selectedPlacementObjectId = objId
                }
                let ok = gameState.placeSelectedObjectAt(row: row, col: col)
                placementDebug("placeSelectedObjectAt object=\(objId) row=\(row) col=\(col) ok=\(ok)")
                if ok, let node = coord.placementsNode {
                    refreshPlacements(node, placements: gameState.gameMap.placements, templates: coord.placementTemplates, mapRows: coord.mapRows, mapCols: coord.mapCols)
                }
            }
        }
        container.onRightClick = { [gameState, isTerrainEditMode, onExitTerrainEditMode] in
            if isTerrainEditMode, let exit = onExitTerrainEditMode {
                DispatchQueue.main.async { exit() }
            } else {
                DispatchQueue.main.async { gameState.selectedPlacementObjectId = nil }
            }
        }
        container.onPlacementError = { [gameState] msg in
            DispatchQueue.main.async { gameState.placementError = msg }
        }
        coord.isTerrainEditMode = isTerrainEditMode
        coord.onTerrainEdit = onTerrainEdit
        coord.onTerrainAddBrushSelection = onTerrainAddBrushSelection
        coord.onCellSelectionToggle = onCellSelectionToggle
        container.onVertexDotSelected = { [onVertexDotSelected] vr, vc in
            DispatchQueue.main.async { onVertexDotSelected?(vr, vc) }
        }
        container.handPanMode = handPanMode
        container.isEraseMode = isEraseMode
        container.isCellSelectionMode = isCellSelectionMode
        container.hasObjectSelected = isPlaceMode && !isTerrainEditMode
        container.cameraPanAllowed = !isPlaceMode && !isTerrainEditMode && !isEraseMode && !isCellSelectionMode
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
        let coord = context.coordinator

        let wasTerrain = coord.isTerrainEditMode
        coord.isTerrainEditMode = isTerrainEditMode
        coord.onTerrainEdit = onTerrainEdit
        coord.onTerrainAddBrushSelection = onTerrainAddBrushSelection
        coord.onCellSelectionToggle = onCellSelectionToggle
        container.onVertexDotSelected = { [onVertexDotSelected] vr, vc in
            DispatchQueue.main.async { onVertexDotSelected?(vr, vc) }
        }
        if isTerrainEditMode && !wasTerrain {
            Task { @MainActor in MapEditorConsole.shared.append("Teren: selector uključen (zelena kockica prati miš)") }
        }
        if !isTerrainEditMode {
            coord.brushPreviewOverlayNode?.isHidden = true
        } else {
            coord.brushPreviewOverlayNode?.isHidden = false
            container.updateGhostFromCurrentMouseLocation()
        }
        if let option = terrainBrushOption {
            coord.terrainBrushOption = option
        }
        container.handPanMode = handPanMode
        container.isEraseMode = isEraseMode
        container.isCellSelectionMode = isCellSelectionMode
        container.hasObjectSelected = isPlaceMode && !isTerrainEditMode
        container.cameraPanAllowed = !isPlaceMode && !isTerrainEditMode && !isEraseMode && !isCellSelectionMode
        container.currentSelectedPlacementObjectId = gameState.selectedPlacementObjectId
        container.selectedToolsPanelItem = gameState.selectedToolsPanelItem
        container.onRightClick = { [gameState, isTerrainEditMode, onExitTerrainEditMode] in
            if isTerrainEditMode, let exit = onExitTerrainEditMode {
                DispatchQueue.main.async { exit() }
            } else {
                DispatchQueue.main.async { gameState.selectedPlacementObjectId = nil }
            }
        }
        container.onPanStart = { [gameState] mouseLoc in
            let s = gameState.mapCameraSettings
            let msg = "[Camera] pan start miš(view)=(\(String(format: "%.1f", mouseLoc.x)),\(String(format: "%.1f", mouseLoc.y))) kamera panOffset=(\(String(format: "%.1f", s.panOffset.x)),\(String(format: "%.1f", s.panOffset.y))) mapRotation=\(String(format: "%.2f", s.mapRotation)) zoom=\(String(format: "%.1f", s.currentZoom))"
            print(msg)
            Task { @MainActor in PlacementDebugConsole.shared.append(msg) }
        }
        container.window?.invalidateCursorRects(for: container)

        if let w = container.window, w.isKeyWindow, w.firstResponder != container {
            w.makeFirstResponder(container)
        }

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
        let rows = gameState.gameMap.rows
        let cols = gameState.gameMap.cols
        let mapWidth = effectiveMapWorldW(cols: cols)
        let mapHeight = effectiveMapWorldH(rows: rows)
        coord.mapRows = rows
        coord.mapCols = cols
        let zoom = gameState.mapCameraSettings.currentZoom
        let div40 = gridDivisionsBuilding(rows: rows, cols: cols)
        let div10 = gridDivisionsDisplay(rows: rows, cols: cols)
        let mapRows = coord.mapRows
        let mapCols = coord.mapCols
        let gridGameMap = gameState.gameMap
        let shouldRefreshGrid = abs(CGFloat(zoom) - coord.lastGridZoom) > 0.01
        if let grid = coord.gridNode {
            grid.isHidden = !showGrid
            if shouldRefreshGrid {
                coord.lastGridZoom = CGFloat(zoom)
                refreshGrid(gridNode: grid, zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
            }
        }
        if isMapEditorGridMode, let scene = coord.scene {
            if gridShow10, coord.gridNode10 == nil {
                let n10 = setupGridNode(zoom: zoom, gridDivisions: div10, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
                n10.name = "grid10"
                scene.rootNode.addChildNode(n10)
                coord.gridNode10 = n10
            } else if !gridShow10, let g10 = coord.gridNode10 {
                g10.removeFromParentNode()
                coord.gridNode10 = nil
            }
            if gridShow40, coord.gridNode40 == nil {
                let n40 = setupGridNode(zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
                n40.name = "grid40"
                scene.rootNode.addChildNode(n40)
                coord.gridNode40 = n40
            } else if !gridShow40, let g40 = coord.gridNode40 {
                g40.removeFromParentNode()
                coord.gridNode40 = nil
            }
        }
        if let g10 = coord.gridNode10 {
            g10.isHidden = !showGrid || !gridShow10
            if shouldRefreshGrid {
                refreshGrid(gridNode: g10, zoom: zoom, gridDivisions: div10, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
            }
        }
        if let g40 = coord.gridNode40 {
            g40.isHidden = !showGrid || !gridShow40
            if shouldRefreshGrid {
                refreshGrid(gridNode: g40, zoom: zoom, gridDivisions: div40, mapWidth: mapWidth, mapHeight: mapHeight, gameMap: gridGameMap, rows: mapRows, cols: mapCols)
            }
        }
        if coord.gridNode10 != nil || coord.gridNode40 != nil, abs(CGFloat(zoom) - coord.lastGridZoom) > 0.01 {
            coord.lastGridZoom = CGFloat(zoom)
        }
        if let sid = selectedId, !WallParent.isWall(objectId: sid) {
            coord.wallLinePreviewNode?.childNodes.forEach { $0.removeFromParentNode() }
        }

        // Map Editor – elevacija terena: mesh i tekstura samo kad se visine promijene (ne svaki frame).
        let terrainChecksum = isTerrainEditMode ? terrainHeightsChecksum(gameMap: gameState.gameMap) : 0
        let terrainNeedsRebuild = isTerrainEditMode && (terrainChecksum != coord.lastTerrainHeightsChecksum || !wasTerrain)
        if terrainNeedsRebuild {
            coord.lastTerrainHeightsChecksum = terrainChecksum
        }
        if terrainNeedsRebuild, let scene = coord.scene, let terrain = findTerrainInHierarchy(scene.rootNode),
           let newGeo = makeTerrainGeometryWithHeights(gameMap: gameState.gameMap) {
            let numElements = newGeo.elements.count
            let oldMat = terrain.geometry?.materials.first ?? SCNMaterial()
            applyTerrainPBRTiled(to: oldMat)
            // Element 0 = gornja ploha (oldMat), element 1 = bočne + donja ploča (sideMat). SceneKit: materials[i] → element i.
            if numElements > 1 {
                let sideMat = SCNMaterial()
                sideMat.diffuse.contents = NSColor.white
                sideMat.ambient.contents = NSColor.white
                sideMat.specular.contents = NSColor.darkGray
                sideMat.isDoubleSided = true
                sideMat.lightingModel = .physicallyBased
                newGeo.materials = [oldMat, sideMat]
            } else {
                newGeo.materials = [oldMat]
            }
            terrain.geometry = newGeo
        }

        // Map Editor – označene ćelije: prikaži zelenu površinu (3D) nad odabranim ćelijama.
        if gameState.isMapEditorMode, let overlayNode = coord.cellSelectionOverlayNode {
            let selected = gameState.mapEditorState?.selectedCells ?? []
            refreshCellSelectionOverlay(overlayNode: overlayNode, selectedCells: selected, gameMap: gameState.gameMap, rows: coord.mapRows, cols: coord.mapCols)
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

    private func wallCellsSet(from placements: [Placement]) -> Set<MapCoordinate> {
        var set: Set<MapCoordinate> = []
        for p in placements where WallParent.isWall(objectId: p.objectId) {
            for c in p.coveredCoordinates() { set.insert(c) }
        }
        return set
    }

    /// Mapa ćelija zida → objectId (za visinu trokutastih spojnica: mali zid = 240, veliki = 400).
    private func wallCellToObjectId(from placements: [Placement]) -> [MapCoordinate: String] {
        var map: [MapCoordinate: String] = [:]
        for p in placements where WallParent.isWall(objectId: p.objectId) {
            for c in p.coveredCoordinates() { map[c] = p.objectId }
        }
        return map
    }

    private enum TriangleCorner {
        case nw, ne, sw, se
    }

    private func makeRightTrianglePrismNode(corner: TriangleCorner, size: CGFloat, height: CGFloat, color: NSColor, alpha: CGFloat = 1.0) -> SCNNode {
        let h = size / 2
        let a: SCNVector3
        let b: SCNVector3
        let c: SCNVector3
        switch corner {
        case .nw:
            a = SCNVector3(-h, 0, -h); b = SCNVector3(h, 0, -h); c = SCNVector3(-h, 0, h)
        case .ne:
            a = SCNVector3(h, 0, -h); b = SCNVector3(-h, 0, -h); c = SCNVector3(h, 0, h)
        case .sw:
            a = SCNVector3(-h, 0, h); b = SCNVector3(h, 0, h); c = SCNVector3(-h, 0, -h)
        case .se:
            a = SCNVector3(h, 0, h); b = SCNVector3(-h, 0, h); c = SCNVector3(h, 0, -h)
        }
        let vertices: [SCNVector3] = [
            a, b, c,
            SCNVector3(a.x, height, a.z),
            SCNVector3(b.x, height, b.z),
            SCNVector3(c.x, height, c.z),
        ]
        let texcoords: [CGPoint] = vertices.map { v in
            CGPoint(x: (CGFloat(v.x) + h) / size, y: (CGFloat(v.z) + h) / size)
        }
        let indices: [UInt32] = [
            0, 2, 1,
            3, 4, 5,
            0, 1, 4, 0, 4, 3,
            1, 2, 5, 1, 5, 4,
            2, 0, 3, 2, 3, 5,
        ]
        let src = SCNGeometrySource(vertices: vertices)
        let uv = SCNGeometrySource(textureCoordinates: texcoords)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [src, uv], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.ambient.contents = NSColor.white
        mat.specular.contents = NSColor.darkGray
        mat.isDoubleSided = true
        mat.lightingModel = .physicallyBased
        mat.transparency = alpha
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    private func wallCubeHeightFromTemplate(_ template: SCNNode) -> CGFloat {
        let (minB, maxB) = template.boundingBox
        return max(1, CGFloat(maxB.y - minB.y))
    }

    private func isWallLineSloped(_ cells: [(Int, Int)]) -> Bool {
        guard cells.count >= 2 else { return false }
        for i in 1..<cells.count {
            let prev = cells[i - 1]
            let cur = cells[i]
            let dRow = abs(cur.0 - prev.0)
            let dCol = abs(cur.1 - prev.1)
            if dRow > 0 && dCol > 0 { return true }
        }
        return false
    }

    private func hasAnyDiagonalAdjacency(_ wallCells: Set<MapCoordinate>) -> Bool {
        guard wallCells.count >= 2 else { return false }
        for cell in wallCells {
            let se = MapCoordinate(row: cell.row + 1, col: cell.col + 1)
            let sw = MapCoordinate(row: cell.row + 1, col: cell.col - 1)
            if wallCells.contains(se) || wallCells.contains(sw) { return true }
        }
        return false
    }

    private func hasDiagonalAdjacency(in wallCells: Set<MapCoordinate>, involving focus: Set<MapCoordinate>) -> Bool {
        guard !focus.isEmpty, wallCells.count >= 2 else { return false }
        for cell in focus {
            let nw = MapCoordinate(row: cell.row - 1, col: cell.col - 1)
            let ne = MapCoordinate(row: cell.row - 1, col: cell.col + 1)
            let sw = MapCoordinate(row: cell.row + 1, col: cell.col - 1)
            let se = MapCoordinate(row: cell.row + 1, col: cell.col + 1)
            if wallCells.contains(nw) || wallCells.contains(ne) || wallCells.contains(sw) || wallCells.contains(se) {
                return true
            }
        }
        return false
    }

    private func stepsRotation(for corner: TriangleCorner) -> CGFloat {
        switch corner {
        case .nw: return 0
        case .ne: return -.pi / 2
        case .se: return .pi
        case .sw: return .pi / 2
        }
    }

    /// Iz mostne ćelije i susjednih zidova odredi corner pravokutnog trokuta tako da
    /// katete gledaju prema unutra (prema zidovima), a hipotenuza prema van.
    private func outwardCorner(for bridge: MapCoordinate, wallCells: Set<MapCoordinate>) -> TriangleCorner? {
        let n = wallCells.contains(MapCoordinate(row: bridge.row - 1, col: bridge.col))
        let e = wallCells.contains(MapCoordinate(row: bridge.row, col: bridge.col + 1))
        let s = wallCells.contains(MapCoordinate(row: bridge.row + 1, col: bridge.col))
        let w = wallCells.contains(MapCoordinate(row: bridge.row, col: bridge.col - 1))
        let count = (n ? 1 : 0) + (e ? 1 : 0) + (s ? 1 : 0) + (w ? 1 : 0)
        guard count == 2 else { return nil }
        if n && e { return .ne }
        if e && s { return .se }
        if s && w { return .sw }
        if w && n { return .nw }
        return nil
    }

    private func firstMaterialRecursive(_ node: SCNNode) -> SCNMaterial? {
        if let mat = node.geometry?.firstMaterial { return mat }
        for child in node.childNodes {
            if let mat = firstMaterialRecursive(child) { return mat }
        }
        return nil
    }

    private func addWallDiagonalConnectors(
        to node: SCNNode,
        wallCells: Set<MapCoordinate>,
        focusCells: Set<MapCoordinate>? = nil,
        color: NSColor,
        alpha: CGFloat = 1.0,
        templateForHeight: SCNNode,
        useWallTexture: Bool = false,
        stepsTemplate: SCNNode? = nil,
        wallObjectIdPerCell: [MapCoordinate: String]? = nil,
        smallWallTemplate: SCNNode? = nil,
        mapRows: Int,
        mapCols: Int
    ) -> Int {
        guard !wallCells.isEmpty else { return 0 }
        let _ = stepsTemplate
        var created = 0
        var createdBridgeCells: Set<MapCoordinate> = []
        var diagonalPairsDetected = 0
        var skippedBridgeOccupied = 0
        let defaultH = wallCubeHeightFromTemplate(templateForHeight)
        let connectorSize = worldUnitsPerCell
        func heightForCell(_ cell: MapCoordinate) -> CGFloat {
            guard let ids = wallObjectIdPerCell, let id = ids[cell] else { return defaultH }
            return ParentWall.wallHeight(for: id)
        }
        func templateAndHeightForConnector(cell1: MapCoordinate, cell2: MapCoordinate) -> (template: SCNNode, h: CGFloat) {
            let h = max(heightForCell(cell1), heightForCell(cell2))
            let useSmall = h <= 250
            let template = (useSmall && smallWallTemplate != nil) ? smallWallTemplate! : templateForHeight
            return (template, h)
        }
        func cornerName(_ corner: TriangleCorner) -> String {
            switch corner {
            case .nw: return "nw"
            case .ne: return "ne"
            case .sw: return "sw"
            case .se: return "se"
            }
        }
        for cell in wallCells {
            let r = cell.row
            let c = cell.col

            // NW-SE dijagonala: (r,c) i (r+1,c+1), trokuti u (r,c+1) i (r+1,c)
            let se = MapCoordinate(row: r + 1, col: c + 1)
            if wallCells.contains(se) {
                diagonalPairsDetected += 1
                if focusCells == nil || focusCells!.contains(cell) || focusCells!.contains(se) {
                    let b1 = MapCoordinate(row: r, col: c + 1)
                    let b2 = MapCoordinate(row: r + 1, col: c)
                    if wallCells.contains(b1) { skippedBridgeOccupied += 1 }
                    if wallCells.contains(b2) { skippedBridgeOccupied += 1 }
                    let (connTemplateNWSE, connHNWSE) = templateAndHeightForConnector(cell1: cell, cell2: se)
                    if !createdBridgeCells.contains(b1), !wallCells.contains(b1) {
                        let p = worldPositionAtCell(row: b1.row, col: b1.col, rows: mapRows, cols: mapCols)
                        guard let corner = outwardCorner(for: b1, wallCells: wallCells) else { continue }
                        let tri: SCNNode
                        if let stepsTemplate {
                            tri = stepsTemplate.clone()
                            duplicateMaterialsRecursive(tri)
                            var (minB, maxB) = tri.boundingBox
                            let currentHeight = max(0.001, CGFloat(maxB.y - minB.y))
                            let scaleY = connHNWSE / currentHeight
                            tri.scale = SCNVector3(1, scaleY, 1)
                            (minB, maxB) = tri.boundingBox
                            let y = max(groundLevelY, -CGFloat(minB.y)) + 0.5
                            tri.position = SCNVector3(p.x, y, p.z)
                            tri.eulerAngles.y = stepsRotation(for: corner)
                            _ = Steps.reapplyTexture(to: tri, bundle: .main)
                            if alpha < 1 {
                                applyGhostColorRecursive(tri, color: color, transparency: alpha)
                            } else {
                                applyTransparencyRecursive(alpha, to: tri)
                            }
                        } else {
                            tri = makeRightTrianglePrismNode(corner: corner, size: connectorSize, height: connHNWSE, color: color, alpha: alpha)
                            if let source = (useWallTexture ? firstMaterialRecursive(connTemplateNWSE) : nil)?.copy() as? SCNMaterial {
                                source.transparency = alpha
                                source.isDoubleSided = true
                                tri.geometry?.materials = [source]
                            }
                            tri.position = SCNVector3(p.x, groundLevelY + 0.5, p.z)
                        }
                        tri.name = "wall_diag_tri_\(cornerName(corner))"
                        tri.renderingOrder = 10
                        tri.categoryBitMask = 0
                        placementDebug("connector create corner=\(cornerName(corner)) at=(\(b1.row),\(b1.col))")
                        node.addChildNode(tri)
                        createdBridgeCells.insert(b1)
                        created += 1
                    }
                    if !createdBridgeCells.contains(b2), !wallCells.contains(b2) {
                        let p = worldPositionAtCell(row: b2.row, col: b2.col, rows: mapRows, cols: mapCols)
                        guard let corner = outwardCorner(for: b2, wallCells: wallCells) else { continue }
                        let tri: SCNNode
                        if let stepsTemplate {
                            tri = stepsTemplate.clone()
                            duplicateMaterialsRecursive(tri)
                            var (minB, maxB) = tri.boundingBox
                            let currentHeight = max(0.001, CGFloat(maxB.y - minB.y))
                            let scaleY = connHNWSE / currentHeight
                            tri.scale = SCNVector3(1, scaleY, 1)
                            (minB, maxB) = tri.boundingBox
                            let y = max(groundLevelY, -CGFloat(minB.y)) + 0.5
                            tri.position = SCNVector3(p.x, y, p.z)
                            tri.eulerAngles.y = stepsRotation(for: corner)
                            _ = Steps.reapplyTexture(to: tri, bundle: .main)
                            if alpha < 1 {
                                applyGhostColorRecursive(tri, color: color, transparency: alpha)
                            } else {
                                applyTransparencyRecursive(alpha, to: tri)
                            }
                        } else {
                            tri = makeRightTrianglePrismNode(corner: corner, size: connectorSize, height: connHNWSE, color: color, alpha: alpha)
                            if let source = (useWallTexture ? firstMaterialRecursive(connTemplateNWSE) : nil)?.copy() as? SCNMaterial {
                                source.transparency = alpha
                                source.isDoubleSided = true
                                tri.geometry?.materials = [source]
                            }
                            tri.position = SCNVector3(p.x, groundLevelY + 0.5, p.z)
                        }
                        tri.name = "wall_diag_tri_\(cornerName(corner))"
                        tri.renderingOrder = 10
                        tri.categoryBitMask = 0
                        placementDebug("connector create corner=\(cornerName(corner)) at=(\(b2.row),\(b2.col))")
                        node.addChildNode(tri)
                        createdBridgeCells.insert(b2)
                        created += 1
                    }
                }
            }

            // NE-SW dijagonala: (r,c) i (r+1,c-1), trokuti u (r,c-1) i (r+1,c)
            let sw = MapCoordinate(row: r + 1, col: c - 1)
            if wallCells.contains(sw) {
                diagonalPairsDetected += 1
                if focusCells == nil || focusCells!.contains(cell) || focusCells!.contains(sw) {
                    let b1 = MapCoordinate(row: r, col: c - 1)
                    let b2 = MapCoordinate(row: r + 1, col: c)
                    if wallCells.contains(b1) { skippedBridgeOccupied += 1 }
                    if wallCells.contains(b2) { skippedBridgeOccupied += 1 }
                    let (connTemplateNESW, connHNESW) = templateAndHeightForConnector(cell1: cell, cell2: sw)
                    if !createdBridgeCells.contains(b1), !wallCells.contains(b1) {
                        let p = worldPositionAtCell(row: b1.row, col: b1.col, rows: mapRows, cols: mapCols)
                        guard let corner = outwardCorner(for: b1, wallCells: wallCells) else { continue }
                        let tri: SCNNode
                        if let stepsTemplate {
                            tri = stepsTemplate.clone()
                            duplicateMaterialsRecursive(tri)
                            var (minB, maxB) = tri.boundingBox
                            let currentHeight = max(0.001, CGFloat(maxB.y - minB.y))
                            let scaleY = connHNESW / currentHeight
                            tri.scale = SCNVector3(1, scaleY, 1)
                            (minB, maxB) = tri.boundingBox
                            let y = max(groundLevelY, -CGFloat(minB.y)) + 0.5
                            tri.position = SCNVector3(p.x, y, p.z)
                            tri.eulerAngles.y = stepsRotation(for: corner)
                            _ = Steps.reapplyTexture(to: tri, bundle: .main)
                            if alpha < 1 {
                                applyGhostColorRecursive(tri, color: color, transparency: alpha)
                            } else {
                                applyTransparencyRecursive(alpha, to: tri)
                            }
                        } else {
                            tri = makeRightTrianglePrismNode(corner: corner, size: connectorSize, height: connHNESW, color: color, alpha: alpha)
                            if let source = (useWallTexture ? firstMaterialRecursive(connTemplateNESW) : nil)?.copy() as? SCNMaterial {
                                source.transparency = alpha
                                source.isDoubleSided = true
                                tri.geometry?.materials = [source]
                            }
                            tri.position = SCNVector3(p.x, groundLevelY + 0.5, p.z)
                        }
                        tri.name = "wall_diag_tri_\(cornerName(corner))"
                        tri.renderingOrder = 10
                        tri.categoryBitMask = 0
                        placementDebug("connector create corner=\(cornerName(corner)) at=(\(b1.row),\(b1.col))")
                        node.addChildNode(tri)
                        createdBridgeCells.insert(b1)
                        created += 1
                    }
                    if !createdBridgeCells.contains(b2), !wallCells.contains(b2) {
                        let p = worldPositionAtCell(row: b2.row, col: b2.col, rows: mapRows, cols: mapCols)
                        guard let corner = outwardCorner(for: b2, wallCells: wallCells) else { continue }
                        let tri: SCNNode
                        if let stepsTemplate {
                            tri = stepsTemplate.clone()
                            duplicateMaterialsRecursive(tri)
                            var (minB, maxB) = tri.boundingBox
                            let currentHeight = max(0.001, CGFloat(maxB.y - minB.y))
                            let scaleY = connHNESW / currentHeight
                            tri.scale = SCNVector3(1, scaleY, 1)
                            (minB, maxB) = tri.boundingBox
                            let y = max(groundLevelY, -CGFloat(minB.y)) + 0.5
                            tri.position = SCNVector3(p.x, y, p.z)
                            tri.eulerAngles.y = stepsRotation(for: corner)
                            _ = Steps.reapplyTexture(to: tri, bundle: .main)
                            if alpha < 1 {
                                applyGhostColorRecursive(tri, color: color, transparency: alpha)
                            } else {
                                applyTransparencyRecursive(alpha, to: tri)
                            }
                        } else {
                            tri = makeRightTrianglePrismNode(corner: corner, size: connectorSize, height: connHNESW, color: color, alpha: alpha)
                            if let source = (useWallTexture ? firstMaterialRecursive(connTemplateNESW) : nil)?.copy() as? SCNMaterial {
                                source.transparency = alpha
                                source.isDoubleSided = true
                                tri.geometry?.materials = [source]
                            }
                            tri.position = SCNVector3(p.x, groundLevelY + 0.5, p.z)
                        }
                        tri.name = "wall_diag_tri_\(cornerName(corner))"
                        tri.renderingOrder = 10
                        tri.categoryBitMask = 0
                        placementDebug("connector create corner=\(cornerName(corner)) at=(\(b2.row),\(b2.col))")
                        node.addChildNode(tri)
                        createdBridgeCells.insert(b2)
                        created += 1
                    }
                }
            }
        }
        if focusCells != nil {
            placementDebug("wall preview connectors: diagonalPairs=\(diagonalPairsDetected) created=\(created) skippedBridgeOccupied=\(skippedBridgeOccupied)")
        }
        return created
    }

    private func applyAdaptiveWallShape(_ instance: SCNNode, row: Int, col: Int, wallCells: Set<MapCoordinate>) -> (offsetX: CGFloat, offsetZ: CGFloat) {
        // Zidne kocke ostaju netaknute; diagonalni spoj se radi dodatnim trokutima.
        return (0, 0)
    }

    private func addVerticalWallSideSteps(
        to node: SCNNode,
        row: Int,
        col: Int,
        wallCells: Set<MapCoordinate>,
        stepsTemplate: SCNNode,
        alpha: CGFloat,
        ghostColor: NSColor? = nil,
        mapRows: Int,
        mapCols: Int
    ) {
        let hasNorth = wallCells.contains(MapCoordinate(row: row - 1, col: col))
        let hasSouth = wallCells.contains(MapCoordinate(row: row + 1, col: col))
        guard hasNorth || hasSouth else { return }

        let sides: [(dc: Int, rotY: CGFloat, name: String)] = [
            (-1, .pi / 2, "wall_steps_side_w"),
            (1, -.pi / 2, "wall_steps_side_e"),
        ]

        for side in sides {
            let sideCell = MapCoordinate(row: row, col: col + side.dc)
            // Ako je bočna ćelija već zid, preskoči da nema vizualnog preklapanja.
            if wallCells.contains(sideCell) { continue }
            let pos = worldPositionAtCell(row: sideCell.row, col: sideCell.col, rows: mapRows, cols: mapCols)
            let instance = stepsTemplate.clone()
            duplicateMaterialsRecursive(instance)
            var (minB, _) = instance.boundingBox
            let y = max(groundLevelY, -CGFloat(minB.y))
            instance.position = SCNVector3(pos.x, y, pos.z)
            instance.eulerAngles.y = side.rotY
            instance.name = side.name
            instance.categoryBitMask = 0
            instance.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(alpha, to: instance)
            if let ghostColor {
                applyGhostColorRecursive(instance, color: ghostColor, transparency: alpha)
            }
            node.addChildNode(instance)
        }
    }

    private func addPlacementNode(for p: Placement, to node: SCNNode, templates: [String: SCNNode], fallback: SCNNode, wallCells: Set<MapCoordinate>, mapRows: Int, mapCols: Int) {
        guard let config = SceneKitPlacementRegistry.config(for: p.objectId) else {
            addFallbackBoxes(for: p, to: node, fallback: fallback, mapRows: mapRows, mapCols: mapCols)
            return
        }
        guard let template = templates[p.objectId]?.clone(), !template.childNodes.isEmpty else {
            addFallbackBoxes(for: p, to: node, fallback: fallback, mapRows: mapRows, mapCols: mapCols)
            return
        }
        template.isHidden = false
        template.categoryBitMask = 0
        template.childNodes.forEach { $0.categoryBitMask = 0; $0.isHidden = false }
        if config.cellW == 1 && config.cellH == 1 {
            for r in p.row..<(p.row + p.height) {
                for c in p.col..<(p.col + p.width) {
                    let pos = worldPositionAtCell(row: r, col: c, rows: mapRows, cols: mapCols)
                    let instance = template.clone()
                    var (minB, _) = instance.boundingBox
                    let placeY = max(groundLevelY, -CGFloat(minB.y))
                    let wallShift: (offsetX: CGFloat, offsetZ: CGFloat) = WallParent.isWall(objectId: p.objectId)
                        ? applyAdaptiveWallShape(instance, row: r, col: c, wallCells: wallCells)
                        : (offsetX: 0, offsetZ: 0)
                    instance.position = SCNVector3(pos.x + wallShift.offsetX, placeY, pos.z + wallShift.offsetZ)
                    _ = SceneKitPlacementRegistry.reapplyTexture(objectId: p.objectId, to: instance, bundle: .main)
                    node.addChildNode(instance)
                    if WallParent.isWall(objectId: p.objectId) {
                        var (mn, mx) = instance.boundingBox
                        let finalHeight = CGFloat(mx.y - mn.y)
                        placementDebug("render Wall instance row=\(r) col=\(c) placeY=\(String(format: "%.2f", placeY)) finalHeight=\(String(format: "%.3f", finalHeight)) bboxY=[\(String(format: "%.3f", CGFloat(mn.y))),\(String(format: "%.3f", CGFloat(mx.y)))]")
                    }
                }
            }
        } else {
            let centerRow = p.row + p.height / 2
            let centerCol = p.col + p.width / 2
            let pos = worldPositionAtCell(row: centerRow, col: centerCol, rows: mapRows, cols: mapCols)
            var (minB, _) = template.boundingBox
            let placeY = max(groundLevelY, -CGFloat(minB.y) + config.yOffset)
            template.position = SCNVector3(pos.x, placeY, pos.z)
            _ = SceneKitPlacementRegistry.reapplyTexture(objectId: p.objectId, to: template, bundle: .main)
            node.addChildNode(template)
        }
    }

    private func refreshPlacements(_ node: SCNNode?, placements: [Placement], templates: [String: SCNNode], mapRows: Int, mapCols: Int) {
        guard let node = node else { return }
        node.childNodes.forEach { $0.removeFromParentNode() }
        node.isHidden = false
        let boxFallback = makePlacementBoxNode()
        boxFallback.categoryBitMask = 0
        let wallCells = wallCellsSet(from: placements)
        for p in placements {
            addPlacementNode(for: p, to: node, templates: templates, fallback: boxFallback, wallCells: wallCells, mapRows: mapRows, mapCols: mapCols)
        }
        if let wallTemplate = templates[HugeWall.objectId], hasAnyDiagonalAdjacency(wallCells) {
            let wallObjectIds = wallCellToObjectId(from: placements)
            let count = addWallDiagonalConnectors(
                to: node,
                wallCells: wallCells,
                focusCells: nil,
                color: NSColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1),
                alpha: 1.0,
                templateForHeight: wallTemplate,
                useWallTexture: true,
                stepsTemplate: templates[Steps.objectId],
                wallObjectIdPerCell: wallObjectIds,
                smallWallTemplate: templates[SmallWall.objectId],
                mapRows: mapRows,
                mapCols: mapCols
            )
            if count > 0 {
                placementDebug("wall diagonal connectors created: \(count)")
            }
        }
    }

    private func refreshWallLinePreview(_ node: SCNNode?, cells: [(Int, Int)], templates: [String: SCNNode], existingWallCells: Set<MapCoordinate>, wallObjectIdPerCell: [MapCoordinate: String] = [:], gameState: GameState? = nil, objectId: String = HugeWall.objectId, mapRows: Int, mapCols: Int) {
        guard let node = node else { return }
        node.childNodes.forEach { $0.removeFromParentNode() }
        guard !cells.isEmpty,
              let template = templates[objectId],
              let config = SceneKitPlacementRegistry.config(for: objectId) else { return }
        let previewSet = Set(cells.map { MapCoordinate(row: $0.0, col: $0.1) })
        let allWallCells = existingWallCells.union(previewSet)
        placementDebug("wall preview update: dragCells=\(cells.count) uniquePreview=\(previewSet.count) existing=\(existingWallCells.count) total=\(allWallCells.count)")
        let canPlace = gameState.map { WallBuildConditions.wallBuildConditionsMet(gameState: $0, objectId: objectId, cells: cells) } ?? true
        let ghostColor = canPlace
            ? NSColor(red: 0.15, green: 0.95, blue: 0.25, alpha: 1)
            : NSColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1)
        let slopedLine = isWallLineSloped(cells)
        let slopedByExisting = hasDiagonalAdjacency(in: allWallCells, involving: previewSet)
        let sloped = slopedLine || slopedByExisting
        placementDebug("wall preview slope detection: line=\(slopedLine) existing=\(slopedByExisting) active=\(sloped)")
        for (row, col) in cells {
            let instance = template.clone()
            duplicateMaterialsRecursive(instance)
            var (minB, _) = instance.boundingBox
            let pos = worldPositionAtCell(row: row, col: col, rows: mapRows, cols: mapCols)
            let y = max(groundLevelY, -CGFloat(minB.y) + config.yOffset)
            let wallShift = applyAdaptiveWallShape(instance, row: row, col: col, wallCells: allWallCells)
            applyGhostColorRecursive(instance, color: ghostColor, transparency: 0.55)
            instance.position = SCNVector3(pos.x + wallShift.offsetX, y, pos.z + wallShift.offsetZ)
            instance.categoryBitMask = 0
            instance.childNodes.forEach { $0.categoryBitMask = 0 }
            node.addChildNode(instance)
        }
        guard sloped else {
            placementDebug("wall preview render result: connectorNodes=0 (inactive: line is straight)")
            return
        }
        let created = addWallDiagonalConnectors(
            to: node,
            wallCells: allWallCells,
            focusCells: previewSet,
            color: ghostColor,
            alpha: 0.55,
            templateForHeight: template,
            useWallTexture: true,
            stepsTemplate: templates[Steps.objectId],
            wallObjectIdPerCell: wallObjectIdPerCell.isEmpty ? nil : wallObjectIdPerCell,
            smallWallTemplate: templates[SmallWall.objectId],
            mapRows: mapRows,
            mapCols: mapCols
        )
        placementDebug("wall preview render result: connectorNodes=\(created)")
    }

    private func addFallbackBoxes(for p: Placement, to node: SCNNode, fallback: SCNNode, mapRows: Int, mapCols: Int) {
        let fallbackHeight: CGFloat = 8
        for r in p.row..<(p.row + p.height) {
            for c in p.col..<(p.col + p.width) {
                let pos = worldPositionAtCell(row: r, col: c, rows: mapRows, cols: mapCols)
                let n = fallback.clone()
                let y = max(groundLevelY, groundLevelY + fallbackHeight / 2)
                n.position = SCNVector3(pos.x, y, pos.z)
                n.isHidden = false
                n.categoryBitMask = 0
                node.addChildNode(n)
            }
        }
    }

    private func makePlacementBoxNode() -> SCNNode {
        let wallColor = NSColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 0.95)
        let box = SCNBox(width: worldUnitsPerCell, height: 8, length: worldUnitsPerCell, chamferRadius: 0)
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
        let dy = max(CGFloat(maxB.y - minB.y), 0.01)
        let scaleX = (cw * worldUnitsPerCell) / dx
        let scaleZ = (ch * worldUnitsPerCell) / dz
        let scaleY: CGFloat
        if WallParent.isWall(objectId: config.objectId) {
            // Zid (veliki/mali) je već u točnoj world skali, bez dodatnog scale-a.
            placementNode.scale = SCNVector3(1, 1, 1)
            if WallParent.isWall(objectId: config.objectId) {
                let finalHeight = dy
                placementDebug("template Wall source(dx=\(String(format: "%.3f", dx)),dy=\(String(format: "%.3f", dy)),dz=\(String(format: "%.3f", dz))) scale(x=1.000,y=1.000,z=1.000) finalHeight=\(String(format: "%.3f", finalHeight))")
            }
            let ghostNode = templateContainer.clone()
            duplicateMaterialsRecursive(ghostNode)
            ghostNode.name = "ghost_\(config.objectId)"
            ghostNode.isHidden = true
            ghostNode.categoryBitMask = 0
            ghostNode.childNodes.forEach { $0.categoryBitMask = 0 }
            applyTransparencyRecursive(0.6, to: ghostNode)
            return (templateContainer, ghostNode)
        } else {
            scaleY = min(scaleX, scaleZ)
        }
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
        var gridNode10: SCNNode?
        var gridNode40: SCNNode?
        var wallLinePreviewNode: SCNNode?
        fileprivate weak var mapViewContainer: SceneKitMapNSView?
        var mapRows: Int = 200
        var mapCols: Int = 200
        /// Template po objectId – za kloniranje pri refreshPlacements.
        var placementTemplates: [String: SCNNode] = [:]
        /// Ghost čvor po objectId – prikazuje se pri pomicanju miša kad je objekt odabran.
        var ghostNodes: [String: SCNNode] = [:]
        var lastGhostCellByObject: [String: (Int, Int)] = [:]
        var lastGridZoom: CGFloat = 1
        var lastTerrainHeightsChecksum: Double = 0
        var isTerrainEditMode: Bool = false
        var onTerrainEdit: ((Int, Int) -> Void)?
        var onTerrainAddBrushSelection: ((Int, Int) -> Void)?
        var onCellSelectionToggle: ((Int, Int) -> Void)?
        var terrainBrushOption: TerrainBrushOption?
        /// Map Editor – zelena površina na terenu za područje pod mišem (bez letećeg elementa).
        var brushPreviewOverlayNode: SCNNode?
        /// Map Editor – čvor s oznakama odabranih ćelija (jedna kocka po ćeliji).
        var cellSelectionOverlayNode: SCNNode?
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
            // Ne pozivaj updateGhostFromCurrentMouseLocation ovdje – renderer radi na pozadinskoj niti (renderingQueue),
            // a convertPoint/bounds moraju na main thread. Ghost i brush ažuriraju se u onMouseMove (mouseMoved/mouseEntered).
        }
    }

    /// Ghost box za objekte kad 3D model nije učitan (fallback u makeTemplateAndGhost).
    private func makeGhostFarmObjNode(cellW: Int, cellH: Int) -> SCNNode {
        let w = CGFloat(cellW) * worldUnitsPerCell
        let h = CGFloat(cellH) * worldUnitsPerCell
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
