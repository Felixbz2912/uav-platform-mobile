# iOS Background Location Notes

Fuer dauerhafte iOS-Ortung muss das iOS-Projekt nach `flutter create` angepasst werden:

## Capabilities

In Xcode unter `Signing & Capabilities`:

- Background Modes aktivieren
- `Location updates` anhaken

## Info.plist

Folgende Texte muessen gesetzt werden:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

Beispieltext:

`Die App sendet deinen Standort waehrend eines Einsatzes an die UAV-Lagekarte, damit Fuehrung und Einsatzkraefte koordiniert werden koennen.`

## App Store/TestFlight

Apple erwartet, dass der dauerhafte Standortzweck sichtbar und nachvollziehbar ist.
Die App muss deshalb einen klaren Einsatzmodus anzeigen und Tracking abschaltbar machen.
