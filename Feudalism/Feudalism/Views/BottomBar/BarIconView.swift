//
//  BarIconView.swift
//  Feudalism
//
//  Zajednička ikona za donji bar: asset ili SF Symbol fallback.
//

import SwiftUI
import AppKit

/// Učita NSImage za ikonu donjeg bara: prvo Assets.xcassets, pa Icons/icons u bundleu.
func loadBarIcon(named name: String) -> NSImage? {
    if let img = NSImage(named: name) { return img }
    let subdirs = ["Icons", "icons", "Feudalism/Icons", "Feudalism/icons"]
    for sub in subdirs {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: sub) {
            return NSImage(contentsOf: url)
        }
    }
    return nil
}

/// Ikona za donji bar: asset (castle, wall, sword, …) ili SF Symbol.
struct BarIconView: View {
    let assetName: String
    let systemName: String
    /// Veličina ikone u pt; zadano 48.
    var size: CGFloat = 48
    private var image: NSImage? { loadBarIcon(named: assetName) }

    var body: some View {
        Group {
            if let nsImage = image {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.58))
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(.white.opacity(0.95))
    }
}
