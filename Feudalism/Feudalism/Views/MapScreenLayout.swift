//
//  MapScreenLayout.swift
//  Feudalism
//
//  Zajednički layout za ekran s mapom (DRY): tamna pozadina, traka gore, sadržaj, opcionalni loading overlay.
//  Koriste ga ContentView (igra) i MapEditorView (Map Editor).
//

import SwiftUI

// MARK: - Zajednička HUD traka (isti izgled za igru i Map Editor)

/// Ista traka gore za solo i Map Editor: širina taman da sve stane (bez rastezanja), visina 52.
struct MapScreenHUDBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    content()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 0)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minHeight: 52, maxHeight: 52)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

/// Vertikalni razdjelnik u HUD traci (1×28, bijela 0.2).
struct HUDBarDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(width: 1, height: 28)
    }
}

/// Prekriva ekran dok se level učitava – jedan objekt za igru i Map Editor.
struct LevelLoadingOverlay: View {
    var message: String = "Učitavanje…"

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.white)
                Text(message)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(.top, 80)
        }
        .allowsHitTesting(true)
    }
}

/// Temeljni layout za ekran s mapom: tamna pozadina, top bar, sadržaj, opcionalni loading i overlay.
struct MapScreenLayout<TopBar: View, Content: View, CustomOverlay: View>: View {
    @ViewBuilder let topBar: () -> TopBar
    @ViewBuilder let content: () -> Content
    /// Ako nije nil, prikaže se LevelLoadingOverlay s ovom porukom.
    var loadingMessage: String?
    @ViewBuilder let customOverlay: () -> CustomOverlay

    init(
        @ViewBuilder topBar: @escaping () -> TopBar,
        @ViewBuilder content: @escaping () -> Content,
        loadingMessage: String? = nil,
        @ViewBuilder customOverlay: @escaping () -> CustomOverlay
    ) {
        self.topBar = topBar
        self.content = content
        self.loadingMessage = loadingMessage
        self.customOverlay = customOverlay
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content()

            VStack(spacing: 0) {
                topBar()
                Spacer(minLength: 0)
            }
        }
        .overlay {
            if let message = loadingMessage {
                LevelLoadingOverlay(message: message)
            }
        }
        .overlay {
            customOverlay()
        }
    }
}

extension MapScreenLayout where CustomOverlay == EmptyView {
    init(
        @ViewBuilder topBar: @escaping () -> TopBar,
        @ViewBuilder content: @escaping () -> Content,
        loadingMessage: String? = nil
    ) {
        self.topBar = topBar
        self.content = content
        self.loadingMessage = loadingMessage
        self.customOverlay = { EmptyView() }
    }
}

#Preview("Loading overlay") {
    LevelLoadingOverlay(message: "Učitavanje levela…")
        .frame(width: 400, height: 300)
}
