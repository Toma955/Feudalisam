//
//  MapEditorChoiceView.swift
//  Feudalism
//
//  Prvi ekran Map Editora: Učitaj mapu (Solo, Dual, … 6) ili Create map (odabir dimenzija).
//

import SwiftUI

private let choiceTileWidth: CGFloat = 200
private let choiceTileHeight: CGFloat = 52
private let sectionSpacing: CGFloat = 28
private let choiceTransitionDuration: Double = 0.22

struct MapEditorChoiceView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var isPresented: Bool

    @State private var showDimensionPicker = false
    @State private var selectedPresetForCreate: MapSizePreset?
    @State private var showCreateNameStep = false
    @State private var createMapName = ""
    @State private var loadErrorSlot: MapEditorSlot?
    @State private var loadErrorMessage: String?
    /// Kad je postavljen, prikaži listu mapa za taj slot da korisnik odabere koju učitati.
    @State private var mapPickerSlot: MapEditorSlot?

    var body: some View {
        Group {
            if showCreateNameStep, let preset = selectedPresetForCreate {
                createNameContent(preset: preset)
            } else if let slot = mapPickerSlot {
                mapPickerContent(slot: slot)
            } else if showDimensionPicker {
                dimensionPickerContent
            } else {
                mainChoiceContent
            }
        }
        .animation(.easeInOut(duration: choiceTransitionDuration), value: showDimensionPicker)
        .animation(.easeInOut(duration: choiceTransitionDuration), value: showCreateNameStep)
        .animation(.easeInOut(duration: choiceTransitionDuration), value: mapPickerSlot != nil)
        .onAppear {
            MapStorage.createSizeFoldersIfNeeded()
        }
        .alert("Učitavanje mape", isPresented: Binding(
            get: { loadErrorSlot != nil },
            set: { if !$0 { loadErrorSlot = nil; loadErrorMessage = nil } }
        )) {
            Button("OK") {
                loadErrorSlot = nil
                loadErrorMessage = nil
            }
        } message: {
            if let msg = loadErrorMessage { Text(msg) }
        }
    }

    private var mainChoiceContent: some View {
        VStack(spacing: 32) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: choiceTransitionDuration)) {
                        isPresented = false
                    }
                } label: {
                    Label("Nazad", systemImage: "chevron.backward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text("Map Editor")
                    .font(.custom("Georgia", size: 22))
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.98))
                Spacer(minLength: 0)
                Color.clear.frame(width: 80, height: 24)
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 16) {
                Text("Učitaj mapu")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: 12) {
                    ForEach(MapEditorSlot.allCases) { slot in
                        let hasSave = gameState.hasEditorMap(inSlot: slot)
                        let entries = MapCatalog.entries(forSlot: slot)
                        Button {
                            if !hasSave || entries.isEmpty {
                                loadErrorMessage = "Nema spremljene mape za \(slot.displayName)."
                                loadErrorSlot = slot
                            } else if entries.count == 1, let entry = entries.first {
                                if gameState.loadEditorMap(entry: entry) {
                                    gameState.openMapEditorAfterLoad()
                                    isPresented = false
                                } else {
                                    loadErrorMessage = "Učitavanje mape nije uspjelo."
                                    loadErrorSlot = slot
                                }
                            } else {
                                withAnimation(.easeInOut(duration: choiceTransitionDuration)) {
                                    mapPickerSlot = slot
                                }
                            }
                        } label: {
                            Text(slot.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(hasSave ? .white.opacity(0.95) : .white.opacity(0.5))
                                .frame(width: choiceTileWidth, height: choiceTileHeight)
                                .background(hasSave ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasSave)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Kreiraj novu mapu")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Button {
                    withAnimation(.easeInOut(duration: choiceTransitionDuration)) {
                        showDimensionPicker = true
                    }
                } label: {
                    Label("Create map", systemImage: "plus.square.on.square")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(maxWidth: .infinity)
                        .frame(height: choiceTileHeight)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(32)
    }

    private var dimensionPickerContent: some View {
        VStack(spacing: 28) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: choiceTransitionDuration)) {
                        showDimensionPicker = false
                    }
                } label: {
                    Label("Nazad", systemImage: "chevron.backward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text("Dimenzije mape")
                    .font(.custom("Georgia", size: 22))
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.98))
                Spacer(minLength: 0)
                Color.clear.frame(width: 80, height: 24)
            }
            .padding(.bottom, 8)

            Text("Odaberi veličinu (200×200 do 1000×1000)")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))

            VStack(spacing: 12) {
                ForEach(MapSizePreset.allCases, id: \.id) { preset in
                    Button {
                        selectedPresetForCreate = preset
                        showDimensionPicker = false
                        showCreateNameStep = true
                        createMapName = ""
                    } label: {
                        Text(preset.rawValue)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                            .frame(maxWidth: .infinity)
                            .frame(height: choiceTileHeight)
                            .background(Color.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(32)
    }

    /// Lista mapa za odabrani slot – korisnik odabere koju mapu učitati.
    private func mapPickerContent(slot: MapEditorSlot) -> some View {
        let entries = MapCatalog.entries(forSlot: slot)
        return VStack(spacing: 28) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: choiceTransitionDuration)) {
                        mapPickerSlot = nil
                    }
                } label: {
                    Label("Nazad", systemImage: "chevron.backward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text("Odaberi mapu – \(slot.displayName)")
                    .font(.custom("Georgia", size: 22))
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.98))
                Spacer(minLength: 0)
                Color.clear.frame(width: 80, height: 24)
            }
            .padding(.bottom, 8)

            Text("Odaberi mapu za učitavanje u editor")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        Button {
                            if gameState.loadEditorMap(entry: entry) {
                                gameState.openMapEditorAfterLoad()
                                mapPickerSlot = nil
                                isPresented = false
                            } else {
                                loadErrorMessage = "Učitavanje mape nije uspjelo."
                                loadErrorSlot = slot
                            }
                        } label: {
                            HStack {
                                Text(entry.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.95))
                                Spacer(minLength: 0)
                                Text("\(entry.side)×\(entry.side)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)

            Spacer(minLength: 0)
        }
        .padding(32)
    }

    /// Korak 3: naziv mape (obavezan) → Generiraj.
    private func createNameContent(preset: MapSizePreset) -> some View {
        VStack(spacing: 28) {
            HStack {
                Button {
                    showCreateNameStep = false
                    selectedPresetForCreate = nil
                    createMapName = ""
                } label: {
                    Label("Nazad", systemImage: "chevron.backward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                Text("Naziv mape")
                    .font(.custom("Georgia", size: 22))
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.98))
                Spacer(minLength: 0)
                Color.clear.frame(width: 80, height: 24)
            }
            .padding(.bottom, 8)

            Text("Dimenzija: \(preset.rawValue)")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 8) {
                Text("Naziv mape (obavezno)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                TextField("Unesite naziv mape", text: $createMapName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            Button {
                let name = createMapName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                if gameState.createMapAndOpenEditor(name: name, side: preset.side) {
                    isPresented = false
                }
            } label: {
                Text("Generiraj mapu")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .frame(height: choiceTileHeight)
                    .background(createMapName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.1) : Color.white.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(createMapName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer(minLength: 0)
        }
        .padding(32)
    }
}

#Preview {
    MapEditorChoiceView(isPresented: .constant(true))
        .environmentObject(GameState())
        .frame(width: 600, height: 480)
        .background(Color.gray.opacity(0.3))
}
