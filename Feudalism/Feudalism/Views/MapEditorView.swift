//
//  MapEditorView.swift
//  Feudalism
//
//  Map Editor – uređivanje mape: postavljanje zidova, brisanje, spremanje/učitavanje.
//

import SwiftUI
import AppKit

struct MapEditorView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var showGrid = true
    @State private var handPanMode = false
    @State private var eraseMode = false
    @State private var saveLoadMessage: String?
    @State private var showSaveLoadAlert = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            SceneKitMapView(
                showGrid: showGrid,
                handPanMode: $handPanMode,
                isEraseMode: eraseMode,
                onRemoveAt: eraseMode ? { gameState.removePlacement(at: MapCoordinate(row: $0, col: $1)) } : nil
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                editorToolbar
                Spacer()
            }
        }
        .overlay {
            if !gameState.isLevelReady {
                levelLoadingOverlay
            }
        }
        .alert("Map Editor", isPresented: $showSaveLoadAlert) {
            Button("OK") { showSaveLoadAlert = false }
        } message: {
            if let msg = saveLoadMessage { Text(msg) }
        }
    }

    private var levelLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.4).tint(.white)
                Text("Učitavanje mape…")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
            }
        }
        .allowsHitTesting(true)
    }

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            Button {
                gameState.closeMapEditor()
            } label: {
                Label("Nazad", systemImage: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.9))

            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: 24)

            Text("Objekt:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            Button {
                eraseMode = false
                gameState.selectedPlacementObjectId = Wall.objectId
            } label: {
                Text("Zid")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(gameState.selectedPlacementObjectId == Wall.objectId && !eraseMode ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.2))

            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: 24)

            Button {
                eraseMode.toggle()
                if eraseMode { gameState.selectedPlacementObjectId = nil }
            } label: {
                Label("Briši", systemImage: "eraser.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(eraseMode ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.bordered)
            .tint(eraseMode ? .yellow.opacity(0.2) : .white.opacity(0.2))

            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: 24)

            Button {
                gameState.clearEditorMap()
            } label: {
                Label("Očisti mapu", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.2))
            .foregroundStyle(.white.opacity(0.9))

            Button {
                if gameState.saveEditorMap() {
                    saveLoadMessage = "Mapa spremljena."
                } else {
                    saveLoadMessage = "Spremanje nije uspjelo."
                }
                showSaveLoadAlert = true
            } label: {
                Label("Spremi", systemImage: "square.and.arrow.down")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.2))
            .foregroundStyle(.white.opacity(0.9))

            Button {
                if gameState.loadEditorMap() {
                    saveLoadMessage = "Mapa učitana."
                } else {
                    saveLoadMessage = "Učitavanje nije uspjelo (nema datoteke ili format)."
                }
                showSaveLoadAlert = true
            } label: {
                Label("Učitaj", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.2))
            .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 0)

            Toggle(isOn: $showGrid) {
                Text("Ćelije")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .toggleStyle(.switch)
            .scaleEffect(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
}

#Preview {
    MapEditorView()
        .environmentObject(GameState())
        .frame(width: 1200, height: 800)
}
