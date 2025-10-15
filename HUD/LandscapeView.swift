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
        HStack {
            VStack(spacing: 8) {
                SettingsButton(isPresented: $showSettings)

                if let limit = limitText {
                    limitBadge(limit, limitColor)
                }
                Spacer()
            }
            .padding(.top, 20)
            .frame(width: 68)

            Spacer()

            HStack(alignment: .bottom, spacing: 12) {
                Text(String(displayedSpeed))
                    .font(.system(size: 350, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .kerning(0)
                    .foregroundStyle(hudColor)
                    .lineLimit(1)

                Text(unitText)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(hudColor.opacity(0.85))
                    .lineLimit(1)
                    .frame(alignment: .trailing)
                    .padding(.bottom)
                    .padding(.trailing)
            }
        }
        .padding(.leading)
    }
}


