-- BLITZBRAIN – Server-Tests (Supabase SQL Editor einfügen und ausführen)
-- Schreibt nichts dauerhaft: am Ende wird absichtlich ein Fehler "RESULT ..." ausgelöst (Rollback).
-- Ergebnis: Zeilen "PASS name" / "FAIL name" im Fehlertext. Alles PASS = in Ordnung.
do $t$
declare
 o text := ''; g text; cd text; i integer := 0; a jsonb; ta text; tb text; v jsonb; it integer; k integer; r public.ffa; c0 integer; s text;
begin
 perform public._auth('Zt_h','654321',true); perform public._auth('Zt_k','654321',true);

 -- 1) Alle Spiele laufen mit Bots bis zum Ende
 foreach g in array public._ffa_games() loop
  i := i + 1; cd := 'ZT' || i || 'X';
  a := public.ffa_create('Zt_h','654321',cd,g,3); ta := a->>'tk';
  perform public.ffa_join('Zt_k','654321',cd);
  for k in 1..3 loop perform public.ffa_do(cd,'Zt_h',ta,'addbot',null,1 + (k % 4)); end loop;
  update public.ffa set pl = jsonb_set(pl, '{Zt_k,seen}', to_jsonb(public._fnow() + 600000)) where ffa.code = cd;
  perform public.ffa_do(cd,'Zt_h',ta,'vote',g,null);
  v := public.ffa_do(cd,'Zt_h',ta,'start',null,null);
  it := 0;
  loop
   it := it + 1; exit when it > 80;
   update public.ffa set tp = tp - 20000, st = st
     || case when st ? 'end' then jsonb_build_object('end', (st->>'end')::bigint - 20000) else '{}'::jsonb end
     || case when st ? 'go' then jsonb_build_object('go', (st->>'go')::bigint - 20000) else '{}'::jsonb end
     || case when st ? 'pt' then jsonb_build_object('pt', (st->>'pt')::bigint - 20000) else '{}'::jsonb end where ffa.code = cd;
   v := public.ffa_do(cd,'Zt_h',ta,'get',null,null);
   exit when v->>'ph' = 'done';
  end loop;
  o := o || case when v->>'ph' = 'done' and (v->>'g') = g then 'PASS' else 'FAIL' end || ' spiel_' || g || E'\n';
 end loop;

 -- 2) Bot-Verwaltung
 a := public.ffa_create('Zt_h','654321','ZTBOT','flask',3); ta := a->>'tk';
 tb := (public.ffa_join('Zt_k','654321','ZTBOT'))->>'tk';
 for k in 1..7 loop v := public.ffa_do('ZTBOT','Zt_h',ta,'addbot',null,2); end loop;
 o := o || case when (select count(*) from jsonb_array_elements(v->'pl') e where e->'bot' <> 'null'::jsonb) = 5 then 'PASS' else 'FAIL' end || E' bots_max_5\n';
 v := public.ffa_do('ZTBOT','Zt_k',tb,'addbot',null,2);
 o := o || case when (select count(*) from jsonb_array_elements(v->'pl') e where e->'bot' <> 'null'::jsonb) = 5 then 'PASS' else 'FAIL' end || E' bots_nur_host\n';
 s := (select e->>'n' from jsonb_array_elements(v->'pl') e where e->'bot' <> 'null'::jsonb limit 1);
 v := public.ffa_do('ZTBOT','Zt_h',ta,'botlv',s,4);
 o := o || case when (select (e->>'bot')::integer from jsonb_array_elements(v->'pl') e where e->>'n' = s) = 4 then 'PASS' else 'FAIL' end || E' bot_stufe_aendern\n';
 v := public.ffa_do('ZTBOT','Zt_h',ta,'rmbot',s,null);
 o := o || case when (select count(*) from jsonb_array_elements(v->'pl') e where e->'bot' <> 'null'::jsonb) = 4 then 'PASS' else 'FAIL' end || E' bot_entfernen\n';

 -- 3) Teams
 v := public.ffa_do('ZTBOT','Zt_h',ta,'tmteam',null,null);
 v := public.ffa_do('ZTBOT','Zt_h',ta,'get',null,null);
 o := o || case when (select count(*) from jsonb_array_elements(v->'pl') e where e->>'tt' is null) = 0 and (v->>'team') = 'true' then 'PASS' else 'FAIL' end || E' team_zuteilung\n';
 for s in select e->>'n' from jsonb_array_elements(v->'pl') e loop
  if s = 'Zt_h' or s = 'Zt_k' then v := public.ffa_do('ZTBOT',s,case s when 'Zt_h' then ta else tb end,'team','A',null);
  else v := public.ffa_do('ZTBOT','Zt_h',ta,'botteam',s,0); end if;
 end loop;
 v := public.ffa_do('ZTBOT','Zt_h',ta,'start',null,null);
 o := o || case when v->>'r' = 'teams' then 'PASS' else 'FAIL' end || E' team_start_braucht_2_teams\n';
 v := public.ffa_do('ZTBOT','Zt_k',tb,'team','B',null);
 v := public.ffa_do('ZTBOT','Zt_h',ta,'start',null,null);
 o := o || case when v->>'ph' = 'intro' then 'PASS' else 'FAIL' end || E' team_start_ok\n';

 -- 4) Quiz: kein Antwort-Leak, Sperre, richtige Antwort beendet Runde
 a := public.ffa_create('Zt_h','654321','ZTQZ','quiz',3); ta := a->>'tk';
 tb := (public.ffa_join('Zt_k','654321','ZTQZ'))->>'tk';
 perform public.ffa_do('ZTQZ','Zt_h',ta,'vote','quiz',null);
 perform public.ffa_do('ZTQZ','Zt_h',ta,'start',null,null);
 update public.ffa set tp = tp - 6000 where code = 'ZTQZ';
 v := public.ffa_do('ZTQZ','Zt_h',ta,'get',null,null);
 o := o || case when v->>'ph' = 'play' and v->'st'->>'c' is null then 'PASS' else 'FAIL' end || E' quiz_kein_leak\n';
 select * into r from public.ffa where code = 'ZTQZ'; c0 := (r.st->>'c')::integer;
 v := public.ffa_do('ZTQZ','Zt_h',ta,'ans',null,(c0 + 1) % 4);
 o := o || case when (v->'st'->>'lk')::integer > 0 and v->>'ph' = 'play' then 'PASS' else 'FAIL' end || E' quiz_falsch_sperrt\n';
 v := public.ffa_do('ZTQZ','Zt_k',tb,'ans',null,c0);
 o := o || case when v->>'ph' = 'between' and v->'st'->>'w' = 'Zt_k' then 'PASS' else 'FAIL' end || E' quiz_richtig_gewinnt\n';

 -- 5) Statistik: Bots zaehlen nicht
 o := o || case when not exists (select 1 from public.ffa_stats where name_key like '%🤖%') then 'PASS' else 'FAIL' end || E' stats_ohne_bots\n';

 -- 6) Melden / Konto loeschen
 o := o || case when public.report_player('Zt_h','654321','Zt_k','cheat','x') = 'ok' then 'PASS' else 'FAIL' end || E' melden_ok\n';
 o := o || case when public.report_player('Zt_h','654321','Zt_h','cheat') = 'self' then 'PASS' else 'FAIL' end || E' melden_nicht_selbst\n';
 o := o || case when public.report_player('Zt_h','654321','Zt_k','zzz') = 'invalid' then 'PASS' else 'FAIL' end || E' melden_grund_pruefen\n';
 o := o || case when public.delete_account('Admin','000000') = 'auth' or public.delete_account('Admin','000000') = 'no' then 'PASS' else 'FAIL' end || E' admin_nicht_loeschbar\n';
 s := public.delete_account('Zt_k','654321');
 o := o || case when s = 'ok' and not exists (select 1 from public.players where name_key = 'zt_k') then 'PASS' else 'FAIL' end || E' konto_loeschen\n';

 -- 7) Online-Raum-Bots
 s := public.create_room('Zt_h','654321','ZTRM',1,10,null);
 s := public.join_room('Zt_h','654321','ZTRM');
 o := o || case when public.room_bot('Zt_h','654321','ZTRM','🤖Robo','zahlen') = 'ok' then 'PASS' else 'FAIL' end || E' raum_bot_ok\n';
 o := o || case when public.room_bot('Zt_h','654321','ZTRM','Robo','zahlen') = 'invalid' then 'PASS' else 'FAIL' end || E' raum_bot_name_pruefen\n';
 update public.rooms set stages = '["zahlen"]'::jsonb where code = 'ZTRM';
 s := public.room_bot_result('Zt_h','654321','ZTRM','🤖Robo',5000,0,'{}');
 o := o || case when s = 'ok' and (select count(*) from public.results where code = 'RAUM-ZTRM') = 1 then 'PASS' else 'FAIL' end || E' raum_bot_ergebnis\n';

 -- 8) Fehlerberichte
 s := public.log_error('t','Testfehler','x:1:1') || public.log_error('t','Testfehler','x:1:1');
 o := o || case when s = 'okok' and (select max(n) from public.app_errors where msg = 'Testfehler') = 2 then 'PASS' else 'FAIL' end || E' fehlerbericht_dedupe\n';

 raise exception E'RESULT\n%', o;
end $t$;
