//
//  ODRManager.swift
//  HUD
//
//  Created by Mert Köksal on 14.10.2025.
//

import Foundation

final class ODRManager {
    static let shared = ODRManager()
    private init() {}

    private var activeRequests: [String: NSBundleResourceRequest] = [:]

    func requestCityPack(countryCode: String?, cityName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let tag = Self.makeCityTag(countryCode: countryCode, cityName: cityName)
        #if DEBUG
        print("[ODR] Requesting tag:", tag)
        #endif
        let request = NSBundleResourceRequest(tags: [tag])
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        activeRequests[tag] = request
        request.beginAccessingResources { [weak self] error in
            if let error {
                #if DEBUG
                print("[ODR] Failed for tag \(tag):", error.localizedDescription)
                #endif
                completion(.failure(error))
                self?.activeRequests[tag] = nil
                return
            }
            // Resource name convention: sanitized cityName with .sqlite extension
            let fileBase = Self.sanitizeName(cityName)
            if let url = Bundle.main.url(forResource: fileBase, withExtension: "sqlite") {
                #if DEBUG
                print("[ODR] Pack ready. URL:", url.path)
                #endif
                completion(.success(url))
            } else {
                #if DEBUG
                print("[ODR] Pack accessed but file missing in bundle for base name:", fileBase)
                #endif
                completion(.failure(NSError(domain: "hud", code: -3, userInfo: [NSLocalizedDescriptionKey: "City pack not found in bundle"])));
            }
            // Keep request cached; caller can end later if desired.
        }
    }

    func endAccess(countryCode: String?, cityName: String) {
        let tag = Self.makeCityTag(countryCode: countryCode, cityName: cityName)
        if let req = activeRequests[tag] {
            req.endAccessingResources()
            activeRequests[tag] = nil
        }
    }

    static func makeCityTag(countryCode: String?, cityName: String) -> String {
        let code = (countryCode ?? "XX").uppercased()
        let city = sanitizeName(cityName)
        return "city_\(code)_\(city)"
    }

    static func sanitizeName(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return raw
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: allowed.inverted).joined()
    }
}


