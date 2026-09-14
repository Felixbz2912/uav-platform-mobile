# UAV Platform Mobile App

Echte Flutter-App fuer iOS und spaeter Android:

- Native App-Huelle mit eingebettetem WebView fuer die bestehende UAV-Plattform.
- Startet auf `https://uav-leipzig.de/app` und verbindet dort die Organisation.
- Native Standort-Engine sendet dauerhaft an `/api/tracker/update`.
- Bestehende Web-Funktionen bleiben serverseitig unveraendert.

## Zielbild

1. Nutzer koppelt das Geraet im Portal und erhaelt einen Tracker-Token.
2. App speichert Server-URL und Token lokal.
3. WebView oeffnet die Plattform.
4. Hintergrunddienst sendet Standort, Genauigkeit, Richtung, Geschwindigkeit und Akku.
5. Lagekarte zeigt den App-Tracker als eigenen violetten Marker.

## Backend-Endpunkte

- `POST /api/tracker/register`
  - Auth: eingeloggte Web-Sitzung
  - Body: `{"label":"iPhone Marvin","platform":"ios"}`
  - Antwort: `device_id`, `token`

- `POST /api/tracker/update`
  - Auth: `Authorization: Bearer <token>`
  - Body: `{"lat":51.3397,"lng":12.3731,"accuracy":8,"heading":180,"speed":0,"battery":87}`

- `GET /api/tracker/list`
  - Auth: eingeloggte Web-Sitzung
  - Liefert aktive Tracker fuer die Lagekarte.

- `POST /api/tracker/leave`
  - Auth: `Authorization: Bearer <token>`
  - Entfernt den aktiven Marker.

## Windows/iOS Ablauf

Auf dem Windows-PC kann der App-Code gepflegt werden. Der iOS-Build braucht
macOS/Xcode und laeuft deshalb ueber Codemagic oder GitHub Actions auf einem
Mac-Runner.

1. Repository zu GitHub pushen.
2. In Codemagic den Ordner `mobile-app` als Flutter-Projekt auswaehlen.
3. Workflow `ios-testflight` starten.
4. Fuer TestFlight spaeter Apple Developer Account und Signierung hinterlegen.

## Lokal mit Flutter SDK

Falls Flutter lokal installiert ist:

```bash
cd mobile-app
flutter create . --platforms=ios,android
flutter pub get
flutter run
```

Ohne Mac kann lokal Android getestet werden. iOS wird ueber den Cloud-Mac gebaut.

## Build-Konfiguration

`codemagic.yaml` enthaelt:

- `ios-testflight`: erzeugt eine iOS-Release-App ohne Codesign als erster Build-Test.
- `android-debug`: erzeugt spaeter eine Android-Debug-APK.

Fuer eine echte TestFlight-Verteilung muessen in Codemagic noch Apple-Zertifikate,
App Store Connect API Key und Bundle Identifier eingerichtet werden.
