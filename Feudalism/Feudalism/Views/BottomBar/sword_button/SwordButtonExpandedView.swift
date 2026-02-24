//
//  SwordButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za kategoriju Oružje: sword_house, shield, bowl, spear, leather. Koristi CategoryExpandedView.
//

import SwiftUI

struct SwordButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectSwordHouse: () -> Void
    var onSelectShield: () -> Void
    var onSelectBow: () -> Void
    var onSelectSpear: () -> Void
    var onSelectLeather: () -> Void

    var body: some View {
        CategoryExpandedView(items: [
            CategoryExpandedItem(assetName: "sword_house", systemName: "house.fill", labelKey: "weapon_sword_house", action: onSelectSwordHouse),
            CategoryExpandedItem(assetName: "shield", systemName: "shield.fill", labelKey: "weapon_shield", action: onSelectShield),
            CategoryExpandedItem(assetName: "bow", systemName: "arrow.up.forward", labelKey: "weapon_bow", action: onSelectBow),
            CategoryExpandedItem(assetName: "spear", systemName: "arrow.up", labelKey: "weapon_spear", action: onSelectSpear),
            CategoryExpandedItem(assetName: "leather", systemName: "square.fill", labelKey: "weapon_leather", action: onSelectLeather),
        ])
    }
}
