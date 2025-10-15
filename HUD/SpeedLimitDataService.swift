//
//  SpeedLimitDataService.swift
//  HUD
//
//  Created by Mert Köksal on 14.10.2025.
//

import Foundation
import CoreLocation

final class SpeedLimitDataService {
    static let shared = SpeedLimitDataService()
    private init() {}

    struct CityInfo {
        let cityName: String
        let countryCode: String?
    }

    func reverseGeocodeCity(from location: CLLocation, completion: @escaping (CityInfo?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            let pm = placemarks?.first
            // Prefer administrativeArea (e.g., Istanbul) over locality/district (e.g., Sancaktepe)
            let name = pm?.administrativeArea ?? pm?.locality ?? pm?.subAdministrativeArea
            let code = pm?.isoCountryCode
            if let name {
                completion(CityInfo(cityName: name, countryCode: code))
            } else {
                completion(nil)
            }
        }
    }

    func downloadCityPack(from urlString: String, to localFileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "hud", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad URL"])));
            return
        }
        let task = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            if let error { completion(.failure(error)); return }
            guard let tempURL else {
                completion(.failure(NSError(domain: "hud", code: -2, userInfo: [NSLocalizedDescriptionKey: "No file"])));
                return
            }
            do {
                let dest = try self.moveToDocuments(tempURL: tempURL, name: localFileName)
                completion(.success(dest))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    private func moveToDocuments(tempURL: URL, name: String) throws -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dest = docs.appendingPathComponent(name)
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.moveItem(at: tempURL, to: dest)
        return dest
    }
}


