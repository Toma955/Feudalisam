//
//  ComputerLordAI.swift
//  Feudalism
//
//  Igra je isključivo za treniranje i ograđivanje AI modela. Modeli imaju osnovne postavke
//  (profil: stil borbe, taktika, strategija) i prema njima se ponašaju. Koriste REALNU
//  situaciju u igri – reagiraju na nju, predviđaju budućnost. Treniranje: Python (isti
//  format situacije, npr. JSON). Inferenca u igri: Swift + Core ML (Neural Engine / GPU / CPU).
//

import Foundation

/// Označava da će computer lord koristiti Apple ML stack (Neural Engine, CPU, GPU).
enum ComputerLordComputeTarget {
    case neuralEngineAndCPU
    case gpuAndCPU
    case all
}

/// Kontroler AI za computer lord. Koristi realnu situaciju u igri (GameSituationSnapshot),
/// osnovne postavke profila i prema njima reagira i predvida; Python koristi isti snapshot za treniranje.
final class ComputerLordAI {
    let realmId: String
    var computeTarget: ComputerLordComputeTarget = .all
    var profileId: String?

    init(realmId: String, profileId: String? = nil) {
        self.realmId = realmId
        self.profileId = profileId
    }

    var profile: AILordProfile? {
        guard let id = profileId else { return nil }
        return AILordProfileStore.shared.profile(id: id)
    }

    /// Realna situacija u igri → reakcija i predviđanje. Snapshot je isti format koji Python koristi za treniranje.
    func decideNextAction(gameState: GameState) async {
        let situation = GameSituationSnapshot.from(gameState: gameState, actingRealmId: realmId)
        let _ = profile
        // Ulaz u model: situation (realno stanje) + profile (osnovne postavke)
        // Reagirat na situaciju, predvidjeti budućnost; Python trenira na istom JSON formatu
        _ = situation
    }
}
