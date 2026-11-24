# BERD Check-in (Android)

Native Scanner-App für **Android-Tablets** am BERD-Empfang. Koppelt sich per Paar-QR aus dem Dashboard und prüft Buchungs-Barcodes (Code 128 / `LBB-BERD:…`).

## Voraussetzungen

- Flutter SDK (wie `lbb-mobile`)
- Buchungsportal erreichbar (`BOOKING_BASE_URL`, Port 6080 / Zoraxy)
- Dashboard: **BERD → App Connect** → Paar-QR

## Server-URL

Standard: `https://book.lbb.cylone.de` (überschreibbar in der App unter *Einstellungen* oder beim Build):

```bash
flutter build apk --release \
  --dart-define=BOOKING_BASE_URL=https://book.lbb.cylone.de
```

## Build & Install

```bash
cd berd-scanner  # eigenes Repo: github.com/Lich-Basketball-e-V/berd-scanner
flutter pub get
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Ablauf am Tablet

1. App öffnen → ggf. Server-URL prüfen  
2. Paar-QR aus dem Dashboard scannen → **Gekoppelt**  
3. Kunden-Barcode scannen → grün/rot + Buchungsdetails  
4. **Entkoppeln**, wenn das Gerät ausgetauscht wird  

API: `POST /api/booking-scanner/pair` und `POST /api/booking-scanner/verify` (Bearer-Gerätetoken).

Die Web-Variante unter `{BOOKING_BASE_URL}/scanner` bleibt als Fallback verfügbar.