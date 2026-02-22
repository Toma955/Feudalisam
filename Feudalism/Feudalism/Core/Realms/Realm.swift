//
//  Realm.swift
//  Feudalism
//
//  Jedan Kraj (kraljevstvo) na mapi – jedan kralj (lord). Human ili Computer.
//

import Foundation
import SwiftUI

/// Tko upravlja tim kraljevstvom:
/// - **Human lord**: igrač kontrolira igru (ovaj kraj).
/// - **Computer lord**: AI kontrolira ovaj kraj.
enum LordType: String, Codable, CaseIterable, Equatable {
    case human = "Human"     // igrač kontrolira igru
    case computer = "Computer"  // AI kontrolira ovaj kraj
}

/// Jedan Kraj (kraljevstvo) – jedan lord na mapi (human kontrolira igru, computer koristi AI).
struct Realm: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    /// Boja za prikaz na karti / UI (hex ili naziv).
    var colorHex: String
    /// Id grupe (saveza); isti groupId = jedna grupa. Nil = sam.
    var groupId: String?
    /// Izbačen iz igre (nema teritorija / kralj pao).
    var isDefeated: Bool
    /// Human = igrač kontrolira igru; Computer = AI kontrolira ovaj kraj.
    var lordType: LordType
    /// Profil AI lorda – stil borbe, taktika, strategija; uči i postaje bolji. Samo za computer lord.
    var aiProfileId: String?

    init(
        id: String? = nil,
        name: String,
        colorHex: String = "8B4513",
        groupId: String? = nil,
        isDefeated: Bool = false,
        lordType: LordType = .computer,
        aiProfileId: String? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.colorHex = colorHex
        self.groupId = groupId
        self.isDefeated = isDefeated
        self.lordType = lordType
        self.aiProfileId = aiProfileId
    }

    /// Igrač kontrolira igru (human lord); inače AI kontrolira (computer lord).
    var isPlayerControlled: Bool { lordType == .human }

    var color: Color {
        Color(hex: colorHex) ?? .brown
    }
}

// MARK: - Color hex (jednostavno za SwiftUI)
extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let num = UInt64(s, radix: 16) else { return nil }
        let r = Double((num >> 16) & 0xFF) / 255
        let g = Double((num >> 8) & 0xFF) / 255
        let b = Double(num & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
