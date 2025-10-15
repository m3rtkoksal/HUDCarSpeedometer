//
//  LocationManager.swift
//  HUD
//
//  Created by Mert Köksal on 14.10.2025.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    @Published var speedMetersPerSecond: CLLocationSpeed? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationServicesAvailable: Bool = CLLocationManager.locationServicesEnabled()
    @Published var lastLocation: CLLocation? = nil

    private let manager = CLLocationManager()
    private var hasRequestedAuthorization = false
    private var lastFix: CLLocation? = nil

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = false
    }

    func start() {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            if !hasRequestedAuthorization {
                hasRequestedAuthorization = true
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            // Start on next runloop tick to avoid blocking gesture handling
            DispatchQueue.main.async { [weak self] in
                self?.manager.startUpdatingLocation()
            }
        case .restricted, .denied:
            break
        @unknown default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .restricted, .denied:
            manager.stopUpdatingLocation()
            speedMetersPerSecond = nil
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            handleAuthorizationChange(manager.authorizationStatus)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // speed is negative when invalid
        let rawSpeed = location.speed
        let computedSpeed: CLLocationSpeed? = {
            if rawSpeed >= 0 { return rawSpeed }
            if let prev = lastFix {
                let dt = location.timestamp.timeIntervalSince(prev.timestamp)
                if dt > 0 {
                    let dist = location.distance(from: prev)
                    let s = dist / dt
                    // Filter out noise: ignore very small movements
                    return s > 0.3 ? s : 0
                }
            }
            return nil
        }()
        lastFix = location
        DispatchQueue.main.async {
            self.speedMetersPerSecond = computedSpeed
            self.lastLocation = location
            #if DEBUG
            if let s = computedSpeed {
                let kmh = s * 3.6
                print("[GPS] speed:", String(format: "%.1f", kmh), "km/h (", String(format: "%.2f", s), "m/s )")
            } else {
                print("[GPS] speed: n/a")
            }
            #endif
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep it simple: stop updates on fatal errors
        // A real app could surface errors via a UI banner
        Task { @MainActor in
            manager.stopUpdatingLocation()
        }
    }
}


