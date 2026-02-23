//
//  ZoomPhaseView.swift
//  Feudalism
//
//  Zoom u 3 faze: max zoom out 3 šume (2×), tri stabla (8×), jedno stablo (14×). Sužen element.
//

import SwiftUI
import AppKit

private let greenIcon = Color.green
/// Tamnija zelena za „bor” u šumi (sve ikone tree.fill da uvijek rade).
private let pineGreen = Color(red: 0.15, green: 0.5, blue: 0.2)

/// Učita forest ikonu iz Icons mape ili Assets (isto kao loadBarIcon u ContentView).
private func loadForestIcon() -> NSImage? {
    if let img = NSImage(named: "forest") { return img }
    let subdirs = ["Icons", "icons", "Feudalism/Icons", "Feudalism/icons"]
    for sub in subdirs {
        if let url = Bundle.main.url(forResource: "forest", withExtension: "png", subdirectory: sub) {
            return NSImage(contentsOf: url)
        }
    }
    return nil
}

/// Ikona: 1 = 3 šume (2× max zoom out), 2 = tri stabla (8×), 3 = jedno stablo (14×).
private struct ZoomPhaseIcon: View {
    let phase: Int
    private static let forestImage = loadForestIcon()

    var body: some View {
        Group {
            switch phase {
            case 1:
                // Max zoom out (2×) – 3 šume jedna do druge
                if let img = Self.forestImage {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 20)
                                .foregroundStyle(greenIcon)
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "tree.fill").foregroundStyle(greenIcon)
                        Image(systemName: "tree.fill").foregroundStyle(pineGreen)
                        Image(systemName: "tree.fill").foregroundStyle(greenIcon)
                    }
                    .font(.system(size: 10))
                }
            case 2:
                // Srednji zoom (8×) – tri stabla
                HStack(spacing: 4) {
                    Image(systemName: "tree.fill")
                    Image(systemName: "tree.fill")
                    Image(systemName: "tree.fill")
                }
                .font(.system(size: 12))
            default:
                // Max zoom (14×) – jedno stablo
                Image(systemName: "tree.fill")
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(greenIcon)
    }
}

/// Gumb zooma: prikazuje trenutnu fazu (3 šume / 3 stabla / 1 stablo). Klik = sljedeća faza. Sužen element.
struct ZoomPhaseView: View {
    @Binding var mapCameraSettings: MapCameraSettings

    private let viewWidth: CGFloat = 120
    private let height: CGFloat = 28
    private let cornerRadius: CGFloat = 10

    private var currentPhase: Int {
        min(3, max(1, mapCameraSettings.zoomPhase))
    }

    var body: some View {
        Button {
            var s = mapCameraSettings
            s.stepZoomPhaseByClick()
            mapCameraSettings = s
        } label: {
            ZoomPhaseIcon(phase: currentPhase)
                .id(currentPhase)
                .frame(width: viewWidth, height: height)
                .contentShape(Rectangle())
                .opacity(1)
                .scaleEffect(1)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.35)).combined(with: .scale(scale: 0.7)),
                    removal: .opacity.animation(.easeIn(duration: 0.2)).combined(with: .scale(scale: 0.85))
                ))
        }
        .animation(.easeOut(duration: 0.35), value: currentPhase)
        .buttonStyle(.plain)
        .frame(width: viewWidth, height: height)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    ZoomPhaseView(mapCameraSettings: .constant(MapCameraSettings()))
        .frame(width: 120, height: 28)
}
