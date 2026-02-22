//
//  AILordProfile.swift
//  Feudalism
//
//  Profil AI lorda – svaki bot drugačiji: način borbe, taktika, strategija.
//  Profili tijekom vremena uče i postaju sve bolji (iskustvo, level, pobede).
//

import Foundation

/// Način borbe / fokus taktike – svaki profil može imati drugačiji stil.
enum AIFightingStyle: String, Codable, CaseIterable, Identifiable {
    case aggressive = "Agresivan"
    case defensive = "Defenzivan"
    case economic = "Ekonomski"
    case balanced = "Uravnotežen"
    case raider = "Pljačkaš"
    case diplomat = "Diplomata"

    var id: String { rawValue }
}

/// Strategija na razini kraljevstva – dugoročni prioritet.
enum AIStrategyFocus: String, Codable, CaseIterable, Identifiable {
    case conquest = "Osvajanje"
    case expansion = "Širenje"
    case trade = "Trgovina"
    case military = "Vojska"
    case survival = "Preživljavanje"

    var id: String { rawValue }
}

/// Jedan profil AI lorda – osobina bota (taktika, strategija) koji uči i postaje bolji.
struct AILordProfile: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var description: String

    /// SF Symbol ime za ikonu (npr. "flame.fill") – da se lordovi razlikuju.
    var iconName: String?
    /// Boja u hex (npr. "E74C3C") – za prikaz na karti i u listi.
    var colorHex: String?

    /// Način borbe / taktika – svaki bot drugačiji.
    var fightingStyle: AIFightingStyle
    /// Strategijski fokus.
    var strategyFocus: AIStrategyFocus

    // MARK: - Učenje – tokom vremena postaju sve bolji

    /// Razina iskustva (raste s igrama).
    var experienceLevel: Int
    /// Ukupno odigranih partija.
    var gamesPlayed: Int
    /// Pobjede – za feedback u model.
    var wins: Int
    /// Porazi – za učenje.
    var losses: Int
    /// Opcionalno: verzija/iteracija Core ML modela (nakon retrain-a).
    var modelVersion: Int

    init(
        id: String? = nil,
        name: String,
        description: String = "",
        iconName: String? = nil,
        colorHex: String? = nil,
        fightingStyle: AIFightingStyle = .balanced,
        strategyFocus: AIStrategyFocus = .expansion,
        experienceLevel: Int = 1,
        gamesPlayed: Int = 0,
        wins: Int = 0,
        losses: Int = 0,
        modelVersion: Int = 1
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.description = description
        self.iconName = iconName
        self.colorHex = colorHex
        self.fightingStyle = fightingStyle
        self.strategyFocus = strategyFocus
        self.experienceLevel = experienceLevel
        self.gamesPlayed = gamesPlayed
        self.wins = wins
        self.losses = losses
        self.modelVersion = modelVersion
    }

    /// Ikona za UI (fallback ako nije postavljeno).
    var displayIconName: String { iconName ?? "person.fill" }
    /// Boja za UI (fallback).
    var displayColorHex: String { colorHex ?? "808080" }

    /// Omjer pobjeda (za težinu / odabir modela).
    var winRate: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(wins) / Double(gamesPlayed)
    }

    /// Zabilježi odigranu partiju – pobjeda ili poraz; povećava level/iskustvo.
    mutating func recordGame(won: Bool) {
        gamesPlayed += 1
        if won { wins += 1 } else { losses += 1 }
        if gamesPlayed % 5 == 0 {
            experienceLevel = min(experienceLevel + 1, 99)
        }
    }
}
