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
    @State private var showTextureStatusAlert = false
    @State private var textureStatusMessage = ""

    var body: some View {
        MapScreenLayout(
            topBar: { editorToolbar },
            content: {
                SceneKitMapView(
                    showGrid: showGrid,
                    handPanMode: $handPanMode,
                    isEraseMode: eraseMode,
                    onRemoveAt: eraseMode ? { gameState.removePlacement(at: MapCoordinate(row: $0, col: $1)) } : nil
                )
                .ignoresSafeArea()
            },
            loadingMessage: gameState.isLevelReady ? nil : "Učitavanje mape…",
            customOverlay: {
                ZStack(alignment: .bottomLeading) {
                    if let status = gameState.wallTextureStatus {
                        Text(status)
                            .font(.caption.monospaced())
                            .padding(8)
                            .background(.black.opacity(0.7))
                            .foregroundStyle(status.contains("Uspješno") || status.hasSuffix("OK") ? .green : .orange)
                            .cornerRadius(6)
                            .padding(12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        )
        .onAppear {
            let (ok, message) = Wall.checkAndLogTextureStatus(bundle: .main)
            let status = ok ? "Tekstura zida je uspješno učitana i primijenjena." : "Tekstura zida nije učitana: \(message)"
            gameState.wallTextureStatus = ok ? "Tekstura zida: OK" : "Tekstura zida: \(message)"
            textureStatusMessage = status
            showTextureStatusAlert = true
        }
        .alert("Status teksture zida", isPresented: $showTextureStatusAlert) {
            Button("OK") { showTextureStatusAlert = false }
        } message: {
            Text(textureStatusMessage)
        }
        .alert("Map Editor", isPresented: $showSaveLoadAlert) {
            Button("OK") { showSaveLoadAlert = false }
        } message: {
            if let msg = saveLoadMessage { Text(msg) }
        }
    }

    private var editorToolbar: some View {
        MapScreenHUDBar {
            // Isti kompas i zoom kao u solo modu (kamera)
            CompassCubeView(
                mapRotation: Binding(
                    get: { gameState.mapCameraSettings.mapRotation },
                    set: { new in
                        var s = gameState.mapCameraSettings
                        s.mapRotation = new
                        gameState.mapCameraSettings = s
                    }
                ),
                panOffset: Binding(
                    get: { gameState.mapCameraSettings.panOffset },
                    set: { new in
                        var s = gameState.mapCameraSettings
                        s.panOffset = new
                        gameState.mapCameraSettings = s
                    }
                )
            )
            ZoomPhaseView(mapCameraSettings: Binding(
                get: { gameState.mapCameraSettings },
                set: { gameState.mapCameraSettings = $0 }
            ))

            HUDBarDivider()

            Button {
                gameState.closeMapEditor()
            } label: {
                Label("Nazad", systemImage: "chevron.backward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .buttonStyle(.plain)

            HUDBarDivider()

            Text("Objekt:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))

            Button {
                eraseMode = false
                gameState.selectedPlacementObjectId = Wall.objectId
            } label: {
                Text("Zid")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(gameState.selectedPlacementObjectId == Wall.objectId && !eraseMode ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button {
                eraseMode.toggle()
                if eraseMode { gameState.selectedPlacementObjectId = nil }
            } label: {
                Label("Briši", systemImage: "eraser.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(eraseMode ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.plain)

            HUDBarDivider()

            Button {
                gameState.clearEditorMap()
            } label: {
                Label("Očisti mapu", systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button {
                if gameState.saveEditorMap() {
                    saveLoadMessage = "Mapa spremljena."
                } else {
                    saveLoadMessage = "Spremanje nije uspjelo."
                }
                showSaveLoadAlert = true
            } label: {
                Label("Spremi", systemImage: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button {
                if gameState.loadEditorMap() {
                    saveLoadMessage = "Mapa učitana."
                } else {
                    saveLoadMessage = "Učitavanje nije uspjelo (nema datoteke ili format)."
                }
                showSaveLoadAlert = true
            } label: {
                Label("Učitaj", systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            HUDBarDivider()

            Toggle(isOn: $showGrid) {
                Text("Ćelije")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .toggleStyle(.switch)
            .scaleEffect(0.82)
        }
    }
}

#Preview {
    MapEditorView()
        .environmentObject(GameState())
        .frame(width: 1200, height: 800)
}
