import SwiftUI

struct LandscapeView: View {
    let displayedSpeed: Int
    let unitText: String
    let hudColor: Color
    let limitText: String?
    let limitColor: Color
    @Binding var showSettings: Bool
    let limitBadge: (String, Color) -> AnyView

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let base = min(width, height)
            let speedFontSize = min(max(120, base * 0.5), width * 0.55)
            let unitFontSize = min(max(20, base * 0.07), width * 0.12)

            HStack(spacing: max(12, base * 0.04)) {
                VStack(spacing: max(8, base * 0.04)) {
                    SettingsButton(isPresented: $showSettings)

                    if let limit = limitText {
                        limitBadge(limit, limitColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    Spacer()
                }
                .padding(.top, max(10, base * 0.06))
                .frame(width: max(56, base * 0.18))

                VStack(alignment: .trailing, spacing: max(4, base * 0.02)) {
                    Spacer(minLength: base * 0.08)

                    Text(String(displayedSpeed))
                        .hudFont(.speedValue(size: speedFontSize))
                        .foregroundStyle(hudColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(unitText)
                        .hudFont(.speedUnit(size: unitFontSize))
                        .foregroundStyle(hudColor.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.top, base * 0.01)
                        .padding(.trailing, base * 0.015)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.trailing, max(12, base * 0.04))
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, max(16, base * 0.05))
            .padding(.vertical, base * 0.04)
        }
    }
}


