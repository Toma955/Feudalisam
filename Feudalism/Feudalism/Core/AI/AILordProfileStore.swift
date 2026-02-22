//
//  AILordProfileStore.swift
//  Feudalism
//
//  Spremište profila AI lordova – perzistentno; profili uče i postaju bolji kroz partije.
//

import Foundation

/// Spremište profila AI lordova. Kasnije: SwiftData / CloudKit za sync.
final class AILordProfileStore: ObservableObject {
    static let shared = AILordProfileStore()

    @Published private(set) var profiles: [AILordProfile] = []

    private let storageKey = "Feudalism.AILordProfiles"

    private init() {
        load()
        if profiles.isEmpty {
            installDefaultProfiles()
        }
    }

    /// Učitaj sa diska (UserDefaults za sada; kasnije SwiftData).
    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AILordProfile].self, from: data) else {
            return
        }
        profiles = migrateIconsAndColorsIfNeeded(decoded)
    }

    /// Ako su stari profili bez ikone/boje, dodaj im zadane vrijednosti.
    private func migrateIconsAndColorsIfNeeded(_ list: [AILordProfile]) -> [AILordProfile] {
        let defaults: [(String, String)] = [
            ("flame.fill", "E74C3C"),
            ("shield.fill", "7F8C8D"),
            ("dollarsign.circle.fill", "F1C40F"),
            ("scale.3d", "3498DB"),
            ("theatermasks.fill", "D35400"),
            ("person.3.fill", "27AE60"),
            ("bolt.fill", "F39C12"),
            ("ant.fill", "B7950B"),
            ("moon.fill", "8E44AD"),
            ("link", "1ABC9C")
        ]
        return list.enumerated().map { index, p in
            guard p.iconName == nil || p.colorHex == nil else { return p }
            let (icon, color) = index < defaults.count ? defaults[index] : ("person.fill", "808080")
            var copy = p
            copy.iconName = copy.iconName ?? icon
            copy.colorHex = copy.colorHex ?? color
            return copy
        }
    }

    /// Spremi – profili ostaju i budu sve bolji kroz partije.
    func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// Dohvati profil po id.
    func profile(id: String) -> AILordProfile? {
        profiles.first { $0.id == id }
    }

    /// Ažuriraj profil (npr. nakon partije – recordGame).
    func updateProfile(_ profile: AILordProfile) {
        guard let i = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[i] = profile
        save()
    }

    /// Zabilježi rezultat partije za profil – učenje, postaje bolji.
    func recordGameResult(profileId: String, won: Bool) {
        guard var p = profile(id: profileId) else { return }
        p.recordGame(won: won)
        updateProfile(p)
    }

    /// Dodaj novi profil (npr. custom bot).
    func addProfile(_ profile: AILordProfile) {
        guard !profiles.contains(where: { $0.id == profile.id }) else { return }
        profiles.append(profile)
        save()
    }

    /// 10 AI lordova – svaki s ikonom i bojom da ih se razlikuje.
    private func installDefaultProfiles() {
        profiles = [
            AILordProfile(name: "Vuk", description: "Brzi napadi, malo obrane.", iconName: "flame.fill", colorHex: "E74C3C", fightingStyle: .aggressive, strategyFocus: .conquest),
            AILordProfile(name: "Kamen", description: "Utvrde i strpljenje.", iconName: "shield.fill", colorHex: "7F8C8D", fightingStyle: .defensive, strategyFocus: .survival),
            AILordProfile(name: "Trgovac", description: "Zlato i gradnja.", iconName: "dollarsign.circle.fill", colorHex: "F1C40F", fightingStyle: .economic, strategyFocus: .trade),
            AILordProfile(name: "Ravnoteža", description: "Sve po malo.", iconName: "scale.3d", colorHex: "3498DB", fightingStyle: .balanced, strategyFocus: .expansion),
            AILordProfile(name: "Pljačkaš", description: "Napad-uzmi-bjež.", iconName: "theatermasks.fill", colorHex: "D35400", fightingStyle: .raider, strategyFocus: .military),
            AILordProfile(name: "Pleme", description: "Savezi i pregovori.", iconName: "person.3.fill", colorHex: "27AE60", fightingStyle: .diplomat, strategyFocus: .trade),
            AILordProfile(name: "Grom", description: "Šok i strah.", iconName: "bolt.fill", colorHex: "F39C12", fightingStyle: .aggressive, strategyFocus: .military),
            AILordProfile(name: "Pčela", description: "Rad i blagostanje.", iconName: "ant.fill", colorHex: "B7950B", fightingStyle: .economic, strategyFocus: .expansion),
            AILordProfile(name: "Sjenka", description: "Iznenađenje i povlačenje.", iconName: "moon.fill", colorHex: "8E44AD", fightingStyle: .raider, strategyFocus: .survival),
            AILordProfile(name: "Most", description: "Savezi prije svega.", iconName: "link", colorHex: "1ABC9C", fightingStyle: .diplomat, strategyFocus: .trade)
        ]
        save()
    }
}
