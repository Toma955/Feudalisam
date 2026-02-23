//
//  SoloSetupView.swift
//  Feudalism
//
//  Međukorak kad se klikne Solo: odabir veličine mape (200×200 … 1000×1000) i Start.
//

import SwiftUI

private let soloSetupCornerRadius: CGFloat = 22
private let soloTileWidth: CGFloat = 200
private let soloTileHeight: CGFloat = 48

struct SoloSetupView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var isPresented: Bool
    @State private var selectedMapSize: MapSizePreset = .size200

    var body: some View {
        VStack(spacing: 24) {
            Text("Solo")
                .font(.custom("Georgia", size: 28))
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.98))
                .padding(.bottom, 4)

            Text("Veličina mape")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))

            VStack(spacing: 10) {
                ForEach(MapSizePreset.allCases) { preset in
                    Button {
                        selectedMapSize = preset
                    } label: {
                        HStack {
                            Text(preset.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.95))
                            Spacer()
                            if selectedMapSize == preset {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(width: soloTileWidth, height: soloTileHeight)
                        .background(selectedMapSize == preset ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Button {
                    isPresented = false
                } label: {
                    Label("Nazad", systemImage: "chevron.backward")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .buttonStyle(.plain)

                Button {
                    AudioManager.shared.stopIntroSoundtrack()
                    gameState.startNewGameWithSetup(humanName: "Igrač", selectedAIProfileIds: [], mapSize: selectedMapSize)
                    isPresented = false
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 120, minHeight: 44)
                        .background(Color.accentColor.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: soloSetupCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(28)
    }
}

#Preview {
    SoloSetupView(isPresented: .constant(true))
        .environmentObject(GameState())
        .frame(width: 320, height: 420)
        .background(Color.black.opacity(0.5))
}
