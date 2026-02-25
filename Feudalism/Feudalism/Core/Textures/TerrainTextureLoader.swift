//
//  TerrainTextureLoader.swift
//  Feudalism
//
//  Učitava teksture terena (voda, vegetacija, zemlja, planina) iz bundlea
//  za prikaz mape. Ako datoteka nedostaje, koristi se proceduralna ploča u boji.
//

import Foundation
import AppKit

private let terrainTextureSubdirs = [
    "Core/Textures/terrain",
    "Textures/terrain",
    nil as String?,
]

private let terrainTileSize = 64

/// Default boje po tipu terena (kad nema PNG u bundleu).
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

/// Učita sliku iz bundlea po imenu (bez ekstenzije).
private func loadTerrainImage(named name: String, bundle: Bundle) -> CGImage? {
    for sub in terrainTextureSubdirs {
        if let url = sub != nil
            ? bundle.url(forResource: name, withExtension: "png", subdirectory: sub)
            : bundle.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url),
           let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        if let url = sub != nil
            ? bundle.url(forResource: name, withExtension: "jpg", subdirectory: sub)
            : bundle.url(forResource: name, withExtension: "jpg"),
           let img = NSImage(contentsOf: url),
           let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
    }
    return nil
}

/// Učitava i kešira ploče tekstura po tipu terena. Ako datoteka ne postoji, koristi proceduralnu boju.
final class TerrainTextureLoader {
    static let shared = TerrainTextureLoader()

    private var cache: [TerrainType: CGImage] = [:]
    private let lock = NSLock()

    private init() {}

    /// Imena datoteka po tipu (bez ekstenzije).
    private static let fileNames: [TerrainType: String] = [
        .grass: "grass",
        .water: "water",
        .forest: "forest",
        .mountain: "mountain",
    ]

    /// Vraća CGImage ploču za zadani tip terena (učitana iz bundlea ili proceduralna).
    func tileImage(for terrain: TerrainType, bundle: Bundle = .main) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[terrain] { return cached }
        let name = Self.fileNames[terrain] ?? "grass"
        let cg = loadTerrainImage(named: name, bundle: bundle) ?? makeDefaultTileCGImage(for: terrain)
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
        lock.unlock()
    }
}
