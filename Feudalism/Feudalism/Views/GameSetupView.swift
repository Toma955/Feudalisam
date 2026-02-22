//
//  GameSetupView.swift
//  Feudalism
//
//  Dodaj sebe (human lord) i AI lordove, pa pokreni igru. Svaki AI ima ikonu i boju.
//

import SwiftUI

struct GameSetupView: View {
    @EnvironmentObject private var gameState: GameState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileStore = AILordProfileStore.shared

    @State private var humanName: String = ""
    @State private var humanColorHex: String = "2E86AB"
    @State private var selectedAIProfileIds: Set<String> = []

    private let humanColorOptions: [(String, String)] = [
        ("2E86AB", "Plava"),
        ("27AE60", "Zelena"),
        ("E74C3C", "Crvena"),
        ("8E44AD", "Ljubičasta"),
        ("F39C12", "Narančasta")
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Nova igra")
                        .font(.custom("Georgia", size: 28))
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)

                    // Human lord
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ti (human lord)")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title)
                                .foregroundStyle(Color(hex: humanColorHex) ?? .blue)
                            TextField("Tvoje ime", text: $humanName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 280)
                            Menu {
                                ForEach(humanColorOptions, id: \.0) { hex, label in
                                    Button(label) { humanColorHex = hex }
                                }
                            } label: {
                                Circle()
                                    .fill(Color(hex: humanColorHex) ?? .blue)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // AI lordovi
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("AI lordovi")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.9))
                            Text("(odabrano \(selectedAIProfileIds.count))")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 10) {
                            ForEach(profileStore.profiles) { profile in
                                AILordRow(
                                    profile: profile,
                                    isSelected: selectedAIProfileIds.contains(profile.id),
                                    onToggle: { toggleAI(profile.id) }
                                )
                            }
                        }
                    }

                    // Pokreni igru
                    Button(action: startGame) {
                        Text("Pokreni igru")
                            .font(.custom("Georgia", size: 20))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canStart ? Color.green.opacity(0.8) : Color.gray.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStart)
                    .padding(.top, 16)
                }
                .padding(24)
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var canStart: Bool {
        true
    }

    private func toggleAI(_ profileId: String) {
        if selectedAIProfileIds.contains(profileId) {
            selectedAIProfileIds.remove(profileId)
        } else {
            selectedAIProfileIds.insert(profileId)
        }
    }

    private func startGame() {
        gameState.startNewGameWithSetup(
            humanName: humanName.trimmingCharacters(in: .whitespacesAndNewlines),
            humanColorHex: humanColorHex,
            selectedAIProfileIds: Array(selectedAIProfileIds)
        )
        dismiss()
    }
}

private struct AILordRow: View {
    let profile: AILordProfile
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: profile.displayIconName)
                    .font(.title2)
                    .foregroundStyle(Color(hex: profile.displayColorHex) ?? .gray)
                    .frame(width: 28, alignment: .center)
                Circle()
                    .fill(Color(hex: profile.displayColorHex) ?? .gray)
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                    Text(profile.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color(hex: profile.displayColorHex) ?? .green : .white.opacity(0.4))
            }
            .padding(10)
            .background(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GameSetupView()
        .environmentObject(GameState())
        .frame(width: 560, height: 500)
}
