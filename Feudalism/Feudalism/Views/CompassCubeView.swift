//
//  CompassCubeView.swift
//  Feudalism
//
//  Horizontalni kompas: strip N | E | S | W s vertikalnim linijama. Klik bilo gdje = mehanizam klizi.
//

import SwiftUI
import AppKit

private let cardinals = ["N", "E", "S", "W"]

/// Iz mapRotation (radijani) vraća indeks 0–3 (N=0, E=1, S=2, W=3).
private func cardinalIndex(from rotation: CGFloat) -> Int {
    let twoPi = 2 * CGFloat.pi
    var r = rotation
    while r < 0 { r += twoPi }
    while r >= twoPi { r -= twoPi }
    let idx = Int((r + .pi / 4) / (.pi / 2)) % 4
    return idx < 0 ? idx + 4 : idx
}

/// Kontinuirana pozicija 0..<5 za glatko klizanje u krug (0=N, 1=E, 2=S, 3=W, 4=N opet). Ne normaliziramo na 2π da W→N ostane na 4.
private func continuousPosition(from rotation: CGFloat) -> CGFloat {
    let twoPi = 2 * CGFloat.pi
    var r = rotation
    while r < 0 { r += twoPi }
    if r >= twoPi { r = twoPi }
    return r / (.pi / 2)
}

/// Točno 9 vertikalnih crtica između slova (oblik "|" – visoke, uske linije).
private struct NineDashes: View {
    private let count = 9
    private let dashWidth: CGFloat = 1.5
    private let gap: CGFloat = 1.2
    private let rowHeight: CGFloat = 32

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<count, id: \.self) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: dashWidth, height: rowHeight)
            }
        }
        .frame(width: nineDashesWidth, height: rowHeight)
    }
}

/// Širina bloka od točno 9 vertikalnih crtica.
private let nineDashesWidth: CGFloat = 9 * 1.5 + 8 * 1.2

/// Jedna ćelija: samo jedno slovo, točno u sredini zone 160×32.
private struct CompassLetterSlot: View {
    let letter: String

    var body: some View {
        ZStack {
            Text(letter)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: 160, height: 32)
    }
}

/// Širina jednog segmenta: zona slova (160) + 9 crtica.
private let letterZoneWidth: CGFloat = 160
private let segmentWidth: CGFloat = letterZoneWidth + nineDashesWidth

/// Kompas: N | 9 crtica | E | 9 crtica | S | 9 crtica | W | 9 crtica | N. 4 klika = 4 × 90° rotacije kamere.
struct CompassCubeView: View {
    @Binding var mapRotation: CGFloat
    @Binding var panOffset: CGPoint

    private let viewWidth: CGFloat = 160
    private let height: CGFloat = 32
    private let cornerRadius: CGFloat = 6
    private let twoPi = 2 * CGFloat.pi

    /// Pomak stripa: sredina prozora uvijek na sredini trenutnog slova.
    private var stripOffsetX: CGFloat {
        let pos = continuousPosition(from: mapRotation)
        let centerOfCurrentSlot = pos * segmentWidth + 80
        return 80 - centerOfCurrentSlot
    }

    var body: some View {
        Button {
            var start = mapRotation
            if start >= twoPi {
                mapRotation = 0
                start = 0
            }
            let target = start + .pi / 2
            let duration = 0.35
            let steps = 24
            let stepDuration = duration / Double(steps)
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let eased = t * t * (3 - 2 * t)
                let value = start + (target - start) * eased
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                    var v = value
                    while v < 0 { v += twoPi }
                    if v >= twoPi { v = twoPi }
                    mapRotation = v
                }
            }
        } label: {
            HStack(spacing: 0) {
                CompassLetterSlot(letter: "N")
                NineDashes()
                CompassLetterSlot(letter: "E")
                NineDashes()
                CompassLetterSlot(letter: "S")
                NineDashes()
                CompassLetterSlot(letter: "W")
                NineDashes()
                CompassLetterSlot(letter: "N")
            }
            .offset(x: stripOffsetX)
            .frame(width: viewWidth, height: height)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: viewWidth, height: height)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    CompassCubeView(
        mapRotation: .constant(0),
        panOffset: .constant(.zero)
    )
    .frame(width: 160, height: 32)
}
