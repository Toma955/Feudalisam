//
//  HouseButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za Kuću: house, pharmacy, hotel, water_well, … Koristi CategoryExpandedView.
//

import SwiftUI

struct HouseButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectHouse: () -> Void
    var onSelectPharmacy: () -> Void
    var onSelectGreenHouse: () -> Void
    var onSelectHotel: () -> Void
    var onSelectWaterWell: () -> Void
    var onSelectChurch: () -> Void
    var onSelectDiplomacy: () -> Void

    var body: some View {
        CategoryExpandedView(items: [
            CategoryExpandedItem(assetName: "house", systemName: "house.fill", labelKey: "house_home", action: onSelectHouse),
            CategoryExpandedItem(assetName: "pharmacy", systemName: "cross.case.fill", labelKey: "house_pharmacy", action: onSelectPharmacy),
            CategoryExpandedItem(assetName: "green_house", systemName: "leaf.fill", labelKey: "house_green_house", action: onSelectGreenHouse),
            CategoryExpandedItem(assetName: "hotel", systemName: "building.2.fill", labelKey: "house_hotel", action: onSelectHotel),
            CategoryExpandedItem(assetName: "water_well", systemName: "drop.fill", labelKey: "house_water_well", action: onSelectWaterWell),
            CategoryExpandedItem(assetName: "church", systemName: "building.columns.fill", labelKey: "house_church", action: onSelectChurch),
            CategoryExpandedItem(assetName: "message", systemName: "envelope.fill", labelKey: "house_diplomacy", action: onSelectDiplomacy),
        ])
    }
}
