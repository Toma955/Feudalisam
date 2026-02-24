//
//  BarIconCache.swift
//  Feudalism
//
//  Centralizirano učitavanje ikona donjeg bara s memorijskim cacheom – jedan izvor, manje duplikata i I/O.
//

import AppKit

/// Cache ikona za donji bar (asset ili bundle). Jedan singleton; svi viewovi koriste image(named:).
final class BarIconCache {
    static let shared = BarIconCache()

    private let lock = NSLock()
    private var cache: [String: NSImage] = [:]

    private static let subdirs = ["Icons", "icons", "Feudalism/Icons", "Feudalism/icons"]

    private init() {}

    /// Učita ikonu po imenu (bez ekstenzije). Prvo Assets.xcassets, pa Icons/icons u bundleu. Rezultat se cacheira.
    func image(named name: String, bundle: Bundle = .main) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[name] { return cached }
        let img = loadUncached(named: name, bundle: bundle)
        if let img = img { cache[name] = img }
        return img
    }

    private func loadUncached(named name: String, bundle: Bundle) -> NSImage? {
        if let img = NSImage(named: name) { return img }
        for sub in Self.subdirs {
            if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: sub),
               let img = NSImage(contentsOf: url) {
                return img
            }
        }
        return nil
    }
}
