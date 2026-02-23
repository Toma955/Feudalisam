//
//  FoodButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za Hranu: Mlin, Pivovara, Destilerija, Vinski podrum, Krčma (beer), Smočnica (pantry), Pekara, Zalogajnica.
//

import SwiftUI

private let foodColumnWidth: CGFloat = 48

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
        VStack(spacing: 4) {
            HStack(spacing: 14) {
                foodButton(assetName: "food", systemName: "leaf.fill", action: onSelectMill)
                foodButton(assetName: "brewery_icon", systemName: "mug.fill", action: onSelectBrewery)
                foodButton(assetName: "brewing", systemName: "flask.fill", action: onSelectDistillery)
                foodButton(assetName: "wine_barrel", systemName: "wineglass.fill", action: onSelectWineCellar)
                foodButton(assetName: "beer", systemName: "mug.fill", action: onSelectTavern)
                foodButton(assetName: "pantry", systemName: "cabinet.fill", action: onSelectPantry)
                foodButton(assetName: "bakery", systemName: "birthday.cake.fill", action: onSelectBakery)
                foodButton(assetName: "cauldron", systemName: "frying.pan.fill", action: onSelectCanteen)
            }
            HStack(spacing: 14) {
                foodLabel("food_mill").frame(width: foodColumnWidth, alignment: .center)
                foodLabel("food_brewery").frame(width: foodColumnWidth, alignment: .center)
                foodLabel("food_distillery").frame(width: foodColumnWidth, alignment: .center)
                foodLabel("food_wine_cellar").frame(width: foodColumnWidth, alignment: .center)
                foodLabel("food_tavern").frame(width: foodColumnWidth, alignment: .center)
                foodLabel("food_smocnica").frame(width: foodColumnWidth, alignment: .center)
                foodLabel("food_bakery").frame(width: foodColumnWidth, alignment: .center)
                foodLabel("food_canteen").frame(width: foodColumnWidth, alignment: .center)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func foodButton(assetName: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let img = loadBarIcon(named: assetName) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 28))
                }
            }
            .frame(width: foodColumnWidth, height: foodColumnWidth)
            .foregroundStyle(.white.opacity(0.95))
        }
        .buttonStyle(.plain)
    }

    private func foodLabel(_ key: String) -> some View {
        Text(LocalizedStrings.string(for: key, language: gameState.appLanguage))
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
