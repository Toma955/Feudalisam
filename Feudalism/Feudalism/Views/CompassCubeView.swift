//
//  CompassCubeView.swift
//  Feudalism
//
//  Jedno slovo (N/E/S/W). Klik: rotacija kamere 90° + sljedeće slovo. 4 klika = 4 strane svijeta. Na početku S.
//

import SwiftUI
import AppKit
import QuartzCore

private let cardinals = ["N", "E", "S", "W"]

/// Ease-in-out: lagano krene, ubrza u sredini, elegantno uspori pri kraju (cubic).
private func easeInOutCubic(_ t: CGFloat) -> CGFloat {
    if t <= 0 { return 0 }
    if t >= 1 { return 1 }
    if t < 0.5 {
        return 4 * t * t * t
    }
    let u = -2 * t + 2
    return 1 - (u * u * u) / 2
}

/// Indeks 0–3 iz mapRotation (0=N, π/2=E, π=S, 3π/2=W).
private func cardinalIndex(from rotation: CGFloat) -> Int {
    let twoPi = 2 * CGFloat.pi
    var r = rotation
    while r < 0 { r += twoPi }
    if r >= twoPi { r = 0 }
    let idx = Int((r / (.pi / 2)).rounded(.down)) % 4
    return idx < 0 ? idx + 4 : idx
}

/// Kompas: jedno slovo upada u kadar, drugo ispada. Klik → odmah animacija + rotacija 90°.
struct CompassCubeView: View {
    @Binding var mapRotation: CGFloat
    @Binding var panOffset: CGPoint
    @StateObject private var displayState = CompassDisplayState()

    private let viewWidth: CGFloat = 160
    private let height: CGFloat = 24
    private let cornerRadius: CGFloat = 6
    private let twoPi = 2 * CGFloat.pi
    private let animDuration: Double = 0.3

    private var currentLetter: String {
        if let overrideIdx = displayState.overrideIndex {
            return cardinals[overrideIdx]
        }
        return cardinals[cardinalIndex(from: mapRotation)]
    }

    var body: some View {
        Button {
            let currentIdx = cardinalIndex(from: mapRotation)
            let nextIdx = (currentIdx + 1) % 4
            withAnimation(.easeInOut(duration: animDuration)) {
                displayState.overrideIndex = nextIdx
            }
            var start = mapRotation
            if start >= twoPi { start = 0 }
            let target = start + .pi / 2
            let duration: TimeInterval = 0.35
            let startTime = CACurrentMediaTime()
            let state = displayState
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { t in
                let elapsed = CACurrentMediaTime() - startTime
                let ti = min(1.0, CGFloat(elapsed / duration))
                let eased = easeInOutCubic(ti)
                var v = start + (target - start) * eased
                while v < 0 { v += twoPi }
                if v >= twoPi { v = 0 }
                mapRotation = v
                if ti >= 1.0 {
                    t.invalidate()
                    DispatchQueue.main.async { state.overrideIndex = nil }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
        } label: {
            Text(currentLetter)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: viewWidth, height: height)
                .id(currentLetter)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .frame(width: viewWidth, height: height)
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: animDuration), value: currentLetter)
        }
        .buttonStyle(.plain)
        .frame(width: viewWidth, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Override indeks da se slovo promijeni odmah pri kliku (animacija ulaz/izlaz preko .id(currentLetter)).
private final class CompassDisplayState: ObservableObject {
    @Published var overrideIndex: Int?
}

#Preview {
    CompassCubeView(
        mapRotation: .constant(.pi),
        panOffset: .constant(.zero)
    )
    .frame(width: 160, height: 24)
}
