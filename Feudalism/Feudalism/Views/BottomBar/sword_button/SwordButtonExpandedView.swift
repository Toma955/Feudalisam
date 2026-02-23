//
//  SwordButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za kategoriju Oružje (2. gumb): sword_house, shield, bowl, spear, leather.
//

import SwiftUI

private let weaponColumnWidth: CGFloat = 48

struct SwordButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    var onSelectSwordHouse: () -> Void
    var onSelectShield: () -> Void
    var onSelectBow: () -> Void
    var onSelectSpear: () -> Void
    var onSelectLeather: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 14) {
                weaponButton(assetName: "sword_house", systemName: "house.fill", labelKey: "weapon_sword_house", action: onSelectSwordHouse)
                weaponButton(assetName: "shield", systemName: "shield.fill", labelKey: "weapon_shield", action: onSelectShield)
                weaponButton(assetName: "bow", systemName: "arrow.up.forward", labelKey: "weapon_bow", action: onSelectBow)
                weaponButton(assetName: "spear", systemName: "arrow.up", labelKey: "weapon_spear", action: onSelectSpear)
                weaponButton(assetName: "leather", systemName: "square.fill", labelKey: "weapon_leather", action: onSelectLeather)
            }
            HStack(spacing: 14) {
                weaponLabel("weapon_sword_house").frame(width: weaponColumnWidth, alignment: .center)
                weaponLabel("weapon_shield").frame(width: weaponColumnWidth, alignment: .center)
                weaponLabel("weapon_bow").frame(width: weaponColumnWidth, alignment: .center)
                weaponLabel("weapon_spear").frame(width: weaponColumnWidth, alignment: .center)
                weaponLabel("weapon_leather").frame(width: weaponColumnWidth, alignment: .center)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func weaponButton(assetName: String, systemName: String, labelKey: String, action: @escaping () -> Void) -> some View {
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
            .frame(width: weaponColumnWidth, height: weaponColumnWidth)
            .foregroundStyle(.white.opacity(0.95))
        }
        .buttonStyle(.plain)
    }

    private func weaponLabel(_ key: String) -> some View {
        Text(LocalizedStrings.string(for: key, language: gameState.appLanguage))
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
