# Codemagic Setup fuer iOS

## Projekt

- Repository verbinden
- Project type: Flutter
- Project path: `mobile-app`
- Workflow fuer den ersten Test: `ios-testflight`

## Erster Build

Der erste Build erzeugt die iOS-Projektdateien automatisch:

```bash
flutter create . --platforms=ios,android --org de.uavleipzig --project-name uav_platform_mobile
```

Danach baut Codemagic eine unsigned iOS-App. Das prueft erstmal nur, ob das
Projekt auf macOS/Xcode sauber kompiliert.

## TestFlight spaeter

Fuer TestFlight muessen danach in Codemagic hinterlegt werden:

- Apple Developer Account
- App Store Connect API Key
- Bundle ID: `de.uavleipzig.uavplatformmobile`
- Signing Certificate
- Provisioning Profile

Erst danach wird aus dem unsigned Build eine installierbare TestFlight-Version.

## Android spaeter

Workflow `android-debug` baut eine Debug-APK. Android kann spaeter aus derselben
Codebasis mitlaufen.
