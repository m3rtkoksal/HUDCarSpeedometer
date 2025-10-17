//
//  HUDView.swift
//  HUD
//
//  Created by Mert Köksal on 14.10.2025.
//

import SwiftUI
import UIKit
import CoreLocation
import Combine

struct HUDView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var vm = HUDViewModel()
    @State private var speedUnitIsKmh: Bool = true
    @State private var showSettings: Bool = false
    @State private var hasStartedLocation: Bool = false
    @State private var showCityDownloadPrompt: Bool = false
    @State private var suggestedCity: String? = nil
    @State private var suggestedCountryCode: String? = nil
    @AppStorage("hud_cityPackDownloaded") private var cityPackDownloaded: Bool = false
    @AppStorage("hud_cityName") private var storedCityName: String = ""
    @AppStorage("hud_countryCode") private var storedCountryCode: String = ""
    @StateObject private var speedStore = SQLiteSpeedLimitStore()
    @State private var hasPromptedCityPack: Bool = false
    // UI state derived via view model

    @AppStorage("hud_maxBrightnessEnabled") private var maxBrightnessEnabled: Bool = true
    @AppStorage("hud_mirrorEnabled") private var mirrorEnabled: Bool = true
    @AppStorage("hud_keepAwakeEnabled") private var keepAwakeEnabled: Bool = true
    @AppStorage("hud_rotation") private var rotationRaw: Int = RotationPreset.deg0.rawValue
    @AppStorage("hud_color") private var hudColorRaw: String = HUDColor.white.rawValue

    enum HUDColor: String, CaseIterable, Identifiable {
        case white
        case orange
        case green
        case purple
        var id: String { rawValue }
        var color: Color {
            switch self {
            case .white: return .white
            case .orange: return .orange
            case .green: return .green
            case .purple: return .purple
            }
        }
        var label: String { rawValue.capitalized }
    }

    private var hudColor: Color {
        HUDColor(rawValue: hudColorRaw)?.color ?? .white
    }

    enum RotationPreset: Int, CaseIterable, Identifiable {
        case deg0 = 0
        case deg90 = 90
        case deg180 = 180
        case deg270 = 270
        var id: Int { rawValue }
        var label: String { "\(rawValue)°" }
    }

    private var rotationAngle: Double { Double(rotationRaw) }

    private var usesLandscapeWidth: Bool {
        // If rotated by 90 or 270, the view's width maps from the device height
        let normalized = Int(rotationAngle) % 180
        return normalized != 0
    }

    // Derived helpers for landscape badge
    private var isOverLimitNow: Bool {
        let sKmh = (locationManager.speedMetersPerSecond ?? 0) * 3.6
        guard let lim = vm.currentLimit else { return false }
        return sKmh > Double(lim)
    }
    private var overlayLimitText: String {
        // Prefer currentLimit; fallback to default 50 once speed is active; otherwise dash
        let speedActive = locationManager.speedMetersPerSecond != nil
        let baseKmh: Double? = vm.currentLimit.map { Double($0) } ?? (speedActive ? 50 : nil)
        guard let v = baseKmh else { return "—" }
        let value = speedUnitIsKmh ? v : v * 0.62137119
        return numberFormatter.string(from: NSNumber(value: value)) ?? "—"
    }

    @State private var previousBrightness: CGFloat = UIScreen.main.brightness
    @State private var previousIdleTimerDisabled: Bool = false
    @State private var speedBelowThresholdSince: Date? = nil
    @State private var notChargingSince: Date? = nil
    @State private var lastObservedSpeedKmh: Double = 0
    @State private var batteryState: UIDevice.BatteryState = UIDevice.current.batteryState

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.minimumIntegerDigits = 1
        return f
    }()
    private let flashTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    @State private var isFlashing: Bool = false
    private let inactivityDuration: TimeInterval = 300
    private let lowSpeedThresholdKmh: Double = 10

    var body: some View {
        let screen = UIScreen.main.bounds
        let containerWidth = usesLandscapeWidth ? screen.height : screen.width
        let containerHeight = usesLandscapeWidth ? screen.width : screen.height
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Mirrored main content
            VStack(spacing: 10) {
                speedText(containerWidth: containerWidth, containerHeight: containerHeight)
            }
            .opacity(0.98)
            .scaleEffect(x: mirrorEnabled ? -1 : 1, y: 1)
            .rotationEffect(.degrees(rotationAngle))
			.padding(8)

            // Non-mirrored controls overlay
            VStack {
                Spacer(minLength: 0)
                Spacer()
            }

            if showSettings {
                SettingsOverlay(
                    containerWidth: containerWidth,
                    containerHeight: containerHeight,
                    usesLandscapeWidth: usesLandscapeWidth,
                    showSettings: $showSettings,
                    mirrorEnabled: $mirrorEnabled,
                    rotationRaw: $rotationRaw,
                    speedUnitIsKmh: $speedUnitIsKmh,
                    keepAwakeEnabled: $keepAwakeEnabled,
                    maxBrightnessEnabled: $maxBrightnessEnabled,
                    hudColorRaw: $hudColorRaw
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
                .frame(width: containerWidth, height: containerHeight)
        .onAppear {
            vm.previousBrightness = UIScreen.main.brightness
            vm.previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            applyBrightnessSetting()
            applyIdleTimerSetting()
            // Request location permission immediately on first launch; delegate will start updates.
            locationManager.start()
            UIDevice.current.isBatteryMonitoringEnabled = true
            batteryState = UIDevice.current.batteryState
            if cityPackDownloaded, !storedCityName.isEmpty {
                ODRManager.shared.requestCityPack(countryCode: storedCountryCode, cityName: storedCityName) { result in
                    DispatchQueue.main.async {
                        if case .success = result {
                            if let url = vm.bundleURLForCity(storedCityName) {
                                speedStore.load(from: url)
                            }
                        }
                    }
                }
            } else if cityPackDownloaded, storedCityName.isEmpty {
                // Fallback: assume Istanbul if previously downloaded before persistence existed
                let assumed = "Istanbul"
                ODRManager.shared.requestCityPack(countryCode: storedCountryCode.isEmpty ? "TR" : storedCountryCode, cityName: assumed) { result in
                    DispatchQueue.main.async {
                        if case .success = result, let url = vm.bundleURLForCity(assumed) {
                            storedCityName = assumed
                            speedStore.load(from: url)
                        }
                    }
                }
            }
        }
        .onChange(of: maxBrightnessEnabled) { _ in
            applyBrightnessSetting()
        }
        .onChange(of: keepAwakeEnabled) { enabled in
            if enabled {
                speedBelowThresholdSince = nil
                notChargingSince = nil
            }
            applyIdleTimerSetting()
        }
        .onChange(of: showSettings) { isOpen in
            if isOpen {
                locationManager.stop()
            } else {
                if !hasStartedLocation {
                    hasStartedLocation = true
                }
                locationManager.start()
                if cityPackDownloaded, !storedCityName.isEmpty {
                    ODRManager.shared.requestCityPack(countryCode: storedCountryCode, cityName: storedCityName) { result in
                        DispatchQueue.main.async {
                            if case .success = result, let url = vm.bundleURLForCity(storedCityName) {
                                speedStore.load(from: url)
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            // Restore previous system settings
            UIScreen.main.brightness = previousBrightness
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
            locationManager.stop()
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
        .onReceive(flashTimer) { _ in
            if vm.isOverLimit {
                isFlashing.toggle()
            } else if isFlashing {
                isFlashing = false
            }
        }
        .onReceive(locationManager.$lastLocation) { loc in
            guard let loc = loc, speedStore.isReady else { return }
            let limit = speedStore.querySpeedLimit(near: loc.coordinate)
            DispatchQueue.main.async {
                vm.currentLimit = limit
            }
        }
    }

    private func speedText(containerWidth: CGFloat, containerHeight: CGFloat) -> some View {
        let speedValueMps = locationManager.speedMetersPerSecond
        let speedKmh: Double? = speedValueMps.map { $0 * 3.6 }
        let unit: String = speedUnitIsKmh ? "km/h" : "mph"
        // Prepare limit label (number only) and color state
        let limitKmh: Double? = vm.currentLimit.map { Double($0) }
        let limitDisplayValue: Double? = speedUnitIsKmh ? limitKmh : limitKmh.map { $0 * 0.62137119 }
        let limitTextString: String? = limitDisplayValue.flatMap { numberFormatter.string(from: NSNumber(value: $0)) }
        let limitBadgeView: (String, Color) -> AnyView = { text, color in
            vm.limitBadge(text: text, color: color)
        }
        let isOverLimit: Bool = {
            guard let v = speedKmh, let lim = limitKmh else { return false }
            return v > lim
        }()
        let limitColor: Color = isOverLimit ? .red : hudColor

        return Group {
            if usesLandscapeWidth {
                let base = min(containerWidth, containerHeight)
                LandscapeView(
                    displayedSpeed: vm.displayedSpeed,
                    unitText: unit.uppercased(),
                    hudColor: hudColor,
                    limitText: limitTextString,
                    limitColor: limitColor,
                    showSettings: $showSettings,
                    limitBadge: limitBadgeView
                )
                .frame(width: containerWidth, height: containerHeight)
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        SettingsButton(isPresented: $showSettings)

                        if let limit = limitTextString {
                            vm.limitBadge(text: limit, color: limitColor)
                        }
                        Spacer(minLength: 0)
                    }

                  Spacer()
                    Text(String(vm.displayedSpeed))
                        .hudFont(.speedValue(size: 170))
                        .foregroundStyle(hudColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(unit.uppercased())
                        .hudFont(.speedUnit(size: 20))
                        .foregroundStyle(hudColor.opacity(0.85))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 30)
                .padding(.trailing, 30)
            }
        }
        .alert(isPresented: $showCityDownloadPrompt) {
            let city = suggestedCity ?? "şehriniz"
            return Alert(
                title: Text("Hız Limiti Paketi"),
                message: Text("\(city) için hız limiti verisini indirmek ister misiniz?"),
                primaryButton: .default(Text("İndir")) {
                    ODRManager.shared.requestCityPack(countryCode: suggestedCountryCode, cityName: city) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                cityPackDownloaded = true
                                storedCityName = city
                                storedCountryCode = suggestedCountryCode ?? storedCountryCode
                                if let url = vm.bundleURLForCity(city) {
                                    speedStore.load(from: url)
                                }
                            case .failure:
                                cityPackDownloaded = false
                            }
                        }
                    }
                },
                secondaryButton: .cancel(Text("Daha sonra"))
            )
        }
        .onReceive(locationManager.$lastLocation) { loc in
            guard let loc = loc else { return }
            // Prompt ODR download once we have a location (first launch)
            if !cityPackDownloaded && !hasPromptedCityPack {
                hasPromptedCityPack = true
                SpeedLimitDataService.shared.reverseGeocodeCity(from: loc) { info in
                    suggestedCity = info?.cityName
                    suggestedCountryCode = info?.countryCode
                    if suggestedCity != nil {
                        showCityDownloadPrompt = true
                    }
                }
            }
            if speedStore.isReady {
                #if DEBUG
                print("[SpeedLimit] querying at", loc.coordinate.latitude, loc.coordinate.longitude)
                #endif
                let limit = speedStore.querySpeedLimit(near: loc.coordinate)
                DispatchQueue.main.async {
                    vm.currentLimit = limit
                }
                #if DEBUG
                if let limit = vm.currentLimit { print("[SpeedLimit] limit=", limit) }
                else { print("[SpeedLimit] no match on initial query") }
                #endif
            }
        }
        .onChange(of: speedStore.isReady) { ready in
            guard ready else { return }
            if let loc = locationManager.lastLocation {
                #if DEBUG
                print("[SpeedLimit] store ready – immediate query")
                #endif
                let limit = speedStore.querySpeedLimit(near: loc.coordinate)
                DispatchQueue.main.async {
                    vm.currentLimit = limit
                }
                #if DEBUG
                if let limit = vm.currentLimit { print("[SpeedLimit] limit=", limit) }
                else { print("[SpeedLimit] no match on initial query") }
                #endif
            }
        }
        .onReceive(locationManager.$speedMetersPerSecond) { s in
            // Recompute display speed on every GPS update
            let kmh = (s ?? 0) * 3.6
            let value = speedUnitIsKmh ? kmh : kmh * 0.62137119
            vm.updateSpeed(metersPerSecond: s)
            lastObservedSpeedKmh = kmh
            updateAutoDisableState(currentSpeedKmh: kmh)
        }
        .onChange(of: speedUnitIsKmh) { _ in
            // Re-render using new units based on last known value
            let s = locationManager.speedMetersPerSecond ?? 0
            let kmh = s * 3.6
            let value = speedUnitIsKmh ? kmh : kmh * 0.62137119
            vm.setUnit(isKmh: speedUnitIsKmh)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
            batteryState = UIDevice.current.batteryState
            updateAutoDisableState(currentSpeedKmh: lastObservedSpeedKmh)
        }
    }

    private func applyBrightnessSetting() {
        vm.applyBrightness(enabled: maxBrightnessEnabled)
    }

    private func applyIdleTimerSetting() {
        vm.applyIdleTimer(enabled: keepAwakeEnabled)
    }

    private func updateAutoDisableState(currentSpeedKmh: Double) {
        guard keepAwakeEnabled else { return }

        if vm.shouldDisableKeepAwake(currentSpeedKmh: currentSpeedKmh, batteryState: batteryState, lowSpeedThreshold: lowSpeedThresholdKmh, inactivityDuration: inactivityDuration) {
            keepAwakeEnabled = false
            applyIdleTimerSetting()
        }
    }
}

#Preview {
    HUDView()
        .preferredColorScheme(.dark)
}


