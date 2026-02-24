//
//  FireBackgroundView.swift
//  Feudalism
//
//  Mutna pozadina s efektom gorućeg plamena (srednjovjekovni meni).
//

import SwiftUI

/// Pozadina s jakim efektom vatre, plamena i iskri – crvena, narančasta, žuta, roze, ljubičasta i modra u skladu s plamenom.
struct FireBackgroundView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                // Tamna baza s blagim ljubičasto‑modrim tonom
                Color(red: 0.08, green: 0.03, blue: 0.08)
                    .ignoresSafeArea()

                // Vanjski prsten – modro i ljubičasto na rubovima
                RadialGradient(
                    colors: [
                        Color(red: 0.15, green: 0.08, blue: 0.35).opacity(0.45),
                        Color(red: 0.22, green: 0.08, blue: 0.28).opacity(0.5),
                        Color(red: 0.12, green: 0.05, blue: 0.2).opacity(0.4),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 350,
                    endRadius: 750
                )
                .opacity(0.7 + 0.08 * sin(t * 1.2))
                .ignoresSafeArea()

                // Roze i ljubičasti ton uz rubove plamena (prijelaz prema vatri)
                RadialGradient(
                    colors: [
                        Color(red: 0.55, green: 0.2, blue: 0.45).opacity(0.35),
                        Color(red: 0.4, green: 0.15, blue: 0.35).opacity(0.25),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 200,
                    endRadius: 500
                )
                .opacity(0.65 + 0.1 * sin(t * 1.5))
                .ignoresSafeArea()

                // Jarka jezgra vatre – žuto‑narančasta u centru
                RadialGradient(
                    colors: [
                        Color(red: 0.98, green: 0.65, blue: 0.12),
                        Color(red: 0.92, green: 0.38, blue: 0.08),
                        Color(red: 0.75, green: 0.25, blue: 0.05),
                        Color(red: 0.45, green: 0.14, blue: 0.03),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 320
                )
                .opacity(0.95 + 0.12 * sin(t * 2.2))
                .ignoresSafeArea()

                // Širi žar – intenzivan crveno‑narančasti prsten
                RadialGradient(
                    colors: [
                        Color(red: 0.7, green: 0.28, blue: 0.06),
                        Color(red: 0.5, green: 0.18, blue: 0.04),
                        Color(red: 0.25, green: 0.08, blue: 0.02),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 600
                )
                .opacity(0.9 + 0.1 * sin(t * 1.6))
                .ignoresSafeArea()

                // Flicker / treperenje – hotspotovi s roze i toplim tonovima
                ForEach(0..<5, id: \.self) { i in
                    let offsetX = CGFloat(sin(t + Double(i) * 0.7) * 0.12)
                    let offsetY = CGFloat(cos(t * 1.1 + Double(i) * 0.5) * 0.1)
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.5, blue: 0.45).opacity(0.5),
                            Color(red: 0.75, green: 0.3, blue: 0.25).opacity(0.35),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5 + offsetX, y: 0.5 + offsetY),
                        startRadius: 0,
                        endRadius: 180
                    )
                    .ignoresSafeArea()
                }

                // Iskre – malo kaosa: počinaju lijevo i desno, uvijek prema gore
                ForEach(0..<12, id: \.self) { i in
                    let cycleDuration: Double = 5.2
                    let phase = (t + Double(i) * 0.5).truncatingRemainder(dividingBy: cycleDuration)
                    let birthCycle = floor((t + Double(i) * 0.5) / cycleDuration)
                    let flightDuration: Double = 4.2
                    let n = min(1, phase / flightDuration)
                    let progress = 2 * n - n * n
                    let startY = 0.65
                    let endY = 0.1
                    let startX = 0.5 + 0.38 * sin(birthCycle * 0.87 + Double(i) * 1.15)
                    let sway = 0.07 * sin(progress * Double.pi * 2.5 + Double(i) * 0.6)
                    let px = startX + sway
                    let py = startY - progress * (startY - endY)
                    let sparkOpacity: Double = {
                        if phase < 0.15 { return phase / 0.15 }
                        if phase < 3.6 { return 1.0 }
                        return max(0, (4.8 - phase) / 1.2)
                    }()
                    RadialGradient(
                        colors: [
                            Color(red: 1, green: 0.88, blue: 0.45).opacity(sparkOpacity),
                            Color(red: 1, green: 0.55, blue: 0.12).opacity(sparkOpacity * 0.5),
                            Color.clear
                        ],
                        center: UnitPoint(x: px, y: py),
                        startRadius: 0,
                        endRadius: 14
                    )
                    .opacity(sparkOpacity)
                    .ignoresSafeArea()
                }
            }
        }
    }
}

#Preview {
    FireBackgroundView()
        .frame(width: 400, height: 300)
}
