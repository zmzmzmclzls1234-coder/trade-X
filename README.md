# TradePulse Mobile - Cross-Platform Stock Trading Simulator (Flutter)

This Flutter application is built for both **Android** and **iOS** using a single Dart codebase.

## Features
- **Cross-Platform**: Android and iOS native UI adaptation with notch and gesture safe area support.
- **Real Market Data**: Connects directly to the secure TradePulse Express backend (`/api/v1`).
- **54 Supported Countries**: Real stock securities, sector/industry/cap filtering, and top 50–100 real stock lists per country.
- **Virtual ₩1,000,000 Trading**: Instant order execution with real live market prices.
- **Bottom Navigation**: Home, Markets, Portfolio, Watchlist, Profile.
- **Dark Fintech Glassmorphism**: Premium fintech UI styling.

## Running the App
1. Install Flutter SDK (`>=3.0.0`).
2. Run `flutter pub get` inside the `flutter_app` directory.
3. Start the backend Node.js server (`npm run dev` in workspace root).
4. Launch on Android:
   ```bash
   flutter run -d android
   ```
5. Launch on iOS:
   ```bash
   flutter run -d ios
   ```
