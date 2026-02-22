//
//  ZoomPhaseView.swift
//  Feudalism
//
//  Zoom u 4 faze: 1 stablo, 2 stabla, 3 stabla, šuma. Zelene ikone, crna pozadina. Klik = ping-pong (2→3→4→3→2→1→2→…).
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

/// Ikona: 1 = šuma (2.1), 2 = tri stabla (14), 3 = jedno stablo (29), 4 = list (38).
private struct ZoomPhaseIcon: View {
    let phase: Int
    private static let forestImage = loadForestIcon()

    var body: some View {
        Group {
            switch phase {
            case 1:
                // Šuma (2.1) – forest ikone jedna do druge, ne diraju se
                if let img = Self.forestImage {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 24)
                                .foregroundStyle(greenIcon)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "tree.fill").foregroundStyle(greenIcon)
                        Image(systemName: "tree.fill").foregroundStyle(pineGreen)
                        Image(systemName: "tree.fill").foregroundStyle(greenIcon)
                        Image(systemName: "tree.fill").foregroundStyle(pineGreen)
                        Image(systemName: "tree.fill").foregroundStyle(greenIcon)
                    }
                    .font(.system(size: 12))
                }
            case 2:
                // Zoom 14 – tri stabla jedna do druge
                HStack(spacing: 6) {
                    Image(systemName: "tree.fill")
                    Image(systemName: "tree.fill")
                    Image(systemName: "tree.fill")
                }
            case 3:
                // Zoom 29 – jedno stablo
                Image(systemName: "tree.fill")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                // Zoom 38 – list
                Image(systemName: "leaf.fill")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .font(.system(size: phase == 1 ? 12 : 14))
        .foregroundStyle(greenIcon)
    }
}

/// Gumb zooma: prikazuje trenutnu fazu (1 stablo / 2 / 3 / šuma). Klik = sljedeća faza (ping-pong).
struct ZoomPhaseView: View {
    @Binding var mapCameraSettings: MapCameraSettings

    private let viewWidth: CGFloat = 160
    private let height: CGFloat = 24
    private let cornerRadius: CGFloat = 6

    private var currentPhase: Int {
        min(4, max(1, mapCameraSettings.zoomPhase))
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
        .frame(width: 160, height: 24)
}
