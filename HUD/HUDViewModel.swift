//
//  HUDViewModel.swift
//  HUD
//
//  Created by Mert Köksal on 15.10.2025.
//

import Foundation
import Combine
import UIKit

final class HUDViewModel: ObservableObject {
    @Published var displayedSpeed: Int = 0
    @Published var currentLimit: Int? = nil
    @Published var overlayLimitText: String = "—"
    @Published var isOverLimit: Bool = false
    @Published var isFlashing: Bool = false

    private var isKmh: Bool = true
    private var cancellables: Set<AnyCancellable> = []

    // Brightness/idle management
    var previousBrightness: CGFloat = UIScreen.main.brightness
    var previousIdleTimerDisabled: Bool = UIApplication.shared.isIdleTimerDisabled

    func applyBrightness(enabled: Bool) {
        UIScreen.main.brightness = enabled ? 1.0 : previousBrightness
    }

    func applyIdleTimer(enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }

    func setUnit(isKmh: Bool) {
        self.isKmh = isKmh
        recalcOverlay()
    }

    func updateSpeed(metersPerSecond: Double?) {
        let kmh = (metersPerSecond ?? 0) * 3.6
        let value = isKmh ? kmh : kmh * 0.62137119
        displayedSpeed = Int(value.rounded())
        if let limit = currentLimit {
            isOverLimit = kmh > Double(limit)
        } else {
            isOverLimit = false
        }
        recalcOverlay(speedActive: metersPerSecond != nil)
    }

    func updateLimit(_ limit: Int?) {
        currentLimit = limit
        recalcOverlay()
    }

    private func recalcOverlay(speedActive: Bool? = nil) {
        let active = speedActive ?? (displayedSpeed > 0)
        let baseKmh: Double? = currentLimit.map { Double($0) } ?? (active ? 50 : nil)
        guard let v = baseKmh else { overlayLimitText = "—"; return }
        let value = isKmh ? v : v * 0.62137119
        overlayLimitText = String(Int(value.rounded()))
    }

    // File helpers
    func bundleURLForCity(_ city: String) -> URL? {
        let base = sanitizeCityName(city)
        return Bundle.main.url(forResource: base, withExtension: "sqlite")
    }

    func sanitizeCityName(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return raw
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: allowed.inverted).joined()
    }
}


