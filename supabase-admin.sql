-- BLITZBRAIN – Admin-Werkzeuge (nur für dich im Supabase SQL Editor, NICHT im Spiel)
-- Einzelne Blöcke markieren und mit "Run selected" ausführen.

-- 1) Alle Konten ansehen (ohne PIN)
select name, team, created_at, fails, locked_until from public.players order by created_at;

-- 2) Konto-Sperre aufheben (z. B. nach zu vielen Fehlversuchen)
-- update public.players set fails = 0, locked_until = null where name_key = lower('NAME');

-- 3) PIN für jemanden neu setzen (Spieler hat PIN vergessen) – neue PIN dem Spieler mitteilen
-- update public.players set pin_hash = extensions.crypt('NEUE_PIN', extensions.gen_salt('bf')), fails = 0, locked_until = null where name_key = lower('NAME');

-- 4) Konto löschen (Name wird wieder frei; Ergebnisse bleiben erhalten)
-- delete from public.players where name_key = lower('NAME');

-- 5) Alle Ergebnisse eines Spielers löschen (z. B. Fehleinträge)
-- delete from public.results where lower(name) = lower('NAME');

-- 6) Ein einzelnes Ergebnis löschen: erst ansehen, dann per id löschen
-- select id, code, name, total_ms, created_at from public.results order by created_at desc limit 50;
-- delete from public.results where id = 123;

-- 7) Alte Ergebnisse aufräumen (älter als 180 Tage; Rekorde gehen dabei verloren!)
-- delete from public.results where created_at < now() - interval '180 days';

-- 8) Alte Räume/Duelle aufräumen (älter als 7 Tage)
-- delete from public.rooms where created_at < now() - interval '7 days';

-- 9) Spiele-Bewertungen auswerten: welche Spiele sind beliebt, zu schwer oder nervig?
select game,
       count(*) filter (where vote = 'up')   as gut,
       count(*) filter (where vote = 'hard') as zu_schwer,
       count(*) filter (where vote = 'down') as nervig,
       count(*)                              as gesamt
from public.ratings group by game order by nervig desc, zu_schwer desc;

-- 10) Teams und ihre Mitglieder
select coalesce(team, '(kein Team)') as team, count(*) as spieler from public.players group by 1 order by 2 desc;

-- 11) Aktivität der letzten 7 Tage (Spieler mit den meisten Ergebnissen)
select name, count(*) as ergebnisse from public.results where created_at > now() - interval '7 days' and code <> 'ARCADE-SOLO' group by name order by 2 desc;
