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

/// Kompas: jedno slovo u sredini. Klik → +90° rotacija + promjena slova. Početno S.
struct CompassCubeView: View {
    @Binding var mapRotation: CGFloat
    @Binding var panOffset: CGPoint

    private let viewWidth: CGFloat = 160
    private let height: CGFloat = 24
    private let cornerRadius: CGFloat = 6
    private let twoPi = 2 * CGFloat.pi

    private var currentLetter: String {
        cardinals[cardinalIndex(from: mapRotation)]
    }

    var body: some View {
        Button {
            var start = mapRotation
            if start >= twoPi { start = 0 }
            let target = start + .pi / 2
            let duration: TimeInterval = 0.35
            let startTime = CACurrentMediaTime()
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { timer in
                let elapsed = CACurrentMediaTime() - startTime
                let t = min(1.0, CGFloat(elapsed / duration))
                let eased = easeInOutCubic(t)
                var v = start + (target - start) * eased
                while v < 0 { v += twoPi }
                if v >= twoPi { v = 0 }
                mapRotation = v
                if t >= 1.0 {
                    timer.invalidate()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
        } label: {
            Text(currentLetter)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: viewWidth, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: viewWidth, height: height)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    CompassCubeView(
        mapRotation: .constant(.pi),
        panOffset: .constant(.zero)
    )
    .frame(width: 160, height: 24)
}
