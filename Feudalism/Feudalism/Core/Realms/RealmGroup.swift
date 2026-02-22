//
//  RealmGroup.swift
//  Feudalism
//
//  Grupa kraljevstava (savez) – pobijedi samo jedna grupa; svi u grupi dijele pobjedu.
//

import Foundation

/// Jedna grupa (savez) – više kraljevstava s istim groupId. Pobjeda = cijela grupa pobjeđuje.
struct RealmGroup: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    /// Id-evi realmova u ovoj grupi.
    var realmIds: [String]

    init(id: String? = nil, name: String, realmIds: [String] = []) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.realmIds = realmIds
    }
}
