# TeamLink

Kollaborations-Desktop-App für kleine Teams — Aufgaben, geteilte Notizen und 1:1-Chat ohne externe Dienste.

## Features

| Feature | Details |
|---|---|
| Aufgaben | Titel, Deadline, Zuweisung oder „offen" — in unter 10 Sek. anlegen |
| Aufgaben übernehmen | Offene Aufgaben per einzigem Klick einem selbst zuweisen |
| Geteilte Notizen | Echtzeit-Sync zwischen allen Projektmitgliedern (< 500 ms) |
| 1:1-Chat | Direktnachrichten ohne externen Dienst, über eigenen Sync-Server |
| Dashboard | Offene / übernommene / erledigte Aufgaben + Deadlines der nächsten 14 Tage |
| Rollen | Lead, Mitglied, Beobachter als Labels — keine technischen Einschränkungen |

---

## Quickstart

### Voraussetzungen

| Tool | Mindestversion |
|---|---|
| Node.js | 18 |
| npm | 9 |
| Flutter SDK | 3.19 |
| Windows / macOS / Linux Desktop | — |

---

### 1 — Sync-Server starten

```bash
cd sync-server
cp .env.example .env        # Werte prüfen (PORT, DB_PATH, NODE_ENV)
npm ci
npm start
```

Der Server läuft auf `http://localhost:3000` (WebSocket: `ws://localhost:3000`).

Für den Entwicklungsbetrieb mit Auto-Reload:

```bash
npm run dev
```

Alternativ mit pm2 (empfohlen für dauerhaften Betrieb):

```bash
bash scripts/deploy-server.sh
```

---

### 2 — Flutter-Client starten

```bash
cd desktop-client
flutter pub get
flutter run -d windows      # oder: -d macos / -d linux
```

Beim ersten Start verbindet sich die App automatisch mit `localhost:3000`.

---

### 3 — Shared Models neu generieren (optional)

Wenn JSON-Schemas unter `shared-models/schemas/` geändert wurden:

```bash
cd shared-models
node generate.js
```

Die generierten Dart-Dateien landen in `desktop-client/lib/models/`.

---

## Architektur

```
TeamTool/
├── desktop-client/      Flutter Desktop (Windows / macOS / Linux)
│   └── lib/
│       ├── app.dart             App-Root, GoRouter, Riverpod-Scope
│       ├── main.dart            Einstiegspunkt
│       ├── models/              Dart-Modelle (aus shared-models generiert)
│       └── features/
│           └── dashboard/       Dashboard-Screen
├── sync-server/         Node.js + Express + SQLite + WebSocket
│   └── src/
│       ├── index.js             Server-Start
│       ├── app.js               Express-App
│       ├── db/schema.js         SQLite-Schema
│       ├── middleware/auth.js   Auth-Middleware
│       └── routes/              REST-Endpunkte (auth, projects, tasks)
└── shared-models/       JSON-Schemas + Dart-Codegenerator
    ├── schemas/                 User, Task, Project, Note, Message, Membership
    └── generate.js              Erzeugt Dart-Modelle aus Schemas
```

**Datenpfad (Beispiel Aufgabe anlegen):**

```
Flutter UI
  → HTTP POST /projects/:id/tasks  (REST)
  → Express Route → SQLite INSERT
  → WebSocket broadcast an alle verbundenen Clients
  → Riverpod Provider update → UI rebuild
```

---

## Installer bauen

### Windows (MSIX)

```powershell
.\scripts\build-windows-installer.ps1
```

Ausgabe: `dist/TeamLink-*.msix`

### macOS (DMG)

```bash
bash scripts/build-macos-installer.sh
```

Ausgabe: `dist/TeamLink-*.dmg`

---

## Umgebungsvariablen (Sync-Server)

Siehe [`sync-server/.env.example`](sync-server/.env.example) für alle verfügbaren Variablen.

| Variable | Standard | Beschreibung |
|---|---|---|
| `PORT` | `3000` | HTTP/WebSocket-Port |
| `DB_PATH` | `data/teamlink.db` | SQLite-Datenbankdatei |
| `NODE_ENV` | `production` | `development` aktiviert Debug-Ausgaben |

---

## Screenshots

> Screenshots werden nach dem ersten UI-Build unter `docs/screenshots/` abgelegt.

| Screen | Datei |
|---|---|
| Dashboard | `docs/screenshots/dashboard.png` |
| Aufgabe anlegen | `docs/screenshots/task-create.png` |
| Geteilte Notizen | `docs/screenshots/notes.png` |
| 1:1-Chat | `docs/screenshots/chat.png` |

---

## Entwicklung

### Server-Tests

```bash
cd sync-server
npm test
```

### Flutter-Analyse

```bash
cd desktop-client
flutter analyze
```

### Codegen (Riverpod)

```bash
cd desktop-client
dart run build_runner build --delete-conflicting-outputs
```
