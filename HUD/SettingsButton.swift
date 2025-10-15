//
//  SettingsButton.swift
//  HUD
//
//  Created by Mert Köksal on 16.10.2025.
//
import SwiftUI

struct SettingsButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut) {
                isPresented.toggle()
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(10)
                .background(.white.opacity(0.08), in: Circle())
        }
        .frame(width: 60, height: 60)
    }
}
