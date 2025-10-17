import SwiftUI
import UIKit

public enum HUDFontStyle {
    case speedValue(size: CGFloat)
    case speedUnit(size: CGFloat)
    case settingsLabel(size: CGFloat)
    case body(size: CGFloat)

    fileprivate var font: Font {
        let fontName = "digital-7"
        switch self {
        case .speedValue(let size):
            return .custom(fontName, size: size)
        case .speedUnit(let size):
            return .custom(fontName, size: size)
        case .settingsLabel(let size):
            return .custom(fontName, size: size)
        case .body(let size):
            return .custom(fontName, size: size)
        }
    }

    fileprivate var lineSpacing: CGFloat {
        switch self {
        case .speedValue, .speedUnit:
            return 0
        case .settingsLabel, .body:
            return 2
        }
    }

    fileprivate var kerning: CGFloat {
        switch self {
        case .speedValue:
            return 2
        case .speedUnit:
            return 1
        case .settingsLabel:
            return 0.5
        case .body:
            return 0
        }
    }
}

public struct HUDFontStyleModifier: ViewModifier {
    let style: HUDFontStyle

    public func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .font(style.font)
                .lineSpacing(style.lineSpacing)
                .kerning(style.kerning)
        } else {
            content
                .font(style.font)
                .lineSpacing(style.lineSpacing)
        }
    }
}

public extension View {
    func hudFont(_ style: HUDFontStyle) -> some View {
        modifier(HUDFontStyleModifier(style: style))
    }
}
