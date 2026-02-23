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
    /// Kad je postavljen (npr. overlay na glavnom izborniku), Zatvori poziva ovu akciju umjesto dismiss.
    var onDismiss: (() -> Void)? = nil

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
                case .profil: profilContent
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
                Button("Zatvori") {
                    if let onDismiss { onDismiss() }
                    else { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var generalContent: some View {
        Form {
            Section {
                Picker("Jezik", selection: $gameState.appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                Text("Tekstovi se uređuju u mapi Locales (hr, en, de, fr, it, es) u datotekama strings.json.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Jezik") }
            Section {
                Toggle("Početna animacija", isOn: $gameState.showStartupAnimation)
                Text("Prikaži animaciju pri pokretanju igre (glavni izbornik).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Pri pokretanju") }
            Section {
                Toggle("Nazivi u donjem izborniku", isOn: $gameState.showBottomBarLabels)
                Text("Kad je uključeno, ispod ikona (Dvor, Farma, …) u donjem izborniku prikazuju se nazivi.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Donji izbornik (solo)") }
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
            } header: { Text("Upravljanje") }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("General")
    }

    private var profilContent: some View {
        Form {
            Section {
                TextField("Naziv", text: $gameState.playerProfileName)
                    .textFieldStyle(.roundedBorder)
                Text("Ime vašeg profila (npr. kraljevstvo ili lord).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Naziv") }
            Section {
                Picker("Amblem", selection: $gameState.playerEmblemId) {
                    ForEach(PlayerEmblem.allCases) { emblem in
                        Label(emblem.displayName, systemImage: emblem.sfSymbolName)
                            .tag(emblem.rawValue)
                    }
                }
                .pickerStyle(.menu)
            } header: { Text("Amblem") }
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(.secondary)
                    Text("Prvi vojnici")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Uskoro")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            } header: { Text("Vojnici") }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Profil")
    }

    private var audioContent: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    volumeRow(title: "Muzika mape", icon: "music.note", value: $gameState.audioMusicVolume)
                    volumeRow(title: "Zvukovi", icon: "speaker.wave.2.fill", value: $gameState.audioSoundsVolume)
                    volumeRow(title: "Govor", icon: "person.wave.2.fill", value: $gameState.audioSpeechVolume)
                }
                Text("Muzika mape pušta se na karti u igri. Za reprodukciju dodaj map_music.mp3 u Copy Bundle Resources.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Glasnoće")
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Audio")
    }

    private func volumeRow(title: String, icon: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24, alignment: .center)
                .foregroundStyle(.secondary)
            Slider(value: value, in: 0...1, step: 0.05)
                .frame(maxWidth: 280)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 2)
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

enum PostavkeSection: String, CaseIterable, Identifiable {
    case general
    case profil
    case audio
    case video
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .profil: return "Profil"
        case .audio: return "Audio"
        case .video: return "Video"
        case .ai: return "AI"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .profil: return "person.crop.circle.fill"
        case .audio: return "speaker.wave.2"
        case .video: return "video"
        case .ai: return "brain"
        }
    }

    var previous: PostavkeSection? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), i > 0 else { return nil }
        return all[i - 1]
    }

    var next: PostavkeSection? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), i < all.count - 1 else { return nil }
        return all[i + 1]
    }
}

/// Sadržaj jedne kategorije za ugradnju u glavni izbornik (unutar istog kvadrata).
struct PostavkeSectionContent: View {
    @EnvironmentObject private var gameState: GameState
    let section: PostavkeSection

    var body: some View {
        Group {
            switch section {
            case .general: generalContent
            case .profil: profilContent
            case .audio: audioContent
            case .video: videoContent
            case .ai: aiContent
            }
        }
    }

    private var generalContent: some View {
        Form {
            Section {
                Picker("Jezik", selection: $gameState.appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                Text("Tekstovi se uređuju u mapi Locales (hr, en, de, fr, it, es) u datotekama strings.json.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Jezik") }
            Section {
                Toggle("Početna animacija", isOn: $gameState.showStartupAnimation)
                Text("Prikaži animaciju pri pokretanju igre (glavni izbornik).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Pri pokretanju") }
            Section {
                Toggle("Nazivi u donjem izborniku", isOn: $gameState.showBottomBarLabels)
                Text("Kad je uključeno, ispod ikona (Dvor, Farma, …) u donjem izborniku prikazuju se nazivi.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Donji izbornik (solo)") }
            Section {
                Picker("Ulazni uređaj", selection: $gameState.inputDevice) {
                    ForEach(InputDevice.allCases, id: \.self) { device in
                        Text(device.displayName).tag(device)
                    }
                }
                .pickerStyle(.segmented)
                Text("Odaberi Trackpad ili Miš.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Upravljanje") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var profilContent: some View {
        Form {
            Section {
                TextField("Naziv", text: $gameState.playerProfileName)
                    .textFieldStyle(.roundedBorder)
                Text("Ime vašeg profila (npr. kraljevstvo ili lord).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: { Text("Naziv") }
            Section {
                Picker("Amblem", selection: $gameState.playerEmblemId) {
                    ForEach(PlayerEmblem.allCases) { emblem in
                        Label(emblem.displayName, systemImage: emblem.sfSymbolName)
                            .tag(emblem.rawValue)
                    }
                }
                .pickerStyle(.menu)
            } header: { Text("Amblem") }
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(.secondary)
                    Text("Prvi vojnici")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Uskoro")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            } header: { Text("Vojnici") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var audioContent: some View {
        Form {
            Section {
                volumeRow(title: "Muzika mape", icon: "music.note", value: $gameState.audioMusicVolume)
                volumeRow(title: "Zvukovi", icon: "speaker.wave.2.fill", value: $gameState.audioSoundsVolume)
                volumeRow(title: "Govor", icon: "person.wave.2.fill", value: $gameState.audioSpeechVolume)
            } header: { Text("Glasnoće") }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func volumeRow(title: String, icon: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24, alignment: .center)
                .foregroundStyle(.secondary)
            Slider(value: value, in: 0...1, step: 0.05)
                .frame(maxWidth: 280)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 2)
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
    }
}

#Preview {
    PostavkeView()
        .environmentObject(GameState())
}
