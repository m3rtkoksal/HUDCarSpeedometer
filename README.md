# HUD Car Speedometer

HUD is a SwiftUI-based iOS head-up display that mirrors your current speed and nearby speed limit onto your windshield. It is designed for night driving, supports landscape and portrait orientations, and works offline with bundled OpenStreetMap-derived city packs.

## Features
- Large mirrored speed readout with automatic flashing when you exceed the limit
- Landscape and portrait layouts optimized for windshield reflection
- Offline speed-limit lookup using preprocessed SQLite packs per city
- Optional over-limit alert badge and adaptive HUD color themes
- In-app settings sheet for mirroring, rotation presets, brightness lock, unit toggle, and color

## Requirements
- Xcode 15 or newer
- iOS 15 (minimum deployment target 15.8)
- Location permissions (When In Use / Always & When In Use)

## Getting Started
1. Clone the repository:
   ```bash
   git clone https://github.com/m3rtkoksal/HUDCarSpeedometer.git
   cd HUDCarSpeedometer
   ```
2. Install Git LFS (required for the bundled road databases):
   ```bash
   brew install git-lfs
   git lfs install
   git lfs pull
   ```
3. Open `HUD.xcodeproj` or the workspace in Xcode and build/run on a device.

**Note:** The app relies on GPS speed data, so testing on a physical device is recommended.

## City Speed-Limit Packs
The app ships with SQLite databases under `HUD/Roads/` (Istanbul, Ankara, Izmir, Bursa). These were generated from OpenStreetMap extracts and include sampled road geometries with maxspeed tags for quick nearest-neighbour queries. To add another city:

1. Create or download a `.sqlite` pack following the existing schema (`roads` table with geometry, optional `maxspeed`, `highway`).
2. Add the file to `HUD/Roads/` and include it in the Xcode target.
3. Update `HUDView` / `HUDViewModel` logic to load the new city as needed.

Because packs are tracked with Git LFS, any new `.sqlite` files must also be added via `git lfs track`.

## Location & Privacy
- `NSLocationWhenInUseUsageDescription`: explains why instant location access is needed for speed and limit calculations.
- `NSLocationAlwaysAndWhenInUseUsageDescription` / `NSLocationAlwaysUsageDescription`: used to keep the HUD accurate when mirrored on a windshield.
- `ITSAppUsesNonExemptEncryption`: declared as `NO` (no custom encryption).

## Settings Overlay
Access the settings overlay via the gear button:
- Mirror display toggle (for windshield use)
- Rotation presets (0°, 90°, 180°, 270°)
- Units (km/h vs mph)
- Keep screen awake & max brightness options
- HUD color theme selection

## Architecture Overview
- `HUDView`: top-level SwiftUI layout handling rotation, mirroring, and state.
- `HUDViewModel`: maintains derived UI state (speed text, limit badge, flashing state).
- `LocationManager`: wraps `CLLocationManager` for speed updates.
- `SQLiteSpeedLimitStore`: lightweight nearest road lookup using preloaded samples.
- `SpeedLimitDataService`: reverse-geocoding and optional pack download support.
- `LandscapeView` / `SettingsOverlay`: modular subviews for distinct UI sections.

## Contributing
Pull requests and issues are welcome. If you adjust the OSM speed-limit pipeline, note any schema changes in the README and update the SQLite loader accordingly.

## License
This project currently does not include an explicit license. All rights reserved by the author unless stated otherwise.


