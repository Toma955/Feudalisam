//
//  HouseButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za Kuću: house, pharmacy, green_house, hotel, water_well, church, message (Diplomacy).
//

import SwiftUI

private let houseColumnWidth: CGFloat = 48

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
        VStack(spacing: 4) {
            HStack(spacing: 18) {
                houseButton(assetName: "house", systemName: "house.fill", action: onSelectHouse)
                houseButton(assetName: "pharmacy", systemName: "cross.case.fill", action: onSelectPharmacy)
                houseButton(assetName: "green_house", systemName: "leaf.fill", action: onSelectGreenHouse)
                houseButton(assetName: "hotel", systemName: "building.2.fill", action: onSelectHotel)
                houseButton(assetName: "water_well", systemName: "drop.fill", action: onSelectWaterWell)
                houseButton(assetName: "church", systemName: "building.columns.fill", action: onSelectChurch)
                houseButton(assetName: "message", systemName: "envelope.fill", action: onSelectDiplomacy)
            }
            HStack(spacing: 18) {
                houseLabel("house_home").frame(width: houseColumnWidth, alignment: .center)
                houseLabel("house_pharmacy").frame(width: houseColumnWidth, alignment: .center)
                houseLabel("house_green_house").frame(width: houseColumnWidth, alignment: .center)
                houseLabel("house_hotel").frame(width: houseColumnWidth, alignment: .center)
                houseLabel("house_water_well").frame(width: houseColumnWidth, alignment: .center)
                houseLabel("house_church").frame(width: houseColumnWidth, alignment: .center)
                houseLabel("house_diplomacy").frame(width: houseColumnWidth, alignment: .center)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func houseButton(assetName: String, systemName: String, action: @escaping () -> Void) -> some View {
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
            .frame(width: houseColumnWidth, height: houseColumnWidth)
            .foregroundStyle(.white.opacity(0.95))
        }
        .buttonStyle(.plain)
    }

    private func houseLabel(_ key: String) -> some View {
        Text(LocalizedStrings.string(for: key, language: gameState.appLanguage))
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
