# EVERLOXX TODO

## Release-Checkliste
- [x] CORS_ALLOW_ORIGINS korrekt gesetzt (Prod-Shop + Domain)
- [x] WORKER_APP_TOKEN gesetzt und rotiert
- [x] SHOPIFY_STOREFRONT_TOKEN gesetzt (kein Admin-Token)
- [x] Worker: SUPABASE_URL + SUPABASE_ANON_KEY + SUPABASE_SERVICE_ROLE_KEY gesetzt
- [x] Supabase Migrationen angewendet (core + delete_account + shopify lockdown)
- [x] Worker Deploy aktuell (Version-ID: 4ee6dc4d-46f0-49f7-b013-fcc12c849119)
- [x] Worker Hardening: Error-Codes 503 fuer fehlende Config, Rate-Limiting per User-ID, Webhook Error-Logging
- [x] Projekt-Export (PDF/Share) implementiert
- [x] Unit-Tests: 102 Tests (chat_text_utils, measurement_calculator, color_utils, safe_json, format_price, credit_manager)
- [x] Onboarding-Tour (4 Slides)
- [x] UI-Check fuer grosse Schrift / kleine Screens (Overflows)
- [x] chat_bot.dart Refactoring: chat_text_utils.dart extrahiert, ~20 Methoden delegiert

### Ausstehend (externe Abhaengigkeiten)
- [ ] Worker: STRIPE_SECRET_KEY + STRIPE_WEBHOOK_SECRET setzen (wenn Stripe eingerichtet)
- [ ] Worker: FCM_SERVER_KEY setzen (wenn Firebase eingerichtet)
- [ ] Push: google-services.json + GoogleService-Info.plist hinterlegen
- [ ] iOS: APNs Keys/Certs in Apple Developer + Firebase
- [ ] Apple Developer Account beantragen

## Manuelles Testing (TODOtest)

### App-Flow
- [ ] App frisch starten -> Chat-Begruessung zeigt "Foto hochladen" + "Farbe scannen"
- [ ] "Foto hochladen" -> Foto senden -> Raumtyp-Frage -> Farb-Vorschlaege -> Render-CTA erscheint
- [ ] "Farbe scannen" funktioniert weiterhin
- [ ] Render starten -> App in den Hintergrund -> Push "Render fertig" erscheint
- [ ] Render starten -> Render wird im Projekt gespeichert + Bild in Projektliste sichtbar
- [ ] Render: Slider funktioniert, Credits korrekt reduziert
- [ ] Analytics-Einwilligung geben, Fehler provozieren -> Eintrag in analytics_events
- [ ] Messung -> Empfehlung zeigt "In den Warenkorb" + "Neu messen"
- [ ] Checkout: Warenkorb -> Shopify Checkout im WebView, Zurueck fuehrt in App

### Delete Account
- [ ] Edge Function loescht Nutzerdaten + Auth-User
- [ ] /functions/v1/delete_account mit Bearer -> 200
- [ ] Danach kein Login/Token-Refresh (401)
- [ ] Tabellen & Storage leer nach Loeschung

### Worker (manuell mit curl)
- [ ] /chat mit Token -> 200
- [ ] /stripe/webhook falsche Signatur -> 400 (jetzt 503 wenn Secret fehlt, nicht mehr 500)
- [ ] /stripe/webhook doppelt senden -> zweites Event ignoriert (idempotent)
- [ ] Android: Release-Build mit key.properties signiert

## Backlog
- [ ] chat_bot.dart weiter aufteilen (~6800 Zeilen)
- [ ] Offline-Caching fuer Projekte (kein Netz)
