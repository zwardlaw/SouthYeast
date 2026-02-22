# Take Me To Pizza

A compass that points you to pizza. Built with SwiftUI for iOS 17+.

## What it does

Open the app, and a pizza slice spins to point toward the nearest pizza place. Swipe through nearby spots in the carousel, tap to expand details, and get walking directions.

## Features

- **Pizza compass** — real-time heading via CoreLocation + CoreMotion with parallax tilt
- **Nearby places** — Google Places API with infinite scroll pagination
- **Mystery mode** — pull the carousel left to activate; hides restaurant names and lets fate decide
- **Neobrutalist design** — Impact type, solid drop shadows, bold outlines

## Requirements

- iOS 17.0+
- Xcode 15+
- Google Places API key (set in `AppConfig.swift`)

## Setup

1. Clone the repo
2. Add your Google Places API key to `TakeMeToPizza/Config/AppConfig.swift`
3. Build and run on a physical device (compass requires real sensors)

## License

MIT
