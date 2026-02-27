//
//  TerrainTextureLoader.swift
//  Feudalism
//
//  Sve teksture terena u jednom mjestu: Core/Objects/Textures (ground, side, terrain).
//  Isti princip kao Wall: Build phases "Copy ground texture" i "Copy Side texture" kopiraju u bundle.
//

import Foundation
import AppKit

/// Iste putanje kao Wall (ParentWall.loadWallTextureSet): više subdirs da bundle nađe resurse.
private let groundSubdirs: [String?] = [
    "Core/Objects/Textures/ground",
    "Objects/Textures/ground",
    "Textures/ground",
    "Feudalism/Core/Objects/Textures/ground",
    nil,
]
/// Iste putanje kao ground (da bundle nađe side kao ground).
private let sideSubdirs: [String?] = [
    "Core/Objects/Textures/side",
    "Core/Objects/Textures/Side",
    "Objects/Textures/side",
    "Textures/side",
    "Feudalism/Core/Objects/Textures/side",
    "Feudalism/Core/Objects/Textures/Side",
    nil,
]
private let terrainSubdirsOther: [String?] = ["Core/Objects/Textures/terrain", "Core/Objects/Textures/ground", "Objects/Textures/terrain", nil]

private let terrainTileSize = 64

/// Kao ParentWall.textureURL: traži resource u bundleu (png pa jpg).
private func textureURL(bundle: Bundle, name: String, subdirs: [String?]) -> URL? {
    for sub in subdirs {
        if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: sub) { return url }
        if let url = bundle.url(forResource: name, withExtension: "jpg", subdirectory: sub) { return url }
    }
    return nil
}

private func loadTerrainImage(named name: String, bundle: Bundle, subdirs: [String?]) -> CGImage? {
    guard let url = textureURL(bundle: bundle, name: name, subdirs: subdirs),
          let img = NSImage(contentsOf: url) else { return nil }
    return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

/// Default boje po tipu terena (kad nema slike u bundleu).
private func defaultColor(for terrain: TerrainType) -> (CGFloat, CGFloat, CGFloat) {
    switch terrain {
    case .grass: return (0.45, 0.68, 0.32)
    case .water: return (0.25, 0.45, 0.75)
    case .forest: return (0.22, 0.42, 0.22)
    case .mountain: return (0.50, 0.48, 0.45)
    }
}

/// Generira 64×64 CGImage u jednoj boji (tilable).
private func makeDefaultTileCGImage(for terrain: TerrainType) -> CGImage? {
    let w = terrainTileSize
    let h = terrainTileSize
    let c = defaultColor(for: terrain)
    guard let ctx = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()
}

/// Učitava i kešira ploče tekstura po tipu terena. Ako datoteka ne postoji, koristi proceduralnu boju.
final class TerrainTextureLoader {
    static let shared = TerrainTextureLoader()

    private var cache: [TerrainType: CGImage] = [:]
    private let lock = NSLock()

    private init() {}

    /// Za .grass: samo ground_Color (jpg). ground.png je samo za web, ne uključujemo ga.
    private static let grassCandidates = ["ground_Color", "ground_texture"]
    private static let fileNames: [TerrainType: String] = [
        .grass: "ground",
        .water: "water",
        .forest: "forest",
        .mountain: "mountain",
    ]

    /// Vraća CGImage ploču za zadani tip terena (učitana iz bundlea ili proceduralna).
    func tileImage(for terrain: TerrainType, bundle: Bundle = .main) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[terrain] { return cached }
        var cg: CGImage?
        if terrain == .grass {
            for name in Self.grassCandidates {
                cg = loadTerrainImage(named: name, bundle: bundle, subdirs: groundSubdirs)
                if cg != nil { break }
            }
        } else {
            let name = Self.fileNames[terrain] ?? "grass"
            cg = loadTerrainImage(named: name, bundle: bundle, subdirs: terrainSubdirsOther)
        }
        cg = cg ?? makeDefaultTileCGImage(for: terrain)
        if let cg = cg { cache[terrain] = cg }
        return cg
    }

    /// Sve ploče za crtanje terena (key = TerrainType).
    func tileImages(bundle: Bundle = .main) -> [TerrainType: CGImage] {
        var out: [TerrainType: CGImage] = [:]
        for t in TerrainType.allCases {
            if let cg = tileImage(for: t, bundle: bundle) { out[t] = cg }
        }
        return out
    }

    /// Očisti keš (npr. nakon promjene jezika ili asseta).
    func clearCache() {
        lock.lock()
        cache.removeAll()
        sideTextureCache = nil
        groundNormalCache = nil
        groundRoughnessCache = nil
        lock.unlock()
    }

    // MARK: - PBR za gornju plohu terena (3D osjećaj kao Wall)

    private var groundNormalCache: CGImage?
    private var groundRoughnessCache: CGImage?

    /// Normal mapa za ground – ground_NormalGL.jpg (OpenGL konvencija, kao Wall).
    func groundNormalImage(bundle: Bundle = .main) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = groundNormalCache { return cached }
        let cg = loadTerrainImage(named: "ground_NormalGL", bundle: bundle, subdirs: groundSubdirs)
        if let cg = cg { groundNormalCache = cg }
        return cg
    }

    /// Roughness za ground – ground_Roughness.jpg.
    func groundRoughnessImage(bundle: Bundle = .main) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = groundRoughnessCache { return cached }
        let cg = loadTerrainImage(named: "ground_Roughness", bundle: bundle, subdirs: groundSubdirs)
        if let cg = cg { groundRoughnessCache = cg }
        return cg
    }

    // MARK: - Bočne strane terena (elevacija)

    private var sideTextureCache: CGImage?

    /// Bočne strane terena – isto kao ground: prvo side_Color (jpg), pa side (png).
    private static let sideCandidates = ["side_Color", "side", "side_texture"]

    func sideTextureImage(bundle: Bundle = .main) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = sideTextureCache { return cached }
        for name in Self.sideCandidates {
            if let cg = loadTerrainImage(named: name, bundle: bundle, subdirs: sideSubdirs) {
                sideTextureCache = cg
                return cg
            }
        }
        return nil
    }
}
