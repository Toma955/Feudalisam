//
//  PostavkeView.swift
//  Feudalism
//
//  Postavke igre – veličina mape, zvuk, itd. (placeholder).
//

import SwiftUI

struct PostavkeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Postavke")
                .font(.custom("Georgia", size: 28))
                .padding(.top, 24)

            Text("Za sada prilagođeno za MacBook.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Veličina mape i ostale opcije – u izradi.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Zatvori") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .padding(.bottom, 24)
        }
        .frame(minWidth: 320, minHeight: 200)
    }
}

#Preview {
    PostavkeView()
}
