# BLITZBRAIN

Mobile-first Party-Spiel (deutsche Oberfläche) als **eine Datei**: `index.html` (HTML + CSS + JS). Punktesystem = Zeit (niedriger ist besser, +1,5 s pro Fehler).

## Dateien
- `index.html` – die komplette App (Version am Dateiende: `BBV` = Update-Kennung, `BVN` = Anzeige-Version; bei jedem Update beide erhöhen)
- `sw.js`, `manifest.webmanifest`, `icon-*.png` – Offline/Installation (PWA)
- `supabase-komplett.sql` – komplette Datenbank (Tabellen, Funktionen). Abschnitte 19–21 entsprechen exakt dem Live-Stand (per `md5(prosrc)` geprüft)
- `supabase-admin.sql` – Admin-Abfragen für den Supabase SQL Editor (nicht im Spiel)
- `tests/smoke.js` – startet alle 50 Arcade-Spiele und prüft auf Fehler (`node tests/smoke.js`, Playwright nötig)
- `.github/workflows/keepalive.yml` – hält das Supabase-Projekt wach

## Modi
Ranked (Elo), 1v1-Duell (ein Handy / online), Party (ein Handy, Online-Raum, Free-for-All inkl. Mini-Turnier, Teams und Bots, Schnell-Challenge), Arcade (solo).

## Aufbau von `index.html` (grob, von oben nach unten)
Styles → Spiele (`STG`) → Hilfsfunktionen → Menüs/Party → Duell → Ranked/Elo → Online-Duell → Profil/Freunde → Bestenlisten → Admin → Free-for-All → Raum/Challenge → Auto-Update.

## Hinweise
- Keine Passwörter/Tokens im Code. Der Supabase-Schlüssel in der App ist der öffentliche (anon) Schlüssel.
- Schreibende Datenbank-Änderungen immer zuerst in `supabase-komplett.sql` nachziehen.
