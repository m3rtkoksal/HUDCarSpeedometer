//
//  SQLiteSpeedLimitStore.swift
//  HUD
//
//  Created by Mert Köksal on 14.10.2025.
//

import Foundation
import CoreLocation
import SQLite3
import Combine

final class SQLiteSpeedLimitStore: ObservableObject {
    @Published private(set) var isReady: Bool = false

    private var db: OpaquePointer?
    private var roadSamples: [RoadSample] = []
    private let workerQueue = DispatchQueue(label: "speedstore.worker", qos: .userInitiated)

    private struct RoadSample {
        let centroidLon: Double
        let centroidLat: Double
        let maxspeedKmh: Int?
        let highway: String?
    }

    func load(from url: URL) {
        workerQueue.async {
            self.openDatabase(at: url)
            let samples = self.buildInMemorySamples()
            DispatchQueue.main.async {
                self.roadSamples = samples
                self.isReady = true
            }
        }
    }

    func querySpeedLimit(near coordinate: CLLocationCoordinate2D) -> Int? {
        guard isReady else { return nil }
        let targetLon = coordinate.longitude
        let targetLat = coordinate.latitude

        var bestDistance = CLLocationDistance.greatestFiniteMagnitude
        var bestSample: RoadSample?

        // Simple linear scan – good enough for city-sized packs. Can be optimized later.
        for sample in roadSamples {
            let d = Self.haversineDistance(lat1: targetLat, lon1: targetLon, lat2: sample.centroidLat, lon2: sample.centroidLon)
            if d < bestDistance {
                bestDistance = d
                bestSample = sample
            }
        }

        // Prefer close matches; allow wider fallback up to 300m
        guard let sample = bestSample else { return nil }
        if bestDistance >= 300 { return nil }
        if let limit = sample.maxspeedKmh { return limit }
        // Fallback by highway type if maxspeed is missing
        if let hw = sample.highway { return Self.defaultLimit(for: hw) }
        return nil
    }

    private func openDatabase(at url: URL) {
        closeDatabase()
        var dbPointer: OpaquePointer?
        if sqlite3_open_v2(url.path, &dbPointer, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
            db = dbPointer
        }
    }

    private func closeDatabase() {
        if let db { sqlite3_close(db) }
        db = nil
        DispatchQueue.main.async {
            self.roadSamples.removeAll(keepingCapacity: false)
            self.isReady = false
        }
    }

    private func buildInMemorySamples() -> [RoadSample] {
        guard let db else { return [] }
        // Detect columns dynamically to be resilient to different exports
        let info = detectRoadsColumns(db: db)
        guard let geomCol = info.geomColumn else {
            #if DEBUG
            print("[SpeedStore] geometry column not found")
            #endif
            return []
        }
        #if DEBUG
        print("[SpeedStore] using geomColumn=\(info.geomColumn ?? "nil") max=\(info.hasMaxspeed) hwy=\(info.hasHighway)")
        #endif
        let maxCol = info.hasMaxspeed ? "maxspeed" : "'' AS maxspeed"
        let hwyCol = info.hasHighway ? "highway" : "'' AS highway"
        let sql = "SELECT \(maxCol), \(hwyCol), \(geomCol) FROM roads"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var samples: [RoadSample] = []
        samples.reserveCapacity(150000)

        while sqlite3_step(stmt) == SQLITE_ROW {
            // maxspeed
            var maxspeedKmh: Int? = nil
            if let cStr = sqlite3_column_text(stmt, 0) {
                let s = String(cString: cStr)
                maxspeedKmh = SQLiteSpeedLimitStore.parseMaxspeed(s)
            }
            // highway
            var highway: String? = nil
            if let cStr = sqlite3_column_text(stmt, 1) {
                highway = String(cString: cStr)
            }
            // geometry: handle WKB BLOB or WKT TEXT
            let colType = sqlite3_column_type(stmt, 2)
            if colType == SQLITE_BLOB, let blobPtr = sqlite3_column_blob(stmt, 2) {
                let blobSize = Int(sqlite3_column_bytes(stmt, 2))
                let data = Data(bytes: blobPtr, count: blobSize)
                let points = SQLiteSpeedLimitStore.parseWKBSamples(from: data, maxSamplesPerLine: 16)
                for pt in points {
                    samples.append(RoadSample(centroidLon: pt.lon, centroidLat: pt.lat, maxspeedKmh: maxspeedKmh, highway: highway))
                    if samples.count >= 500_000 { break }
                }
            } else if let gStr = sqlite3_column_text(stmt, 2) {
                let wkt = String(cString: gStr)
                let points = SQLiteSpeedLimitStore.parseLineStringSamples(from: wkt, maxSamplesPerLine: 16)
                for pt in points {
                    samples.append(RoadSample(centroidLon: pt.lon, centroidLat: pt.lat, maxspeedKmh: maxspeedKmh, highway: highway))
                    if samples.count >= 500_000 { break }
                }
            } else {
                #if DEBUG
                print("[SpeedStore] geometry value type=", colType)
                #endif
            }
            if samples.count >= 500_000 { break }
        }

        #if DEBUG
        print("[SpeedStore] loaded samples:", samples.count)
        #endif
        return samples
    }

    private func detectRoadsColumns(db: OpaquePointer) -> (geomColumn: String?, hasMaxspeed: Bool, hasHighway: Bool) {
        var stmt: OpaquePointer?
        var foundGeom: String? = nil
        var hasMax = false
        var hasHwy = false
        if sqlite3_prepare_v2(db, "PRAGMA table_info(roads)", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let nameC = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: nameC)
                    let lower = name.lowercased()
                    if lower == "geom" || lower == "geometry" { foundGeom = name }
                    if lower == "maxspeed" { hasMax = true }
                    if lower == "highway" { hasHwy = true }
                }
            }
        }
        sqlite3_finalize(stmt)
        // Fallback: try querying known geometry column names
        if foundGeom == nil {
            let candidates = ["geom","geometry","GEOMETRY","wkt","WKT"]
            for cand in candidates {
                var probe: OpaquePointer?
                let q = "SELECT \(cand) FROM roads LIMIT 1"
                if sqlite3_prepare_v2(db, q, -1, &probe, nil) == SQLITE_OK {
                    foundGeom = cand
                    sqlite3_finalize(probe)
                    break
                }
                sqlite3_finalize(probe)
            }
        }
        return (foundGeom, hasMax, hasHwy)
    }

    private static func parseMaxspeed(_ raw: String) -> Int? {
        // Common forms: "50", "50 km/h", "signals", "walk"
        let digits = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: digits)
        var value: Int = 0
        if scanner.scanInt(&value) { return value }
        return nil
    }

    private static func parseLineStringSamples(from wkt: String, maxSamplesPerLine: Int) -> [(lon: Double, lat: Double)] {
        // Normalizes both LINESTRING and MULTILINESTRING to a plain list of "lon lat" pairs.
        var cleaned = wkt
        cleaned = cleaned.replacingOccurrences(of: "MULTILINESTRING", with: "")
        cleaned = cleaned.replacingOccurrences(of: "LINESTRING", with: "")
        cleaned = cleaned.replacingOccurrences(of: "(", with: "")
        cleaned = cleaned.replacingOccurrences(of: ")", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return [] }
        let pairs = cleaned.split(separator: ",")
        if pairs.isEmpty { return [] }
        let desired = max(1, min(maxSamplesPerLine, pairs.count))
        let step = max(1, pairs.count / desired)
        var result: [(Double, Double)] = []
        result.reserveCapacity(desired)
        var i = 0
        while i < pairs.count && result.count < desired {
            let token = pairs[i]
            let comps = token.trimmingCharacters(in: .whitespaces).split(whereSeparator: { $0 == " " || $0 == "\t" })
            if comps.count >= 2, let lon = Double(comps[0]), let lat = Double(comps[1]) {
                result.append((lon, lat))
            }
            i += step
        }
        if let last = pairs.last {
            let comps = last.trimmingCharacters(in: .whitespaces).split(whereSeparator: { $0 == " " || $0 == "\t" })
            if comps.count >= 2, let lon = Double(comps[0]), let lat = Double(comps[1]) {
                if result.isEmpty || (result.last!.0 != lon || result.last!.1 != lat) {
                    result.append((lon, lat))
                }
            }
        }
        return result
    }

    private static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> CLLocationDistance {
        let r = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1 * .pi/180) * cos(lat2 * .pi/180) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }

    private static func defaultLimit(for highway: String) -> Int {
        // Simple defaults for Turkey (rough); adjust as needed
        switch highway {
        case "motorway": return 120
        case "trunk", "primary": return 90
        case "secondary": return 80
        case "tertiary", "residential": return 50
        default: return 50
        }
    }

    // Minimal WKB parser for LineString/MultiLineString (little endian). Alignment-safe.
    private static func parseWKBSamples(from data: Data, maxSamplesPerLine: Int) -> [(lon: Double, lat: Double)] {
        var cursor = 0

        func readUInt8() -> UInt8? {
            guard cursor + 1 <= data.count else { return nil }
            let v = data[cursor]
            cursor += 1
            return v
        }
        func readUInt32LE() -> UInt32? {
            guard cursor + 4 <= data.count else { return nil }
            var u: UInt32 = 0
            _ = withUnsafeMutableBytes(of: &u) { buf in
                data.copyBytes(to: buf, from: cursor..<(cursor+4))
            }
            cursor += 4
            return UInt32(littleEndian: u)
        }
        func readDoubleLE() -> Double? {
            guard cursor + 8 <= data.count else { return nil }
            var u: UInt64 = 0
            _ = withUnsafeMutableBytes(of: &u) { buf in
                data.copyBytes(to: buf, from: cursor..<(cursor+8))
            }
            cursor += 8
            u = UInt64(littleEndian: u)
            return Double(bitPattern: u)
        }

        guard let byteOrder = readUInt8(), byteOrder == 1 else { return [] } // little endian
        guard let geomTypeRaw = readUInt32LE() else { return [] }
        let geomType = geomTypeRaw & 0xFF
        var points: [(Double, Double)] = []

        if geomType == 2 { // LineString
            guard let n = readUInt32LE() else { return [] }
            let count = Int(n)
            let step = max(1, count / maxSamplesPerLine)
            for i in 0..<count {
                guard let x = readDoubleLE(), let y = readDoubleLE() else { return points }
                if i % step == 0 || i == count - 1 { points.append((x, y)) }
            }
        } else if geomType == 5 { // MultiLineString
            guard let num = readUInt32LE() else { return [] }
            for _ in 0..<Int(num) {
                _ = readUInt8()         // sub byte order
                _ = readUInt32LE()      // sub type
                guard let n = readUInt32LE() else { break }
                let count = Int(n)
                let step = max(1, count / maxSamplesPerLine)
                for i in 0..<count {
                    guard let x = readDoubleLE(), let y = readDoubleLE() else { break }
                    if i % step == 0 || i == count - 1 { points.append((x, y)) }
                }
            }
        }
        return points
    }
}


