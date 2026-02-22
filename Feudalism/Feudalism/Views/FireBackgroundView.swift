//
//  FireBackgroundView.swift
//  Feudalism
//
//  Mutna pozadina s efektom gorućeg plamena (srednjovjekovni meni).
//

import SwiftUI

/// Pozadina s prigušenim efektom vatre – nijanse crvene/narandžaste, tamna.
struct FireBackgroundView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                // Najtamniji sloj
                Color(red: 0.08, green: 0.04, blue: 0.02)
                    .ignoresSafeArea()

                // Središte vatre – jarka jezgra u centru ekrana
                RadialGradient(
                    colors: [
                        Color(red: 0.55, green: 0.22, blue: 0.06),
                        Color(red: 0.38, green: 0.14, blue: 0.04),
                        Color(red: 0.22, green: 0.08, blue: 0.02),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 280
                )
                .opacity(0.92 + 0.06 * sin(t * 2))
                .ignoresSafeArea()

                // Širi “žar” oko središta – mutni crveno‑narančasti
                RadialGradient(
                    colors: [
                        Color(red: 0.28, green: 0.10, blue: 0.04),
                        Color(red: 0.14, green: 0.05, blue: 0.02),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 120,
                    endRadius: 520
                )
                .opacity(0.85 + 0.08 * sin(t * 1.5))
                .ignoresSafeArea()

                // Donji “plamen” – linearni gradient
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(red: 0.25, green: 0.08, blue: 0.02).opacity(0.6),
                            Color(red: 0.4, green: 0.14, blue: 0.04).opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 400)
                    .opacity(0.9 + 0.08 * sin(t * 1.7))
                }
                .ignoresSafeArea()

                // Blagi “flicker” – mali radiali iz središta
                ForEach(0..<3, id: \.self) { i in
                    let offset = CGFloat(sin(t + Double(i) * 0.8) * 0.08)
                    RadialGradient(
                        colors: [
                            Color(red: 0.48, green: 0.20, blue: 0.06).opacity(0.3),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5 + offset, y: 0.5 + offset),
                        startRadius: 0,
                        endRadius: 140
                    )
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
