import SwiftUI

extension HUDView {
    struct SettingsOverlay: View {
        let containerWidth: CGFloat
        let containerHeight: CGFloat
        let usesLandscapeWidth: Bool

        @Binding var showSettings: Bool
        @Binding var mirrorEnabled: Bool
        @Binding var rotationRaw: Int
        @Binding var speedUnitIsKmh: Bool
        @Binding var keepAwakeEnabled: Bool
        @Binding var maxBrightnessEnabled: Bool
        @Binding var hudColorRaw: String

        private var overlayWidth: CGFloat { usesLandscapeWidth ? containerHeight : containerWidth }
        private var overlayHeight: CGFloat { usesLandscapeWidth ? containerWidth : containerHeight }
        private var hudTint: Color {
            let color = HUDColor(rawValue: hudColorRaw)?.color ?? .white
            if color == .white {
                return .gray
            }
            return color
        }

        var body: some View {
            VStack(spacing: 16) {
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)

                Text("HUD Settings")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $mirrorEnabled) {
                        Label("Mirror display (for windshield reflection)", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                    .tint(hudTint)
                    .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rotation")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                        HStack(spacing: 12) {
                            ForEach(RotationPreset.allCases) { option in
                                Button {
                                    rotationRaw = option.rawValue
                                } label: {
                                    Text(option.label)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            (rotationRaw == option.rawValue ? .white.opacity(0.15) : .white.opacity(0.08)),
                                            in: .rect(cornerRadius: 8)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(rotationRaw == option.rawValue ? .white.opacity(0.6) : .white.opacity(0.12), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }

                    Toggle(isOn: $speedUnitIsKmh) {
                        Label("Units: km/h (off = mph)", systemImage: "speedometer")
                    }
                    .tint(hudTint)
                    .foregroundStyle(.white)

                    Toggle(isOn: $keepAwakeEnabled) {
                        Label("Keep screen awake", systemImage: "moon.zzz")
                    }
                    .tint(hudTint)
                    .foregroundStyle(.white)

                    Toggle(isOn: $maxBrightnessEnabled) {
                        Label("Maximize brightness while active", systemImage: "sun.max")
                    }
                    .tint(hudTint)
                    .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("HUD color")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.8))
                        HStack(spacing: 12) {
                            ForEach(HUDColor.allCases) { option in
                                Button {
                                    hudColorRaw = option.rawValue
                                } label: {
                                    Text(option.label)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(option.color)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            (hudColorRaw == option.rawValue ? option.color.opacity(0.15) : .white.opacity(0.08)),
                                            in: .rect(cornerRadius: 8)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(hudColorRaw == option.rawValue ? option.color.opacity(0.6) : .white.opacity(0.12), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(.black.opacity(0.7), in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 16)

                Button {
                    withAnimation(.easeInOut) {
                        showSettings = false
                    }
                } label: {
                    Text("Close")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(.white, in: .rect(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .frame(width: overlayWidth, height: overlayHeight, alignment: .bottom)
            .background(
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut) { showSettings = false }
                    }
            )
        }
    }
}


