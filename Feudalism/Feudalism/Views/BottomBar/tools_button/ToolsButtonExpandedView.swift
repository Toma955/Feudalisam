//
//  ToolsButtonExpandedView.swift
//  Feudalism
//
//  Prošireni sadržaj za kategoriju Alati: Sword (sword_icon, zeleno kad označen), Mace (mace.png, crveno kad označen), Report, Shovel, Pen.
//

import SwiftUI
import AppKit

private let toolColumnWidth: CGFloat = 48

struct ToolsButtonExpandedView: View {
    @EnvironmentObject private var gameState: GameState
    @Binding var selectedToolId: String?
    var onSelectSword: () -> Void
    var onSelectMace: () -> Void
    var onSelectReport: () -> Void
    var onSelectShovel: () -> Void
    var onSelectPen: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 14) {
                toolButton(icon: "sword_icon", systemName: "crossed.swords", labelKey: "tools_sword", isHighlighted: selectedToolId == "sword", highlightColor: .green, action: onSelectSword)
                toolButton(icon: "mace", systemName: "hammer.fill", labelKey: "tools_mace", isHighlighted: selectedToolId == "mace", highlightColor: .red, action: onSelectMace)
                toolButton(icon: "report", systemName: "doc.text.fill", labelKey: "tools_report", isHighlighted: selectedToolId == "report", highlightColor: .green, action: onSelectReport)
                toolButton(icon: "shovel", systemName: "square.fill", labelKey: "tools_shovel", isHighlighted: selectedToolId == "shovel", highlightColor: .green, action: onSelectShovel)
                toolButton(icon: "pen", systemName: "pencil", labelKey: "tools_pen", isHighlighted: selectedToolId == "pen", highlightColor: .green, action: onSelectPen)
            }
            HStack(spacing: 14) {
                toolLabel("tools_sword").frame(width: toolColumnWidth, alignment: .center)
                toolLabel("tools_mace").frame(width: toolColumnWidth, alignment: .center)
                toolLabel("tools_report").frame(width: toolColumnWidth, alignment: .center)
                toolLabel("tools_shovel").frame(width: toolColumnWidth, alignment: .center)
                toolLabel("tools_pen").frame(width: toolColumnWidth, alignment: .center)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func toolButton(icon: String, systemName: String, labelKey: String, isHighlighted: Bool, highlightColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let img = loadBarIcon(named: icon) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 28))
                }
            }
            .frame(width: toolColumnWidth, height: toolColumnWidth)
            .foregroundStyle(isHighlighted ? highlightColor : .white.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isHighlighted ? highlightColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func toolLabel(_ key: String) -> some View {
        Text(LocalizedStrings.string(for: key, language: gameState.appLanguage))
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
