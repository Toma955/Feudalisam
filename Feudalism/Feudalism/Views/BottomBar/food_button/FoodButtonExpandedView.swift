//
//  FoodButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za Hranu: Mlin, Pivovara, … Pekara, Zalogajnica. Koristi CategoryExpandedView.
//

import SwiftUI

struct FoodButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectMill: () -> Void
    var onSelectBrewery: () -> Void
    var onSelectDistillery: () -> Void
    var onSelectWineCellar: () -> Void
    var onSelectTavern: () -> Void
    var onSelectPantry: () -> Void
    var onSelectBakery: () -> Void
    var onSelectCanteen: () -> Void

    var body: some View {
        CategoryExpandedView(items: [
            CategoryExpandedItem(assetName: "food", systemName: "leaf.fill", labelKey: "food_mill", action: onSelectMill),
            CategoryExpandedItem(assetName: "brewery_icon", systemName: "mug.fill", labelKey: "food_brewery", action: onSelectBrewery),
            CategoryExpandedItem(assetName: "brewing", systemName: "flask.fill", labelKey: "food_distillery", action: onSelectDistillery),
            CategoryExpandedItem(assetName: "wine_barrel", systemName: "wineglass.fill", labelKey: "food_wine_cellar", action: onSelectWineCellar),
            CategoryExpandedItem(assetName: "beer", systemName: "mug.fill", labelKey: "food_tavern", action: onSelectTavern),
            CategoryExpandedItem(assetName: "pantry", systemName: "cabinet.fill", labelKey: "food_smocnica", action: onSelectPantry),
            CategoryExpandedItem(assetName: "bakery", systemName: "birthday.cake.fill", labelKey: "food_bakery", action: onSelectBakery),
            CategoryExpandedItem(assetName: "cauldron", systemName: "frying.pan.fill", labelKey: "food_canteen", action: onSelectCanteen),
        ])
    }
}
