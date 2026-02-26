//
//  MapEditorView.swift
//  Feudalism
//
//  Map Editor – uređivanje mape: postavljanje zidova, brisanje, spremanje/učitavanje.
//

import SwiftUI
import AppKit

// MARK: - Donji mini izbornik (kategorije)
private enum MapEditorBottomCategory: String, CaseIterable, Identifiable {
    case građevine = "Građevine"
    case biljke = "Biljke"
    case životinje = "Životinje"
    case trava = "Trava"
    case teren = "Teren"
    case vode = "Vode"
    case evakuacija = "Evakuacija"

    var id: String { rawValue }
    var label: String { rawValue }
    var systemImage: String {
        switch self {
        case .građevine: return "building.2.fill"
        case .biljke: return "leaf.fill"
        case .životinje: return "pawprint.fill"
        case .trava: return "crop"
        case .teren: return "map.fill"
        case .vode: return "drop.fill"
        case .evakuacija: return "figure.run"
        }
    }
}

private let editorBottomBarButtonSize: CGFloat = 44
private let editorBottomBarSpacing: CGFloat = 12

struct MapEditorView: View {
    @EnvironmentObject private var gameState: GameState
    @State private var gridShow10 = true
    @State private var gridShow40 = false
    @State private var showGridDots = false
    @State private var handPanMode = false
    @State private var eraseMode = false
    @State private var saveLoadMessage: String?
    @State private var showSaveLoadAlert = false
    @State private var selectedEditorCategory: MapEditorBottomCategory = .građevine
    @State private var terrainToolOption: TerrainToolOption = .raise5
    @State private var terrainBrushOption: TerrainBrushOption = .kockaSrednja

    var body: some View {
        MapScreenLayout(
            topBar: { editorToolbar },
            content: {
                SceneKitMapView(
                    showGrid: true,
                    gridShow10: gridShow10,
                    gridShow40: gridShow40,
                    showGridDots: showGridDots,
                    handPanMode: $handPanMode,
                    isEraseMode: eraseMode,
                    onRemoveAt: eraseMode ? { gameState.removePlacement(at: MapCoordinate(row: $0, col: $1)) } : nil,
                    isTerrainEditMode: selectedEditorCategory == .teren,
                    terrainTool: selectedEditorCategory == .teren ? terrainToolOption : nil,
                    terrainBrushOption: selectedEditorCategory == .teren ? terrainBrushOption : nil,
                    onTerrainEdit: { r, c in
                        gameState.applyTerrainElevation(centerRow: r, centerCol: c, tool: terrainToolOption, brushOption: terrainBrushOption)
                    }
                )
                .ignoresSafeArea()
            },
            loadingMessage: gameState.isLevelReady ? nil : (gameState.levelLoadingMessage ?? "Učitavanje mape…"),
            customOverlay: {
                ZStack(alignment: .bottom) {
                    // Status teksture samo kad nije u redu (greška); kad je OK – ništa ne prikazujemo
                    ZStack(alignment: .bottomLeading) {
                        if let status = gameState.wallTextureStatus, status != "OK" {
                            Text(status)
                                .font(.caption.monospaced())
                                .padding(8)
                                .background(.black.opacity(0.7))
                                .foregroundStyle(.orange)
                                .cornerRadius(6)
                                .padding(12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    // Opcije alata za teren (kad je Teren odabran): Podigni za 5/10, Izravnaj
                    if selectedEditorCategory == .teren {
                        terrainToolPanel
                            .padding(.bottom, 80)
                    }

                    // Donji mini izbornik: sivi okrugli gumbi s ikonama
                    editorBottomBar
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        )
        .onAppear {
            let (ok, message) = HugeWall.checkAndLogTextureStatus(bundle: .main)
            gameState.wallTextureStatus = ok ? "OK" : message
        }
        .alert("Map Editor", isPresented: $showSaveLoadAlert) {
            Button("OK") { showSaveLoadAlert = false }
        } message: {
            if let msg = saveLoadMessage { Text(msg) }
        }
    }

    /// Panel opcija za teren: Podigni za 5, Podigni za 10, Izravnaj.
    private var terrainToolPanel: some View {
        HStack(spacing: 10) {
            ForEach(TerrainToolOption.allCases, id: \.rawValue) { option in
                Button {
                    terrainToolOption = option
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(terrainToolOption == option ? .yellow : .white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(terrainToolOption == option ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    /// Donji mini izbornik: sivi okrugli gumbi s ikonama (Građevine, Biljke, Životinje, Trava, Teren, Vode, Evakuacija).
    private var editorBottomBar: some View {
        HStack(spacing: editorBottomBarSpacing) {
            ForEach(MapEditorBottomCategory.allCases) { category in
                Button {
                    selectedEditorCategory = category
                } label: {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(selectedEditorCategory == category ? .white : .white.opacity(0.85))
                        .frame(width: editorBottomBarButtonSize, height: editorBottomBarButtonSize)
                        .background(selectedEditorCategory == category ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(selectedEditorCategory == category ? Color.white.opacity(0.6) : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .help(category.label)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
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

            if selectedEditorCategory == .teren {
                // 3 kocke (mala, srednja, velika) + 3 kruga (mali, srednji, veliki) – samo jedan izabran; ghost na mapi prikazuje oblik
                HStack(spacing: 10) {
                    ForEach([TerrainBrushOption.kockaMala, .kockaSrednja, .kockaVelika], id: \.rawValue) { option in
                        Button {
                            terrainBrushOption = option
                        } label: {
                            Image(systemName: "square.fill")
                                .font(.system(size: option == .kockaMala ? 14 : (option == .kockaSrednja ? 18 : 22)))
                                .foregroundStyle(terrainBrushOption == option ? .yellow : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach([TerrainBrushOption.krugMali, .krugSrednji, .krugVeliki], id: \.rawValue) { option in
                        Button {
                            terrainBrushOption = option
                        } label: {
                            Image(systemName: "circle.fill")
                                .font(.system(size: option == .krugMali ? 14 : (option == .krugSrednji ? 18 : 22)))
                                .foregroundStyle(terrainBrushOption == option ? .yellow : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                HUDBarDivider()
            }

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
                let result = gameState.saveEditorMap()
                if result.success {
                    saveLoadMessage = "Mapa spremljena."
                } else {
                    saveLoadMessage = result.errorMessage ?? "Spremanje nije uspjelo."
                }
                showSaveLoadAlert = true
            } label: {
                Label("Spremi", systemImage: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button {
                if gameState.loadEditorMap(fromSlot: .solo) {
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

            Text("Mreža:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))

            Button {
                gridShow10.toggle()
            } label: {
                Text("10×10")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(gridShow10 ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button {
                gridShow40.toggle()
            } label: {
                Text("40×40")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(gridShow40 ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button {
                showGridDots.toggle()
            } label: {
                Text("Kugle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(showGridDots ? .yellow : .white.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    MapEditorView()
        .environmentObject(GameState())
        .frame(width: 1200, height: 800)
}
