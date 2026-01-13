# THERMOLOX - Agent Guide (local)

## Ziel
Dieses Dokument hilft dem nächsten Agenten, die App-Struktur, den Stil und die
lokalen "Superkräfte" (Secrets) zu verstehen, ohne Geheimnisse zu leaken.

## App-Aufbau (kurz)
- Flutter App: `lib/`
  - Chat/Assistant: `lib/chat/`
  - UI/Pages: `lib/pages/` (u.a. `lib/pages/project_detail_page.dart`)
  - Services/Controller: `lib/services/`, `lib/controllers/`
  - Shared UI: `lib/widgets/`
- Supabase: `supabase/` (SQL, Functions, RLS)
- Cloudflare Worker: `cloudflare/worker.js`
  - Endpunkte: `/chat`, `/upload`, `/stt`, `/tts`, `/image-edit`
- Assets: `assets/` (Icons, Bilder)

## Schreibstil / UX
- Ton: freundlich, professionell, klar, ohne unnötigen Fachjargon.
- Umlaute in Nutzertexten verwenden (ä/ö/ü, nicht ae/oe/ue).
- DSGVO: Analytics/Chat nur mit Einwilligung.
- Worte vermeiden: "Credits" (stattdessen "Visualisierungen").
- Premium Gate: "Um <Feature> nutzen zu können, benötigst du einen Pro Account."
  Buttons: "Upgrade" / "Verzichten".

## Kommunikationsstil mit Stefan
- Kurz, direkt, lösungsorientiert.
- Erst Ergebnis, dann Kontext/Begründung.
- Nur nachfragen, wenn nötig; sonst umsetzen.

## Pro / Visualisierungen
- Pro = Lifetime.
- Visualisierungen: 10 pro Paket, Nachkauf 9,90 €.
- GodMode: `stefan.obholz@gmail.com` und User-ID
  `0d3f96a8-a856-44da-b8c9-0c8003a2b6d7`.

## Worker / Auth
- Worker verlangt `WORKER_APP_TOKEN` für alle Endpunkte.
- Header: `X-Worker-Token: <token>` oder `Authorization: Bearer <token>`.

## Superkräfte (Secrets)
Die Datei `secrets` im Repo-Root enthält lokale Keys. Sie ist in `.gitignore`.
Niemals Secrets in Code oder Chats schreiben.

### Setup (lokal)
1) Datei `secrets` befüllen (siehe Vorlage).
2) In der Shell laden:
   - `set -a; source ./secrets; set +a`

### Wichtige Keys
- OpenAI (Worker): `OPENAI_API_KEY`, `PROMPT_BRAIN`, `PROMPT_TECH`
- Worker-URL: `CF_WORKER_URL`
- Worker-Zugriff: `WORKER_APP_TOKEN`
- Supabase: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- Cloudflare: `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`

### Zugriff / Deploy
- Supabase CLI: `supabase link --project-ref $SUPABASE_PROJECT_REF`
- Worker Deploy: `wrangler deploy` (nutzt Cloudflare Tokens)
Hinweis: Netzwerkzugriff im Agenten kann eingeschränkt sein -> ggf. Approval.

## Lokale Befehle / thermolox_run
- Alias liegt in `~/.zshrc` (Zeile 17):
  `alias thermolox_run="cd ~/Projekte/thermolox && export WORKER_APP_TOKEN=$(grep -m1 '^WORKER_APP_TOKEN=' ./secrets | cut -d= -f2-) && flutter run --dart-define-from-file=supabase.json --dart-define=WORKER_APP_TOKEN=$WORKER_APP_TOKEN"`
- Alias lädt den Token direkt aus `./secrets`.
- Nach Änderung: `source ~/.zshrc`

## Aktueller Stand (kurz)
- Raumfoto-Flow: Upload soll den Flow starten; in `lib/chat/chat_bot.dart` läuft
  `_maybeStartRoomFlowAfterUpload()` vor `_handleRoomFlowUserText()`.
- Projekt-Detail: Notizen sind editierbare Stichpunkte (TextFields mit `- `,
  X löscht; leere Zeilen werden entfernt). Sync läuft über die Callbacks der Page.
- Vollbild-Preview: bei Slider-Preview Material-Ancestor nötig (Fehler "No
  Material widget found").
- Bildgrößen: Original + Render müssen gleich groß sein, sonst Verzerrung im
  Slider.

## Sonstiges
- Shopify Token ist aktuell in `lib/config/shopify_config.dart`.
