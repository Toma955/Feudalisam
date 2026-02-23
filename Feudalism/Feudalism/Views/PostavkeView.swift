//
//  PostavkeView.swift
//  Feudalism
//
//  Postavke igre: General (ulazni uređaj), Audio, Video, AI.
//

import SwiftUI

struct PostavkeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gameState: GameState
    @State private var selectedSection: PostavkeSection = .general

    var body: some View {
        NavigationSplitView {
            List(PostavkeSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Postavke")
            .frame(minWidth: 200)
        } detail: {
            Group {
                switch selectedSection {
                case .general: generalContent
                case .audio: audioContent
                case .video: videoContent
                case .ai: aiContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
        }
        .frame(minWidth: 520, minHeight: 340)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Zatvori") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var generalContent: some View {
        Form {
            Section {
                Picker("Ulazni uređaj", selection: $gameState.inputDevice) {
                    ForEach(InputDevice.allCases, id: \.self) { device in
                        Text(device.displayName).tag(device)
                    }
                }
                .pickerStyle(.segmented)
                Text("Odaberi Trackpad ili Miš; posebne funkcije za svaki uređaj mogu se dodati u Trackpad odnosno Miš postavkama.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Upravljanje")
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("General")
    }

    private var audioContent: some View {
        Form {
            Section {
                Text("Postavke zvuka – u izradi.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Audio")
    }

    private var videoContent: some View {
        Form {
            Section {
                Text("Postavke video / prikaza – u izradi.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Video")
    }

    private var aiContent: some View {
        Form {
            Section {
                Text("Postavke AI – u izradi.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("AI")
    }
}

private enum PostavkeSection: String, CaseIterable, Identifiable {
    case general
    case audio
    case video
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .audio: return "Audio"
        case .video: return "Video"
        case .ai: return "AI"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .audio: return "speaker.wave.2"
        case .video: return "video"
        case .ai: return "brain"
        }
    }
}

#Preview {
    PostavkeView()
        .environmentObject(GameState())
}
