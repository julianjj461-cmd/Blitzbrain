-- BLITZBRAIN: komplettes Setup in EINEM Block (Highscores, Räume, Konten mit PIN)
-- Kann auf einer neuen UND auf einer bestehenden Datenbank ausgeführt werden (nichts geht verloren).

create extension if not exists pgcrypto with schema extensions;

-- 1) Highscores / Ergebnisse
create table if not exists public.results (id bigint generated always as identity primary key, code text not null check (char_length(code) between 8 and 30), name text not null check (char_length(name) between 1 and 14), total_ms integer not null check (total_ms between 500 and 3600000), pen_ms integer not null default 0 check (pen_ms >= 0), games jsonb not null default '{}', created_at timestamptz not null default now());
create index if not exists results_code_total_idx on public.results (code, total_ms);
alter table public.results enable row level security;
drop policy if exists "results lesen" on public.results;
create policy "results lesen" on public.results for select to anon using (true);

-- 2) Räume und 1v1-Duelle
create table if not exists public.rooms (code text primary key check (char_length(code) between 4 and 8), seed integer not null, size integer not null check (size between 2 and 5), host text not null check (char_length(host) between 1 and 14), stages jsonb, start_at timestamptz, created_at timestamptz not null default now());
alter table public.rooms enable row level security;
drop policy if exists "rooms lesen" on public.rooms;
drop policy if exists "rooms eintragen" on public.rooms;
drop policy if exists "rooms aendern" on public.rooms;
create policy "rooms lesen" on public.rooms for select to anon using (true);

create table if not exists public.picks (id bigint generated always as identity primary key, code text not null references public.rooms(code) on delete cascade, name text not null check (char_length(name) between 1 and 14), game text, picked_at timestamptz, created_at timestamptz not null default now(), unique (code, name), unique (code, game));
alter table public.picks enable row level security;
drop policy if exists "picks lesen" on public.picks;
drop policy if exists "picks aendern" on public.picks;
drop policy if exists "picks eintragen" on public.picks;
create policy "picks lesen" on public.picks for select to anon using (true);

-- 3) Konten mit PIN
create table if not exists public.players (name_key text primary key, name text not null, pin_hash text not null, fails integer not null default 0, locked_until timestamptz, created_at timestamptz not null default now());
alter table public.players add column if not exists avatar text;
alter table public.players add column if not exists team text;
alter table public.players add column if not exists last_seen timestamptz;
alter table public.players enable row level security;

create or replace function public._bad_name(p text) returns boolean language sql immutable set search_path = public as $$ select n ~ '(adolf|arsch|bastard|bitch|blowjob|cunt|dildo|fick|fotze|fuck|goebbels|hakenkreuz|himmler|hitler|hure|hurensohn|idiot|judensau|kack|kanacke|kanake|missgeburt|mongo|nazi|neger|nigg|nutt|nutte|penis|penner|pimmel|pisse|porn|pussy|scheiss|scheisse|schlampe|schwanz|schwuchtel|shit|siegheil|slut|spast|stalin|titte|trottel|vagina|vollidiot|vollpfosten|votze|whore|wichs|wixer|wixx|zigeuner)' or regexp_replace(n, '(.)\1+', '\1', 'g') ~ '(adolf|arsch|bastard|bitch|blowjob|cunt|dildo|fick|fotze|fuck|goebels|hakenkreuz|himler|hitler|hure|hurensohn|idiot|judensau|kack|kanacke|kanake|misgeburt|mongo|nazi|neger|nig|nut|nute|pener|penis|pimel|pise|porn|pusy|scheis|scheise|schlampe|schwanz|schwuchtel|shit|siegheil|slut|spast|stalin|tite|trotel|vagina|volidiot|volpfosten|votze|whore|wichs|wix|wixer|zigeuner)' from (select regexp_replace(translate(replace(lower(p), 'ß', 'ss'), 'äöü@$013457', 'aouasoieast'), '[^a-z]', '', 'g') as n) q $$;

create or replace function public._auth(p_name text, p_pin text, p_create boolean) returns text language plpgsql security definer set search_path = public, extensions as $$ declare r public.players; k text := lower(btrim(p_name)); begin if char_length(btrim(p_name)) not between 1 and 14 or char_length(coalesce(p_pin, '')) not between 4 and 12 then return 'invalid'; end if; select * into r from public.players where name_key = k; if not found then if p_create then if public._bad_name(p_name) then return 'blocked'; end if; insert into public.players(name_key, name, pin_hash) values (k, btrim(p_name), crypt(p_pin, gen_salt('bf'))); return 'new:' || btrim(p_name); end if; return 'none'; end if; if r.locked_until is not null and r.locked_until > now() then return 'locked'; end if; if r.pin_hash = crypt(p_pin, r.pin_hash) then update public.players set fails = 0, locked_until = null where name_key = k; return 'ok:' || r.name; end if; if r.fails >= 4 then update public.players set fails = 0, locked_until = now() + interval '5 minutes' where name_key = k; return 'locked'; end if; update public.players set fails = fails + 1 where name_key = k; return 'wrong'; end $$;

create or replace function public.claim_name(p_name text, p_pin text) returns text language sql security definer set search_path = public, extensions as $$ select public._auth(p_name, p_pin, true) $$;

create or replace function public.submit_result(p_name text, p_pin text, p_code text, p_total integer, p_pen integer, p_games jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; insert into public.results(code, name, total_ms, pen_ms, games) values (p_code, substr(s, 4), p_total, p_pen, coalesce(p_games, '{}'::jsonb)); return 'ok'; end $$;

create or replace function public.join_room(p_name text, p_pin text, p_code text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; insert into public.picks(code, name) values (p_code, substr(s, 4)) on conflict do nothing; return 'ok'; end $$;

create or replace function public.create_room(p_name text, p_pin text, p_code text, p_seed integer, p_size integer, p_stages jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if char_length(coalesce(p_code, '')) not between 4 and 8 or p_size not between 2 and 5 then return 'invalid'; end if; insert into public.rooms(code, seed, size, host, stages) values (p_code, p_seed, p_size, substr(s, 4), p_stages); return 'ok'; exception when unique_violation then return 'exists'; end $$;

create or replace function public.set_room(p_name text, p_pin text, p_code text, p_stages jsonb, p_start timestamptz, p_expect integer) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; r public.rooms; me text; duel boolean; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := substr(s, 4); select * into r from public.rooms where code = p_code; if not found then return 'stale'; end if; duel := left(p_code, 1) = '1' and r.stages is not null and jsonb_typeof(r.stages) = 'object'; if r.host <> me and not (duel and exists (select 1 from public.picks where code = p_code and name = me)) then return 'denied'; end if; if p_stages is not null and not duel and r.stages is not null then return 'stale'; end if; update public.rooms set stages = coalesce(p_stages, stages), start_at = coalesce(p_start, start_at) where code = p_code and (p_expect is null or (stages ->> 'r')::integer = p_expect); if not found then return 'stale'; end if; return 'ok'; end $$;

create or replace function public.set_pick(p_name text, p_pin text, p_code text, p_game text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; update public.picks set game = p_game, picked_at = now() where code = p_code and name = substr(s, 4); return 'ok'; exception when unique_violation then return 'taken'; end $$;

drop function if exists public.best_times(integer);
create or replace function public.best_times(p_days integer default null) returns table(n text, g text, ms integer, d text, t text) language sql stable security definer set search_path = public as $$ with x as (select r.name as nm, j.key as gm, case when jsonb_typeof(j.value) = 'number' then (j.value #>> '{}')::numeric end as v, r.created_at as ts from public.results r, lateral jsonb_each(case when jsonb_typeof(r.games) = 'object' then r.games else '{}'::jsonb end) j where r.code <> 'ARCADE-SOLO' and r.total_ms >= 700 and (p_days is null or r.created_at >= now() - make_interval(days => p_days))), b as (select distinct on (gm, nm) nm, gm, v::integer as vi, ts from x where v >= 700 and v <= 600000 order by gm, nm, v, ts), k as (select nm, gm, vi, ts, row_number() over (partition by gm order by vi, ts) as rn from b) select k.nm, k.gm, k.vi, to_char(k.ts, 'YYYY-MM-DD'), (select pl.team from public.players pl where pl.name_key = lower(btrim(k.nm))) from k where k.rn <= 25 order by k.gm, k.vi $$;

-- 5) Bewertungen, Teams, Profil, Reaktionen
create table if not exists public.ratings (name_key text not null, game text not null check (char_length(game) between 1 and 30), vote text not null check (vote in ('up', 'down', 'hard')), created_at timestamptz not null default now(), primary key (name_key, game));
alter table public.ratings enable row level security;

create table if not exists public.reacts (id bigint generated always as identity primary key, code text not null, name text not null, emoji text not null, created_at timestamptz not null default now());
create index if not exists reacts_code_idx on public.reacts (code, id);
alter table public.reacts enable row level security;
drop policy if exists "reacts lesen" on public.reacts;
create policy "reacts lesen" on public.reacts for select to anon using (true);

create or replace function public.rate_game(p_name text, p_pin text, p_game text, p_vote text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if p_vote not in ('up', 'down', 'hard') or char_length(coalesce(p_game, '')) not between 1 and 30 then return 'invalid'; end if; insert into public.ratings(name_key, game, vote) values (lower(substr(s, 4)), p_game, p_vote) on conflict (name_key, game) do update set vote = excluded.vote, created_at = now(); return 'ok'; end $$;

create or replace function public.set_team(p_name text, p_pin text, p_team text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; t text := btrim(coalesce(p_team, '')); ex text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if t = '' then update public.players set team = null where name_key = lower(substr(s, 4)); return 'ok:'; end if; if char_length(t) > 12 then return 'invalid'; end if; if public._bad_name(t) then return 'blocked'; end if; select team into ex from public.players where lower(team) = lower(t) limit 1; update public.players set team = coalesce(ex, t) where name_key = lower(substr(s, 4)); return 'ok:' || coalesce(ex, t); end $$;

create or replace function public.set_avatar(p_name text, p_pin text, p_avatar text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if p_avatar is not null and p_avatar <> '' and p_avatar <> all (array['🦊', '🐙', '🚀', '🐲', '🦄', '🐼', '🐸', '🦁', '🐧', '🦉', '🐝', '🦖', '🐳', '🦋', '🐢', '🐯', '🦈', '🐨', '🐵', '🦩', '🐺', '🦔', '👻', '🤖']) then return 'invalid'; end if; update public.players set avatar = nullif(p_avatar, '') where name_key = lower(substr(s, 4)); return 'ok'; end $$;

create or replace function public.get_avatars() returns table(k text, a text) language sql stable security definer set search_path = public as $$ select name_key, avatar from public.players where avatar is not null $$;

create or replace function public.get_team(p_name text) returns text language sql stable security definer set search_path = public as $$ select team from public.players where name_key = lower(btrim(p_name)) $$;

create or replace function public.player_bests(p_name text) returns table(g text, ms integer, rk integer, cnt integer) language sql stable security definer set search_path = public as $$ with x as (select r.name as nm, j.key as gm, case when jsonb_typeof(j.value) = 'number' then (j.value #>> '{}')::numeric end as v, r.created_at as ts from public.results r, lateral jsonb_each(case when jsonb_typeof(r.games) = 'object' then r.games else '{}'::jsonb end) j where r.code <> 'ARCADE-SOLO' and r.total_ms >= 700), b as (select distinct on (gm, lower(nm)) lower(nm) as nk, gm, v::integer as vi from x where v >= 700 and v <= 600000 order by gm, lower(nm), v), k as (select nk, gm, vi, rank() over (partition by gm order by vi) as rk, count(*) over (partition by gm) as cnt from b) select gm, vi, rk::integer, cnt::integer from k where nk = lower(btrim(p_name)) order by gm $$;

create or replace function public.send_react(p_name text, p_pin text, p_code text, p_emoji text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if p_emoji not in ('😏', '🤯', '👏', '😭', '🔥', '🥱') then return 'invalid'; end if; if not exists (select 1 from public.picks where code = p_code and name = substr(s, 4)) then return 'denied'; end if; delete from public.reacts where created_at < now() - interval '1 day'; insert into public.reacts(code, name, emoji) values (p_code, substr(s, 4), p_emoji); return 'ok'; end $$;

revoke all on function public._auth(text, text, boolean), public._bad_name(text) from public, anon, authenticated;
grant execute on function public.claim_name(text, text), public.submit_result(text, text, text, integer, integer, jsonb), public.join_room(text, text, text), public.create_room(text, text, text, integer, integer, jsonb), public.set_room(text, text, text, jsonb, timestamptz, integer), public.set_pick(text, text, text, text), public.best_times(integer), public.rate_game(text, text, text, text), public.set_team(text, text, text), public.player_bests(text), public.get_team(text), public.set_avatar(text, text, text), public.get_avatars(), public.send_react(text, text, text, text) to anon;

-- 3b) Freunde & Postfach (Anfragen + Einladungen, nur über PIN-geprüfte Funktionen)
create table if not exists public.friends (a text not null, b text not null, primary key (a, b));
create table if not exists public.inbox (id bigint generated always as identity primary key, to_key text not null, from_name text not null, kind text not null check (kind in ('friend', 'invite')), payload text, created timestamptz not null default now());
create table if not exists public.mutes (a text not null, b text not null, primary key (a, b));
alter table public.friends enable row level security;
alter table public.mutes enable row level security;
alter table public.inbox enable row level security;

create or replace function public.friend_request(p_name text, p_pin text, p_to text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; k text := lower(btrim(coalesce(p_to, ''))); begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); if k = me then return 'self'; end if; if not exists (select 1 from public.players where name_key = k) then return 'nf'; end if; if exists (select 1 from public.friends where a = me and b = k) then return 'already'; end if; if exists (select 1 from public.inbox where to_key = me and kind = 'friend' and lower(from_name) = k) then delete from public.inbox where to_key = me and kind = 'friend' and lower(from_name) = k; insert into public.friends values (me, k), (k, me) on conflict do nothing; return 'accepted'; end if; if exists (select 1 from public.inbox where to_key = k and kind = 'friend' and lower(from_name) = me) then return 'sent'; end if; insert into public.inbox(to_key, from_name, kind) values (k, substr(s, 4), 'friend'); return 'sent'; end $$;

create or replace function public.inbox_list(p_name text, p_pin text) returns table(id bigint, k text, f text, p text, c timestamptz) language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return; end if; update public.players set last_seen = now() where name_key = lower(substr(s, 4)); delete from public.inbox where kind = 'invite' and created < now() - interval '1 day'; return query select i.id, i.kind, i.from_name, i.payload, i.created from public.inbox i where i.to_key = lower(substr(s, 4)) order by i.created desc limit 40; end $$;

create or replace function public.inbox_answer(p_name text, p_pin text, p_id bigint, p_accept boolean) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; r public.inbox; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); select * into r from public.inbox where id = p_id and to_key = me; if not found then return 'nf'; end if; if r.kind = 'friend' and p_accept then insert into public.friends values (me, lower(r.from_name)), (lower(r.from_name), me) on conflict do nothing; end if; if r.kind = 'invite' and p_accept then delete from public.inbox where to_key = me and kind = 'invite' and id <> p_id; end if; delete from public.inbox where id = p_id; return 'ok'; end $$;

drop function if exists public.friends_list(text, text);
create or replace function public.friends_list(p_name text, p_pin text) returns table(n text, a text, s integer, m boolean) language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return; end if; return query select pl.name, pl.avatar, (extract(epoch from now() - pl.last_seen))::integer, exists (select 1 from public.mutes mu where mu.a = f.a and mu.b = f.b) from public.friends f join public.players pl on pl.name_key = f.b where f.a = lower(substr(s, 4)) order by pl.name; end $$;

create or replace function public.friend_remove(p_name text, p_pin text, p_who text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; k text := lower(btrim(coalesce(p_who, ''))); begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); delete from public.friends where (a = me and b = k) or (a = k and b = me); return 'ok'; end $$;

create or replace function public.send_invite(p_name text, p_pin text, p_to text, p_payload text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; k text := lower(btrim(coalesce(p_to, ''))); begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); if p_payload is null or p_payload !~ '^[A-Za-z0-9-]{4,30}$' then return 'invalid'; end if; if not exists (select 1 from public.friends where a = me and b = k) then return 'nofriend'; end if; if exists (select 1 from public.mutes where a = k and b = me) then return 'ok'; end if; if (select count(*) from public.inbox where to_key = k) >= 40 then return 'full'; end if; delete from public.inbox where to_key = k and kind = 'invite' and payload = p_payload and lower(from_name) = me; insert into public.inbox(to_key, from_name, kind, payload) values (k, substr(s, 4), 'invite', p_payload); return 'ok'; end $$;

create or replace function public.leave_room(p_name text, p_pin text, p_code text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; r public.rooms; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; select * into r from public.rooms where code = p_code; if not found then return 'nf'; end if; if r.stages is null or (jsonb_typeof(r.stages) = 'object' and coalesce((r.stages ->> 'r')::int, 0) = 0) then delete from public.picks where code = p_code and name = substr(s, 4); return 'ok'; end if; return 'late'; end $$;
create or replace function public.invite_state(p_name text, p_pin text, p_payload text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if exists (select 1 from public.inbox where kind = 'invite' and payload = p_payload and lower(from_name) = lower(substr(s, 4))) then return 'pending'; end if; return 'gone'; end $$;

create or replace function public.cancel_invites(p_name text, p_pin text, p_payload text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; delete from public.inbox where kind = 'invite' and payload = p_payload and lower(from_name) = lower(substr(s, 4)); return 'ok'; end $$;
create or replace function public.friend_mute(p_name text, p_pin text, p_who text, p_on boolean) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; k text := lower(btrim(coalesce(p_who, ''))); begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); if not exists (select 1 from public.friends where a = me and b = k) then return 'nofriend'; end if; if p_on then insert into public.mutes values (me, k) on conflict do nothing; else delete from public.mutes where a = me and b = k; end if; return 'ok'; end $$;
grant execute on function public.friend_mute(text, text, text, boolean) to anon, authenticated;

grant execute on function public.invite_state(text, text, text), public.cancel_invites(text, text, text) to anon, authenticated;

grant execute on function public.leave_room(text, text, text) to anon, authenticated;

grant execute on function public.friend_request(text, text, text), public.inbox_list(text, text), public.inbox_answer(text, text, bigint, boolean), public.friends_list(text, text), public.friend_remove(text, text, text), public.send_invite(text, text, text, text) to anon, authenticated;

-- 3c) EINMALIGES Leeren aller Bestenlisten (läuft nur beim ersten Ausführen dieser Datei, danach nie wieder)
create table if not exists public._once (k text primary key, done_at timestamptz not null default now());
alter table public._once enable row level security;
do $$ begin if not exists (select 1 from public._once where k = 'reset-highscores-1') then delete from public.results; delete from public.reacts; delete from public.rooms; insert into public._once(k) values ('reset-highscores-1'); end if; end $$;

-- 4) Direktes Schreiben ohne PIN sperren (alles läuft nur noch über die Funktionen oben)
do $$ declare p record; begin for p in select policyname, tablename from pg_policies where schemaname = 'public' and ((tablename in ('results', 'picks', 'rooms') and cmd = 'INSERT') or (tablename in ('picks', 'rooms') and cmd = 'UPDATE')) loop execute format('drop policy %I on public.%I', p.policyname, p.tablename); end loop; end $$;

revoke execute on function public.cleanup_old() from anon, authenticated, public;

-- 5) Aufräumen: doppelte Regel/Index entfernen
drop policy if exists "alle duerfen lesen" on public.results;
drop index if exists public.results_code_total_ms_idx;

-- 6) Zufalls-Gegner (Matchmaking für 1v1)
create table if not exists public.queue (name_key text primary key, name text not null, rounds integer not null, games jsonb not null, code text, created_at timestamptz not null default now());
alter table public.queue enable row level security;

create or replace function public.find_match(p_name text, p_pin text, p_rounds integer, p_games jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; w public.queue; c text; chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; i integer; n integer := 0; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); if p_rounds not in (1, 3, 5, 7, 10) or p_games is null or jsonb_typeof(p_games) <> 'array' or jsonb_array_length(p_games) <> p_rounds then return 'invalid'; end if; delete from public.queue where created_at < now() - interval '90 seconds'; delete from public.queue where name_key = me; select * into w from public.queue where code is null and name_key <> me and rounds = p_rounds order by created_at limit 1 for update skip locked; if found then loop n := n + 1; c := '1'; for i in 1..4 loop c := c || substr(chars, 1 + floor(random() * 32)::integer, 1); end loop; begin insert into public.rooms(code, seed, size, host, stages) values (c, (random() * 2000000000)::integer, 2, w.name, jsonb_build_object('g', w.games, 'r', 0)); exit; exception when unique_violation then if n > 6 then return 'error'; end if; end; end loop; insert into public.picks(code, name) values (c, w.name), (c, substr(s, 4)); update public.queue set code = c where name_key = w.name_key; return 'match:' || c; end if; insert into public.queue(name_key, name, rounds, games) values (me, substr(s, 4), p_rounds, p_games); return 'wait'; end $$;

create or replace function public.match_status(p_name text, p_pin text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; q public.queue; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); select * into q from public.queue where name_key = me; if not found then return 'none'; end if; if q.code is not null then delete from public.queue where name_key = me; return 'match:' || q.code; end if; if q.created_at < now() - interval '90 seconds' then delete from public.queue where name_key = me; return 'none'; end if; return 'wait'; end $$;

create or replace function public.cancel_match(p_name text, p_pin text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; q public.queue; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); select * into q from public.queue where name_key = me; if not found then return 'none'; end if; delete from public.queue where name_key = me; if q.code is not null then return 'match:' || q.code; end if; return 'ok'; end $$;

-- 7) Duell-Rangliste (ELO)
create table if not exists public.elo (name_key text primary key, name text not null, r integer not null default 1000, g integer not null default 0, w integer not null default 0);
create table if not exists public.elo_done (code text primary key, at timestamptz not null default now());
alter table public.elo enable row level security;
alter table public.elo_done enable row level security;

create or replace function public.elo_apply(p_code text) returns text language plpgsql security definer set search_path = public as $$ declare a record; b record; ea numeric; ra integer; rb integer; sa numeric; ka integer; kb integer; ga integer; gb integer; begin if p_code is null or p_code !~ '^1[A-Z0-9]{4,6}$' then return 'invalid'; end if; if exists (select 1 from public.elo_done where code = p_code) then return 'done'; end if; if (select count(distinct lower(name)) from public.results where code = p_code || '-END') <> 2 then return 'wait'; end if; select name, min(total_ms) - 500 as o into a from public.results where code = p_code || '-END' group by name order by name limit 1; select name, min(total_ms) - 500 as o into b from public.results where code = p_code || '-END' group by name order by name desc limit 1; insert into public.elo_done(code) values (p_code) on conflict do nothing; if not found then return 'done'; end if; if not ((a.o = 1 and b.o = 0) or (a.o = 0 and b.o = 1) or (a.o = 2 and b.o = 2)) then return 'bad'; end if; insert into public.elo(name_key, name) values (lower(a.name), a.name), (lower(b.name), b.name) on conflict (name_key) do nothing; select r, g into ra, ga from public.elo where name_key = lower(a.name); select r, g into rb, gb from public.elo where name_key = lower(b.name); sa := case when a.o = 1 then 1 when a.o = 0 then 0 else .5 end; ea := 1 / (1 + power(10, (rb - ra) / 400.0)); ka := case when ga < 10 then 40 else 24 end; kb := case when gb < 10 then 40 else 24 end; update public.elo set r = round(ra + ka * (sa - ea)), g = g + 1, w = w + (a.o = 1)::integer where name_key = lower(a.name); update public.elo set r = round(rb + kb * ((1 - sa) - (1 - ea))), g = g + 1, w = w + (b.o = 1)::integer where name_key = lower(b.name); return 'ok'; end $$;

create or replace function public.elo_top() returns table(n text, r integer, g integer, w integer) language sql stable security definer set search_path = public as $$ select name, r, g, w from public.elo where g > 0 order by r desc, g desc limit 20 $$;

-- 8) Saisons: wer hielt in einem Zeitraum die meisten Spiel-Bestzeiten?
create or replace function public.season_top(p_from timestamptz, p_to timestamptz) returns table(n text, c integer) language sql stable security definer set search_path = public as $$ with x as (select r.name as nm, j.key as gm, case when jsonb_typeof(j.value) = 'number' then (j.value #>> '{}')::numeric end as v from public.results r, lateral jsonb_each(case when jsonb_typeof(r.games) = 'object' then r.games else '{}'::jsonb end) j where r.code <> 'ARCADE-SOLO' and r.total_ms >= 700 and r.created_at >= p_from and r.created_at < p_to), b as (select distinct on (gm, nm) nm, gm, v from x where v >= 700 and v <= 600000 order by gm, nm, v), w as (select distinct on (gm) nm, gm from b order by gm, v) select nm, count(*)::integer from w group by nm order by 2 desc, 1 limit 10 $$;

-- 9) Aufräumen: alte Reste täglich löschen
create or replace function public.cleanup_old() returns text language plpgsql security definer set search_path = public as $$ begin delete from public.rooms where created_at < now() - interval '1 day'; delete from public.reacts where created_at < now() - interval '1 day'; delete from public.inbox where kind = 'invite' and created < now() - interval '1 day'; delete from public.inbox where kind = 'friend' and created < now() - interval '30 days'; delete from public.queue where created_at < now() - interval '10 minutes'; return 'ok'; end $$;
do $$ begin create extension if not exists pg_cron; perform cron.unschedule('bb-cleanup'); exception when others then null; end $$;
do $$ begin perform cron.schedule('bb-cleanup', '17 3 * * *', 'select public.cleanup_old()'); exception when others then raise notice 'pg_cron nicht verfügbar: %', sqlerrm; end $$;

grant execute on function public.find_match(text, text, integer, jsonb), public.match_status(text, text), public.cancel_match(text, text), public.elo_apply(text), public.elo_top(), public.season_top(timestamptz, timestamptz) to anon, authenticated;

-- 10) Elo: Paar-Limit (max. 3 gewertete Duelle pro Paar in 24 h) + eigener Rang
alter table public.elo_done add column if not exists pair text;
create or replace function public.elo_apply(p_code text) returns text language plpgsql security definer set search_path = public as $$ declare a record; b record; ea numeric; ra integer; rb integer; sa numeric; ka integer; kb integer; ga integer; gb integer; pr text; begin if p_code is null or p_code !~ '^1[A-Z0-9]{4,7}$' then return 'invalid'; end if; if exists (select 1 from public.elo_done where code = p_code) then return 'done'; end if; if (select count(distinct lower(name)) from public.results where code = p_code || '-END') <> 2 then return 'wait'; end if; select name, min(total_ms) - 500 as o into a from public.results where code = p_code || '-END' group by name order by name limit 1; select name, min(total_ms) - 500 as o into b from public.results where code = p_code || '-END' group by name order by name desc limit 1; if not ((a.o = 1 and b.o = 0) or (a.o = 0 and b.o = 1) or (a.o = 2 and b.o = 2)) then return 'bad'; end if; pr := lower(a.name) || '|' || lower(b.name); insert into public.elo_done(code, pair) values (p_code, pr) on conflict do nothing; if not found then return 'done'; end if; if (select count(*) from public.elo_done where pair = pr and at > now() - interval '24 hours' and code <> p_code and pair is not null) >= 3 then update public.elo_done set pair = pr || '!' where code = p_code; return 'limit'; end if; insert into public.elo(name_key, name) values (lower(a.name), a.name), (lower(b.name), b.name) on conflict (name_key) do nothing; select r, g into ra, ga from public.elo where name_key = lower(a.name); select r, g into rb, gb from public.elo where name_key = lower(b.name); sa := case when a.o = 1 then 1 when a.o = 0 then 0 else .5 end; ea := 1 / (1 + power(10, (rb - ra) / 400.0)); ka := case when ga < 10 then 40 else 24 end; kb := case when gb < 10 then 40 else 24 end; update public.elo set r = round(ra + ka * (sa - ea)), g = g + 1, w = w + (a.o = 1)::integer where name_key = lower(a.name); update public.elo set r = round(rb + kb * ((1 - sa) - (1 - ea))), g = g + 1, w = w + (b.o = 1)::integer where name_key = lower(b.name); return 'ok'; end $$;
create or replace function public.elo_rank(p_name text) returns table(r integer, g integer, w integer, pos integer) language sql stable security definer set search_path = public as $$ select e.r, e.g, e.w, (select count(*)::integer + 1 from public.elo x where x.g > 0 and (x.r > e.r or (x.r = e.r and x.g > e.g))) from public.elo e where e.name_key = lower(p_name) and e.g > 0 $$;
grant execute on function public.elo_apply(text), public.elo_rank(text) to anon, authenticated;
-- 11) Ranked: Raum-Markierung, Elo-Ergebnis je Duell, Aufgabe-Sieg, Elo-nahes Matching
create table if not exists public.ranked_rooms (code text primary key, created_at timestamptz not null default now());
alter table public.ranked_rooms enable row level security;
alter table public.elo_done add column if not exists res jsonb;

create or replace function public.elo_apply(p_code text) returns text language plpgsql security definer set search_path = public as $$ declare a record; b record; ea numeric; ra integer; rb integer; sa numeric; ka integer; kb integer; ga integer; gb integer; pr text; na integer; nb integer; begin if p_code is null or p_code !~ '^1[A-Z0-9]{4,7}$' then return 'invalid'; end if; if exists (select 1 from public.elo_done where code = p_code) then return 'done'; end if; if (select count(distinct lower(name)) from public.results where code = p_code || '-END') <> 2 then return 'wait'; end if; select name, min(total_ms) - 500 as o into a from public.results where code = p_code || '-END' group by name order by name limit 1; select name, min(total_ms) - 500 as o into b from public.results where code = p_code || '-END' group by name order by name desc limit 1; if not ((a.o = 1 and b.o = 0) or (a.o = 0 and b.o = 1) or (a.o = 2 and b.o = 2)) then return 'bad'; end if; pr := lower(a.name) || '|' || lower(b.name); insert into public.elo_done(code, pair) values (p_code, pr) on conflict do nothing; if not found then return 'done'; end if; if (select count(*) from public.elo_done where pair = pr and at > now() - interval '24 hours' and code <> p_code and pair is not null) >= 3 then update public.elo_done set pair = pr || '!', res = jsonb_build_object('limit', true) where code = p_code; return 'limit'; end if; insert into public.elo(name_key, name) values (lower(a.name), a.name), (lower(b.name), b.name) on conflict (name_key) do nothing; select r, g into ra, ga from public.elo where name_key = lower(a.name); select r, g into rb, gb from public.elo where name_key = lower(b.name); sa := case when a.o = 1 then 1 when a.o = 0 then 0 else .5 end; ea := 1 / (1 + power(10, (rb - ra) / 400.0)); ka := case when ga < 10 then 40 else 24 end; kb := case when gb < 10 then 40 else 24 end; na := round(ra + ka * (sa - ea)); nb := round(rb + kb * ((1 - sa) - (1 - ea))); update public.elo set r = na, g = g + 1, w = w + (a.o = 1)::integer where name_key = lower(a.name); update public.elo set r = nb, g = g + 1, w = w + (b.o = 1)::integer where name_key = lower(b.name); update public.elo_done set res = jsonb_build_object(lower(a.name), jsonb_build_object('d', na - ra, 'r', na), lower(b.name), jsonb_build_object('d', nb - rb, 'r', nb)) where code = p_code; return 'ok'; end $$;

create or replace function public.elo_result(p_code text, p_name text) returns table(d integer, r integer, lim boolean) language sql stable security definer set search_path = public as $$ select coalesce((res -> lower(p_name) ->> 'd')::integer, 0), coalesce((res -> lower(p_name) ->> 'r')::integer, 0), coalesce((res ->> 'limit')::boolean, false) from public.elo_done where code = p_code and res is not null $$;

create or replace function public.forfeit(p_name text, p_pin text, p_code text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; op text; r public.rooms; rd integer; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := substr(s, 4); if not exists (select 1 from public.ranked_rooms where code = p_code) then return 'no'; end if; select * into r from public.rooms where code = p_code; if not found then return 'no'; end if; if exists (select 1 from public.results where code = p_code || '-END') or exists (select 1 from public.elo_done where code = p_code) then return 'no'; end if; if not exists (select 1 from public.picks where code = p_code and name = me) then return 'no'; end if; select name into op from public.picks where code = p_code and name <> me and name not like 'ok-%' limit 1; if op is null then return 'no'; end if; rd := coalesce((r.stages ->> 'r')::integer, 0); if rd < 1 then return 'no'; end if; if not exists (select 1 from public.results where code = p_code || '-R' || rd and lower(name) = lower(me) and created_at < now() - interval '90 seconds') then return 'early'; end if; if exists (select 1 from public.results where code = p_code || '-R' || rd and lower(name) = lower(op)) then return 'no'; end if; insert into public.results(code, name, total_ms, pen_ms, games) values (p_code || '-END', me, 501, 0, '{}'), (p_code || '-END', op, 500, 0, '{}'); perform public.elo_apply(p_code); return 'ok'; end $$;

create or replace function public.find_match(p_name text, p_pin text, p_rounds integer, p_games jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; w public.queue; c text; chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; i integer; n integer := 0; myr integer; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); if p_rounds not in (1, 3, 5, 7, 10) or p_games is null or jsonb_typeof(p_games) <> 'array' or jsonb_array_length(p_games) <> p_rounds then return 'invalid'; end if; delete from public.queue where created_at < now() - interval '90 seconds'; delete from public.queue where name_key = me; select coalesce((select r from public.elo where name_key = me), 1000) into myr; select q.* into w from public.queue q left join public.elo e on e.name_key = q.name_key where q.code is null and q.name_key <> me and q.rounds = p_rounds order by abs(coalesce(e.r, 1000) - myr), q.created_at limit 1 for update of q skip locked; if found then loop n := n + 1; c := '1'; for i in 1..4 loop c := c || substr(chars, 1 + floor(random() * 32)::integer, 1); end loop; begin insert into public.rooms(code, seed, size, host, stages) values (c, (random() * 2000000000)::integer, 2, w.name, jsonb_build_object('g', w.games, 'r', 0)); exit; exception when unique_violation then if n > 6 then return 'error'; end if; end; end loop; insert into public.picks(code, name) values (c, w.name), (c, substr(s, 4)); insert into public.ranked_rooms(code) values (c) on conflict do nothing; update public.queue set code = c where name_key = w.name_key; return 'match:' || c; end if; insert into public.queue(name_key, name, rounds, games) values (me, substr(s, 4), p_rounds, p_games); return 'wait'; end $$;

create or replace function public.cleanup_old() returns text language plpgsql security definer set search_path = public as $$ begin delete from public.rooms where created_at < now() - interval '1 day'; delete from public.reacts where created_at < now() - interval '1 day'; delete from public.inbox where kind = 'invite' and created < now() - interval '1 day'; delete from public.inbox where kind = 'friend' and created < now() - interval '30 days'; delete from public.queue where created_at < now() - interval '10 minutes'; delete from public.ranked_rooms where created_at < now() - interval '2 days'; return 'ok'; end $$;
revoke execute on function public.cleanup_old() from anon, authenticated, public;

grant execute on function public.elo_apply(text), public.elo_result(text, text), public.forfeit(text, text, text), public.find_match(text, text, integer, jsonb) to anon, authenticated;

-- 12) Push-Benachrichtigungen (Tabellen, RPCs, Trigger). Die Edge Function "push" erzeugt ihre Schlüssel selbst.
create extension if not exists pg_net with schema extensions;
create table if not exists public.push_cfg (k text primary key, v text not null);
alter table public.push_cfg enable row level security;
insert into public.push_cfg(k, v) values ('hook', gen_random_uuid()::text || gen_random_uuid()::text) on conflict do nothing;
create table if not exists public.push_subs (endpoint text primary key, name_key text not null, p256dh text not null, auth text not null, created_at timestamptz not null default now());
create index if not exists push_subs_name_idx on public.push_subs (name_key);
alter table public.push_subs enable row level security;
create or replace function public.save_push(p_name text, p_pin text, p_sub jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; ep text; k1 text; k2 text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; ep := p_sub ->> 'endpoint'; k1 := p_sub -> 'keys' ->> 'p256dh'; k2 := p_sub -> 'keys' ->> 'auth'; if ep is null or k1 is null or k2 is null or char_length(ep) > 600 or ep !~ '^https://' then return 'invalid'; end if; delete from public.push_subs where name_key = lower(substr(s, 4)) and endpoint <> ep and created_at < now() - interval '60 days'; insert into public.push_subs(endpoint, name_key, p256dh, auth) values (ep, lower(substr(s, 4)), k1, k2) on conflict (endpoint) do update set name_key = excluded.name_key, p256dh = excluded.p256dh, auth = excluded.auth, created_at = now(); return 'ok'; end $$;
create or replace function public.drop_push(p_name text, p_pin text, p_endpoint text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; delete from public.push_subs where endpoint = p_endpoint and name_key = lower(substr(s, 4)); return 'ok'; end $$;
create or replace function public.inbox_push() returns trigger language plpgsql security definer set search_path = public, extensions as $$ declare h text; begin if not exists (select 1 from public.push_subs where name_key = lower(new.to_key)) then return new; end if; select v into h from public.push_cfg where k = 'hook'; perform net.http_post(url := 'https://hiweloxyqbjemegabfdz.supabase.co/functions/v1/push', headers := jsonb_build_object('Content-Type', 'application/json', 'x-hook', h), body := jsonb_build_object('to', lower(new.to_key), 'from', new.from_name, 'kind', new.kind)); return new; exception when others then return new; end $$;
drop trigger if exists inbox_push_trg on public.inbox;
create trigger inbox_push_trg after insert on public.inbox for each row execute function public.inbox_push();
revoke execute on function public.inbox_push() from anon, authenticated, public;
grant execute on function public.save_push(text, text, jsonb), public.drop_push(text, text, text) to anon, authenticated;

-- 13) Manipulationsschutz, Gewinnserie, Ranked-Saisons, Liga-Liste
create or replace function public.submit_result(p_name text, p_pin text, p_code text, p_total integer, p_pen integer, p_games jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; tt integer := p_total; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if (select count(*) from public.results where name = substr(s, 4) and created_at > now() - interval '60 seconds') >= 40 then return 'rate'; end if; if p_code not like '%-END' and tt < 700 then if p_code ~ '-R[0-9]+$' then tt := 700; else return 'implausible'; end if; end if; insert into public.results(code, name, total_ms, pen_ms, games) values (p_code, substr(s, 4), tt, p_pen, coalesce(p_games, '{}'::jsonb)); return 'ok'; end $$;

alter table public.elo add column if not exists ws integer not null default 0;

create or replace function public.elo_apply(p_code text) returns text language plpgsql security definer set search_path = public as $$ declare a record; b record; oa integer; ob integer; ea numeric; ra integer; rb integer; sa numeric; ka integer; kb integer; ga integer; gb integer; wsa integer; wsb integer; pr text; na integer; nb integer; ba integer := 0; bb integer := 0; n integer; i integer; ta integer; tb integer; wa integer := 0; wb integer := 0; xa bigint := 0; xb bigint := 0; ok boolean := true; begin if p_code is null or p_code !~ '^1[A-Z0-9]{4,7}$' then return 'invalid'; end if; if exists (select 1 from public.elo_done where code = p_code) then return 'done'; end if; if (select count(distinct lower(name)) from public.results where code = p_code || '-END') <> 2 then return 'wait'; end if; select name, min(total_ms) - 500 as o into a from public.results where code = p_code || '-END' group by name order by name limit 1; select name, min(total_ms) - 500 as o into b from public.results where code = p_code || '-END' group by name order by name desc limit 1; oa := a.o; ob := b.o; select jsonb_array_length(stages -> 'g') into n from public.rooms where code = p_code and jsonb_typeof(stages -> 'g') = 'array'; if n is not null and n > 0 then for i in 1..n loop select min(total_ms) into ta from public.results where code = p_code || '-R' || i and lower(name) = lower(a.name); select min(total_ms) into tb from public.results where code = p_code || '-R' || i and lower(name) = lower(b.name); if ta is null or tb is null then ok := false; exit; end if; if ta < tb then wa := wa + 1; elsif tb < ta then wb := wb + 1; end if; xa := xa + ta; xb := xb + tb; end loop; if ok then oa := case when wa > wb then 1 when wb > wa then 0 when xa < xb then 1 when xb < xa then 0 else 2 end; ob := case oa when 1 then 0 when 0 then 1 else 2 end; end if; end if; if not ((oa = 1 and ob = 0) or (oa = 0 and ob = 1) or (oa = 2 and ob = 2)) then return 'bad'; end if; pr := lower(a.name) || '|' || lower(b.name); insert into public.elo_done(code, pair) values (p_code, pr) on conflict do nothing; if not found then return 'done'; end if; if (select count(*) from public.elo_done where pair = pr and at > now() - interval '24 hours' and code <> p_code and pair is not null) >= 3 then update public.elo_done set pair = pr || '!', res = jsonb_build_object('limit', true) where code = p_code; return 'limit'; end if; insert into public.elo(name_key, name) values (lower(a.name), a.name), (lower(b.name), b.name) on conflict (name_key) do nothing; select r, g, ws into ra, ga, wsa from public.elo where name_key = lower(a.name); select r, g, ws into rb, gb, wsb from public.elo where name_key = lower(b.name); sa := case when oa = 1 then 1 when oa = 0 then 0 else .5 end; ea := 1 / (1 + power(10, (rb - ra) / 400.0)); ka := case when ga < 10 then 40 else 24 end; kb := case when gb < 10 then 40 else 24 end; wsa := case when oa = 1 then wsa + 1 when oa = 0 then 0 else wsa end; wsb := case when ob = 1 then wsb + 1 when ob = 0 then 0 else wsb end; if oa = 1 and wsa >= 3 then ba := least(10, (wsa - 2) * 3); end if; if ob = 1 and wsb >= 3 then bb := least(10, (wsb - 2) * 3); end if; na := round(ra + ka * (sa - ea)) + ba; nb := round(rb + kb * ((1 - sa) - (1 - ea))) + bb; update public.elo set r = na, g = g + 1, w = w + (oa = 1)::integer, ws = wsa where name_key = lower(a.name); update public.elo set r = nb, g = g + 1, w = w + (ob = 1)::integer, ws = wsb where name_key = lower(b.name); update public.elo_done set res = jsonb_build_object(lower(a.name), jsonb_build_object('d', na - ra, 'r', na, 'ws', wsa, 'b', ba), lower(b.name), jsonb_build_object('d', nb - rb, 'r', nb, 'ws', wsb, 'b', bb)) where code = p_code; return 'ok'; end $$;

drop function if exists public.elo_result(text, text);
create or replace function public.elo_result(p_code text, p_name text) returns table(d integer, r integer, lim boolean, ws integer, b integer) language sql stable security definer set search_path = public as $$ select coalesce((res -> lower(p_name) ->> 'd')::integer, 0), coalesce((res -> lower(p_name) ->> 'r')::integer, 0), coalesce((res ->> 'limit')::boolean, false), coalesce((res -> lower(p_name) ->> 'ws')::integer, 0), coalesce((res -> lower(p_name) ->> 'b')::integer, 0) from public.elo_done where code = p_code and res is not null $$;

create or replace function public.elo_map() returns table(n text, r integer) language sql stable security definer set search_path = public as $$ select name, r from public.elo where g > 0 order by r desc limit 1000 $$;

create or replace function public.cur_season() returns integer language sql stable as $$ select floor(extract(epoch from (now() - timestamptz '2026-11-08 23:00:00+00')) / (28 * 86400))::integer + 1 $$;

create table if not exists public.elo_meta (k text primary key, v text not null);
create table if not exists public.elo_season (season integer not null, name_key text not null, name text not null, r integer not null, pos integer not null, primary key (season, name_key));
alter table public.elo_meta enable row level security;
alter table public.elo_season enable row level security;

create or replace function public.elo_rollover() returns text language plpgsql security definer set search_path = public as $$ declare cs integer := public.cur_season(); lastn integer; begin select v::integer into lastn from public.elo_meta where k = 'season'; if lastn is null then insert into public.elo_meta values ('season', cs::text) on conflict (k) do nothing; return 'init'; end if; if cs <= lastn then return 'same'; end if; insert into public.elo_season(season, name_key, name, r, pos) select lastn, name_key, name, r, (row_number() over (order by r desc, g desc))::integer from public.elo where g > 0 on conflict do nothing; update public.elo set r = round(1000 + (r - 1000) * 0.5), ws = 0 where g > 0; update public.elo_meta set v = cs::text where k = 'season'; return 'rolled'; end $$;

create or replace function public.elo_hall(p_name text) returns table(season integer, pos integer) language sql stable security definer set search_path = public as $$ select season, pos from public.elo_season where name_key = lower(p_name) and pos <= 3 order by season $$;
create or replace function public.elo_season_top(p_season integer) returns table(n text, r integer, pos integer) language sql stable security definer set search_path = public as $$ select name, r, pos from public.elo_season where season = p_season and pos <= 3 order by pos $$;

create or replace function public.cleanup_old() returns text language plpgsql security definer set search_path = public as $$ begin delete from public.rooms where created_at < now() - interval '1 day'; delete from public.reacts where created_at < now() - interval '1 day'; delete from public.inbox where kind = 'invite' and created < now() - interval '1 day'; delete from public.inbox where kind = 'friend' and created < now() - interval '30 days'; delete from public.queue where created_at < now() - interval '10 minutes'; delete from public.ranked_rooms where created_at < now() - interval '2 days'; perform public.elo_rollover(); return 'ok'; end $$;
revoke execute on function public.cleanup_old() from anon, authenticated, public;
revoke execute on function public.elo_rollover() from anon, authenticated, public;
grant execute on function public.submit_result(text, text, text, integer, integer, jsonb), public.elo_apply(text), public.elo_result(text, text), public.elo_map(), public.elo_hall(text), public.elo_season_top(integer) to anon, authenticated;
select public.elo_rollover();

-- 14) Räume bis 10 Spieler
alter table public.rooms drop constraint if exists rooms_size_check;
alter table public.rooms add constraint rooms_size_check check (size between 2 and 10);
create or replace function public.create_room(p_name text, p_pin text, p_code text, p_seed integer, p_size integer, p_stages jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if char_length(coalesce(p_code, '')) not between 4 and 8 or p_size not between 2 and 10 then return 'invalid'; end if; insert into public.rooms(code, seed, size, host, stages) values (p_code, p_seed, p_size, substr(s, 4), p_stages); return 'ok'; exception when unique_violation then return 'exists'; end $$;
grant execute on function public.create_room(text, text, text, integer, integer, jsonb) to anon, authenticated;

-- 15) Free-for-All-Modus (7 Spiele, Spielwahl per Abstimmung im Raum)
create table if not exists public.ffa (code text primary key check (char_length(code) between 4 and 8), host text not null, game text not null check (game in ('flask','dobble','minor','kartoffel','sprint','einzig','zaehl','zwei3','merk','reaktion')), rounds integer not null default 8, phase text not null default 'lobby', rnd integer not null default 0, tp bigint not null default 0, st jsonb not null default '{}', pl jsonb not null default '{}', created_at timestamptz not null default now());
alter table public.ffa enable row level security;
create or replace function public._fnow() returns bigint language sql as $$ select (extract(epoch from clock_timestamp()) * 1000)::bigint $$;

alter table public.ffa drop constraint if exists ffa_game_check;
alter table public.ffa add constraint ffa_game_check check (game in ('flask','dobble','minor','kartoffel','sprint','einzig','zaehl','zwei3','merk','reaktion'));
alter table public.ffa add column if not exists tm jsonb;
alter table public.ffa add column if not exists cf jsonb not null default '{}';

create or replace function public._ffa_games() returns text[] language sql immutable as $$ select array['flask','dobble','minor','kartoffel','sprint','einzig','zaehl','zwei3','merk','reaktion'] $$;
create or replace function public._ffa_bd(g text) returns bigint language sql immutable as $$ select case g when 'flask' then 2800 when 'dobble' then 2400 when 'kartoffel' then 3000 when 'sprint' then 4500 when 'zaehl' then 5000 when 'zwei3' then 5000 when 'merk' then 4000 when 'reaktion' then 3200 else 4200 end::bigint $$;
create or replace function public._ffa_pt(g text) returns bigint language sql immutable as $$ select case g when 'dobble' then 12000 when 'minor' then 10000 when 'einzig' then 10000 when 'zaehl' then 15000 when 'zwei3' then 12000 when 'sprint' then 8000 else null end::bigint $$;

create or replace function public._ffa_round(r public.ffa) returns public.ffa language plpgsql set search_path = public as $$
declare t bigint := public._fnow(); n text; i integer; al text[]; nb integer; bs jsonb := '[]'; c text[]; rest text[]; card text[]; k jsonb := '{}';
 onl text[]; h text; tg text; nn integer; oth text[]; sq jsonb;
 pool text[] := array['🐶','🐱','🦊','🐸','🐵','🦁','🐼','🐙','🦄','🐢','🍎','🍕','🍩','🚗','⚽','🎸','🌵','🔥','💎','🎈','🚀','🌈','🍀','👻','🤖','🎃','🍔','🐝','🦋','🍉'];
 fr text[] := array['🍎','🍌','🍇','🍓','🍋','🍒'];
begin
 r.rnd := r.rnd + 1; r.phase := 'play'; r.tp := t;
 onl := array(select key from jsonb_each(r.pl) where (value->>'seen')::bigint > t - 15000);
 if r.game = 'flask' then
  select coalesce(array_agg(key order by key), '{}') into al from jsonb_each(r.pl) where (value->>'out') is null;
  nb := greatest(coalesce(array_length(al, 1), 0) - 1, 1);
  for i in 1..nb loop bs := bs || jsonb_build_object('o', null, 't', 0); end loop;
  r.st := jsonb_build_object('al', to_jsonb(al), 'b', bs, 'end', t + 5000 + (random() * 6000)::integer, 'last', '[]'::jsonb);
 elsif r.game = 'dobble' then
  select array_agg(x) into c from (select x from unnest(pool) x order by random() limit 6) q;
  select array_agg(x) into rest from unnest(pool) x where x <> all(c);
  for n in select key from jsonb_each(r.pl) loop
   select array_agg(x order by random()) into card from (select x from (select x from unnest(rest) x order by random() limit 5) a union all select c[1 + floor(random() * 6)::integer]) b;
   k := k || jsonb_build_object(n, to_jsonb(card));
  end loop;
  r.st := jsonb_build_object('c', to_jsonb(c), 'k', k, 'w', null, 'lk', '{}'::jsonb);
 elsif r.game = 'kartoffel' then
  h := case when cardinality(onl) > 0 then onl[1 + floor(random() * cardinality(onl))::integer] else null end;
  r.st := jsonb_build_object('h', h, 'from', null, 'pt', t, 'end', t + 8000 + (random() * 9000)::integer);
 elsif r.game = 'sprint' then
  r.st := jsonb_build_object('go', t + 2000, 'c', '{}'::jsonb);
 elsif r.game = 'einzig' then
  r.st := jsonb_build_object('p', '{}'::jsonb, 'k', least(12, greatest(5, cardinality(onl) + 3)));
 elsif r.game = 'zaehl' then
  tg := fr[1 + floor(random() * 6)::integer];
  oth := array_remove(fr, tg);
  nn := 4 + floor(random() * 11)::integer;
  select array_agg(x order by random()) into card from (select tg x from generate_series(1, nn) union all select oth[1 + floor(random() * 5)::integer] from generate_series(1, 30 - nn)) q;
  r.st := jsonb_build_object('cells', to_jsonb(card), 'tg', tg, 'n', nn, 'p', '{}'::jsonb);
 elsif r.game = 'merk' then
  nn := least(2 + r.rnd, 12);
  select jsonb_agg(floor(random() * 4)::integer) into sq from generate_series(1, nn);
  r.st := jsonb_build_object('sq', sq, 'sh', nn * 700 + 800, 'pos', '{}'::jsonb, 'dn', '{}'::jsonb, 'end', t + nn * 700 + 800 + 12000);
 elsif r.game = 'reaktion' then
  r.st := jsonb_build_object('go', t + 2500 + (random() * 4500)::integer, 'w', null, 'lk', '{}'::jsonb);
 else
  r.st := jsonb_build_object('p', '{}'::jsonb);
 end if;
 return r;
end $$;

-- Spielende: normal 'done'; im Mini-Turnier Punkte nach Platz und weiter zum naechsten Spiel
create or replace function public._ffa_fin(r public.ffa) returns public.ffa language plpgsql set search_path = public as $$
declare t bigint := public._fnow(); x text; cnt integer; pts integer; gp jsonb := '{}'; tot jsonb; q text[]; i integer;
begin
 if r.tm is null then r.phase := 'done'; r.tp := t; return r; end if;
 tot := coalesce(r.tm->'tot', '{}'::jsonb);
 for x in select key from jsonb_each(r.pl) loop
  select count(*) into cnt from jsonb_each(r.pl) where (value->>'s')::integer > (r.pl->x->>'s')::integer;
  pts := greatest(0, 3 - cnt);
  gp := gp || jsonb_build_object(x, pts);
  tot := jsonb_set(tot, array[x], to_jsonb(coalesce((tot->>x)::integer, 0) + pts), true);
 end loop;
 i := (r.tm->>'i')::integer; q := array(select jsonb_array_elements_text(r.tm->'q'));
 r.tm := r.tm || jsonb_build_object('tot', tot);
 r.tp := t;
 if i + 1 < cardinality(q) then
  r.phase := 'inter'; r.st := jsonb_build_object('gp', gp, 'tot', tot, 'g', r.game, 'next', q[i + 2]);
 else
  select jsonb_object_agg(key, ((value - 'out') - 'w') || jsonb_build_object('s', coalesce((tot->>key)::integer, 0))) into r.pl from jsonb_each(r.pl);
  r.phase := 'done'; r.st := jsonb_build_object('tmfin', true);
 end if;
 return r;
end $$;

create or replace function public._ffa_next(r public.ffa) returns public.ffa language plpgsql set search_path = public as $$
declare t bigint := public._fnow(); q text[]; i integer;
begin
 q := array(select jsonb_array_elements_text(r.tm->'q')); i := (r.tm->>'i')::integer + 1;
 r.tm := r.tm || jsonb_build_object('i', i);
 r.game := q[i + 1]; r.rounds := (r.tm->>'rn')::integer;
 select jsonb_object_agg(key, jsonb_build_object('s', 0, 'seen', (value->>'seen')::bigint, 'tk', value->>'tk')) into r.pl from jsonb_each(r.pl);
 r.rnd := 0; r.phase := 'intro'; r.tp := t; r.st := jsonb_build_object('vote', '{}'::jsonb);
 return r;
end $$;

create or replace function public._ffa_tick(r public.ffa) returns public.ffa language plpgsql set search_path = public as $$
declare t bigint := public._fnow(); i integer := 0; hold text[]; al text[]; outs text[]; cnt integer; x text; y text; onl text[]; picked text[]; minc integer; nopt integer; mn integer; mx integer; nn integer; wins text[]; counts jsonb; resj jsonb; av numeric; tgn numeric; md numeric;
begin
 loop
  i := i + 1; exit when i > 4;
  exit when r.phase in ('lobby', 'done');
  if r.phase = 'intro' then
   exit when t - r.tp < 5000;
   r := public._ffa_round(r);
  elsif r.phase = 'inter' then
   exit when t - r.tp < 6000;
   r := public._ffa_next(r);
  elsif r.phase = 'play' then
   if r.game = 'flask' then
    exit when t < (r.st->>'end')::bigint;
    select coalesce(array_agg(distinct b->>'o') filter (where b->>'o' is not null), '{}') into hold from jsonb_array_elements(r.st->'b') b;
    if cardinality(hold) = 0 then r := public._ffa_round(r); continue; end if;
    al := array(select jsonb_array_elements_text(r.st->'al'));
    outs := array(select y2 from unnest(al) y2 where y2 <> all(hold));
    select count(*) into cnt from jsonb_each(r.pl) where (value->>'out') is not null;
    foreach x in array outs loop r.pl := jsonb_set(r.pl, array[x], (r.pl->x) || jsonb_build_object('out', cnt + 1, 's', cnt)); end loop;
    if cardinality(al) - cardinality(outs) <= 1 then
     foreach x in array hold loop r.pl := jsonb_set(r.pl, array[x], (r.pl->x) || jsonb_build_object('s', cnt + cardinality(outs), 'w', true)); end loop;
     r.st := r.st || jsonb_build_object('last', to_jsonb(outs));
     r := public._ffa_fin(r);
    else
     r.phase := 'between'; r.tp := t; r.st := r.st || jsonb_build_object('last', to_jsonb(outs), 'al', to_jsonb(array(select y2 from unnest(al) y2 where y2 = any(hold))));
    end if;
   elsif r.game = 'dobble' then
    exit when t - r.tp <= 12000;
    r.phase := 'between'; r.tp := t;
   elsif r.game = 'kartoffel' then
    exit when t < (r.st->>'end')::bigint;
    x := r.st->>'h';
    for y in select key from jsonb_each(r.pl) where key is distinct from x loop
     r.pl := jsonb_set(r.pl, array[y, 's'], to_jsonb((r.pl->y->>'s')::integer + 1));
    end loop;
    r.st := r.st || jsonb_build_object('boom', x);
    r.phase := 'between'; r.tp := t;
   elsif r.game = 'sprint' then
    exit when t < r.tp + 8700;
    select max(value::integer) into mx from jsonb_each_text(r.st->'c');
    wins := '{}'::text[];
    if mx is not null and mx > 0 then
     wins := array(select key from jsonb_each_text(r.st->'c') where value::integer = mx);
     foreach x in array wins loop r.pl := jsonb_set(r.pl, array[x, 's'], to_jsonb((r.pl->x->>'s')::integer + 1)); end loop;
    end if;
    r.st := r.st || jsonb_build_object('res', jsonb_build_object('win', to_jsonb(wins), 'max', coalesce(mx, 0)));
    r.phase := 'between'; r.tp := t;
   elsif r.game = 'merk' then
    onl := array(select key from jsonb_each(r.pl) where (value->>'seen')::bigint > t - 15000);
    exit when t < (r.st->>'end')::bigint and exists (select 1 from unnest(onl) y2 where coalesce((r.st->'pos'->>y2)::integer, 0) >= 0 and not ((r.st->'dn') ? y2));
    wins := array(select key from jsonb_each_text(r.st->'dn') order by value::bigint);
    foreach x in array wins loop r.pl := jsonb_set(r.pl, array[x, 's'], to_jsonb((r.pl->x->>'s')::integer + 1)); end loop;
    if cardinality(wins) > 0 then x := wins[1]; r.pl := jsonb_set(r.pl, array[x, 's'], to_jsonb((r.pl->x->>'s')::integer + 1)); end if;
    r.st := r.st || jsonb_build_object('res', jsonb_build_object('ord', to_jsonb(wins)));
    r.phase := 'between'; r.tp := t;
   elsif r.game = 'reaktion' then
    exit when t < (r.st->>'go')::bigint + 6000;
    r.phase := 'between'; r.tp := t;
   else
    onl := array(select key from jsonb_each(r.pl) where (value->>'seen')::bigint > t - 15000);
    picked := array(select jsonb_object_keys(r.st->'p'));
    exit when t - r.tp <= public._ffa_pt(r.game) and not (cardinality(picked) > 0 and not exists (select 1 from unnest(onl) y2 where y2 <> all(picked)));
    wins := '{}'::text[];
    select jsonb_object_agg(o, c), min(c), count(*) into counts, minc, nopt from (select value as o, count(*) as c from jsonb_each_text(r.st->'p') group by value) q;
    if r.game = 'minor' then
     if nopt > 1 then wins := array(select key from jsonb_each_text(r.st->'p') where value in (select value from jsonb_each_text(r.st->'p') group by value having count(*) = minc)); end if;
     resj := jsonb_build_object('counts', coalesce(counts, '{}'::jsonb), 'win', to_jsonb(wins));
    elsif r.game = 'einzig' then
     select min(value::integer) into mn from jsonb_each_text(r.st->'p') where value in (select value from jsonb_each_text(r.st->'p') group by value having count(*) = 1);
     if mn is not null then wins := array(select key from jsonb_each_text(r.st->'p') where value::integer = mn); end if;
     resj := jsonb_build_object('counts', coalesce(counts, '{}'::jsonb), 'win', to_jsonb(wins), 'n', mn);
    elsif r.game = 'zwei3' then
     select avg(value::numeric) into av from jsonb_each_text(r.st->'p');
     if av is not null then
      tgn := av * 2 / 3;
      select min(abs(value::numeric - tgn)) into md from jsonb_each_text(r.st->'p');
      wins := array(select key from jsonb_each_text(r.st->'p') where abs(value::numeric - tgn) = md);
     end if;
     resj := jsonb_build_object('avg', round(coalesce(av, 0), 1), 'tg', round(coalesce(tgn, 0), 1), 'win', to_jsonb(wins));
    else
     nn := (r.st->>'n')::integer;
     select min(abs(value::integer - nn)) into mn from jsonb_each_text(r.st->'p');
     if mn is not null then wins := array(select key from jsonb_each_text(r.st->'p') where abs(value::integer - nn) = mn); end if;
     resj := jsonb_build_object('n', nn, 'win', to_jsonb(wins));
    end if;
    foreach x in array wins loop r.pl := jsonb_set(r.pl, array[x, 's'], to_jsonb((r.pl->x->>'s')::integer + 1)); end loop;
    r.st := r.st || jsonb_build_object('res', resj);
    r.phase := 'between'; r.tp := t;
   end if;
  elsif r.phase = 'between' then
   exit when t - r.tp < public._ffa_bd(r.game);
   if r.game <> 'flask' and r.rnd >= r.rounds then r := public._ffa_fin(r); exit; end if;
   r := public._ffa_round(r);
  end if;
 end loop;
 return r;
end $$;

create or replace function public._ffa_view(r public.ffa, me text) returns jsonb language plpgsql set search_path = public as $$
declare t bigint := public._fnow(); pl jsonb; st jsonb := '{}'; lft bigint; tot bigint; live boolean := r.phase in ('play', 'between', 'done');
begin
 select coalesce(jsonb_agg(jsonb_build_object('n', key, 's', coalesce((value->>'s')::integer, 0), 'on', (value->>'seen')::bigint > t - 15000, 'out', value->'out', 'w', coalesce((value->>'w')::boolean, false), 'rx', case when t - coalesce((value->>'rt')::bigint, 0) < 3000 then value->>'rx' end) order by coalesce((value->>'s')::integer, 0) desc, key), '[]') into pl from jsonb_each(r.pl);
 if r.phase = 'lobby' then
  st := jsonb_build_object('vt', (select coalesce(jsonb_object_agg(g, c), '{}'::jsonb) from (select value->>'v' g, count(*) c from jsonb_each(r.pl) where value->>'v' is not null group by 1) q), 'mv', r.pl->me->'v', 'ex', coalesce(r.cf->'ex', '[]'::jsonb), 'tm', coalesce((r.cf->>'tm')::boolean, false));
 elsif r.phase = 'intro' then
  st := jsonb_build_object('vote', r.st->'vote');
 elsif r.phase = 'inter' then
  st := r.st;
 elsif r.game = 'flask' and live then
  st := jsonb_build_object('al', r.st->'al', 'last', r.st->'last', 'b', (select coalesce(jsonb_agg(jsonb_build_object('o', b->>'o', 'prot', (b->>'o') is not null and t - (b->>'t')::bigint < 700) order by ord), '[]') from jsonb_array_elements(r.st->'b') with ordinality as q(b, ord)));
 elsif r.game = 'dobble' and live then
  st := jsonb_build_object('c', r.st->'c', 'w', r.st->'w', 'my', r.st->'k'->me, 'lk', greatest(0, coalesce((r.st->'lk'->>me)::bigint, 0) - t));
 elsif r.game = 'kartoffel' and live then
  st := jsonb_build_object('h', r.st->'h', 'from', r.st->'from', 'boom', r.st->'boom');
 elsif r.game = 'sprint' and live then
  st := jsonb_build_object('c', r.st->'c', 'res', r.st->'res');
 elsif r.game = 'merk' and live then
  st := jsonb_build_object('sq', r.st->'sq', 'sh', r.st->'sh', 'my', coalesce((r.st->'pos'->>me)::integer, 0),
   'dn', (select coalesce(jsonb_agg(k), '[]') from jsonb_object_keys(r.st->'dn') k),
   'fl', (select coalesce(jsonb_agg(key), '[]') from jsonb_each_text(r.st->'pos') where value = '-1'), 'res', r.st->'res');
 elsif r.game = 'reaktion' and live then
  st := jsonb_build_object('g', t >= (r.st->>'go')::bigint, 'w', r.st->'w', 'lk', greatest(0, coalesce((r.st->'lk'->>me)::bigint, 0) - t));
 elsif r.game in ('minor', 'einzig', 'zaehl', 'zwei3') and live then
  st := jsonb_build_object('picked', (select coalesce(jsonb_agg(k), '[]') from jsonb_object_keys(r.st->'p') k), 'my', r.st->'p'->me);
  if r.game = 'einzig' then st := st || jsonb_build_object('k', r.st->'k'); end if;
  if r.game = 'zaehl' then st := st || jsonb_build_object('cells', r.st->'cells', 'tg', r.st->'tg'); end if;
  if r.phase in ('between', 'done') then st := st || jsonb_build_object('res', r.st->'res', 'picks', r.st->'p'); end if;
 end if;
 tot := case r.phase when 'intro' then 5000 when 'inter' then 6000 when 'play' then (case when r.game = 'merk' then (r.st->>'end')::bigint - r.tp else public._ffa_pt(r.game) end) when 'between' then public._ffa_bd(r.game) else null end;
 lft := case when tot is null then null else tot - (t - r.tp) end;
 return jsonb_build_object('r', 'ok', 'ph', r.phase, 'g', r.game, 'rnd', r.rnd, 'rounds', r.rounds, 'host', r.host, 'left', lft, 'tot', tot, 'pl', pl, 'st', st,
  'tm', case when r.tm is null then null else jsonb_build_object('i', (r.tm->>'i')::integer, 'n', jsonb_array_length(r.tm->'q'), 'tot', r.tm->'tot') end);
end $$;

create or replace function public.ffa_create(p_name text, p_pin text, p_code text, p_game text, p_rounds integer) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare s text; tk text; nm text;
begin
 s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return jsonb_build_object('r', 'auth'); end if; nm := substr(s, 4);
 if p_game <> all(public._ffa_games()) then return jsonb_build_object('r', 'bad'); end if;
 delete from public.ffa where created_at < now() - interval '1 day';
 if exists (select 1 from public.ffa where code = p_code) then return jsonb_build_object('r', 'exists'); end if;
 tk := md5(random()::text || clock_timestamp()::text || nm);
 insert into public.ffa(code, host, game, rounds, tp, pl) values (p_code, nm, p_game, least(15, greatest(3, coalesce(p_rounds, 8))), public._fnow(), jsonb_build_object(nm, jsonb_build_object('s', 0, 'seen', public._fnow(), 'tk', tk)));
 return jsonb_build_object('r', 'ok', 'tk', tk, 'me', nm);
end $$;

create or replace function public.ffa_do(p_code text, p_name text, p_tk text, p_op text, p_arg text, p_n integer) returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare r public.ffa; r0 public.ffa; t bigint := public._fnow(); nb jsonb; cur jsonb; idx integer; stale text[]; cnts jsonb; mx integer; tied text[]; kk integer; go bigint; enabled text[]; q text[];
begin
 select * into r from public.ffa where code = p_code for update;
 if not found then return jsonb_build_object('r', 'none'); end if;
 if not (r.pl ? p_name) or r.pl->p_name->>'tk' is distinct from p_tk then return jsonb_build_object('r', 'kicked'); end if;
 r0 := r;
 if t - coalesce((r.pl->p_name->>'seen')::bigint, 0) > 3000 then r.pl := jsonb_set(r.pl, array[p_name, 'seen'], to_jsonb(t)); end if;
 if r.phase = 'lobby' then
  stale := array(select key from jsonb_each(r.pl) where (value->>'seen')::bigint < t - 20000 and key <> p_name);
  if cardinality(stale) > 0 then r.pl := r.pl - stale; end if;
  if not (r.pl ? r.host) then r.host := p_name; end if;
 end if;
 if p_op = 'start' and r.host = p_name and r.phase = 'lobby' then
  if (select count(*) from jsonb_each(r.pl) where (value->>'seen')::bigint > t - 15000) < 2 then return jsonb_build_object('r', 'few'); end if;
  enabled := array(select g from unnest(public._ffa_games()) g where not (coalesce(r.cf->'ex', '[]'::jsonb) ? g));
  if coalesce((r.cf->>'tm')::boolean, false) then
   q := array(select g from unnest(enabled) g order by random() limit 4);
   r.tm := jsonb_build_object('q', to_jsonb(q), 'i', 0, 'tot', '{}'::jsonb, 'rn', 3, 'orig', r.rounds);
   r.game := q[1]; r.rounds := 3; cnts := '{}'::jsonb;
  else
   select coalesce(jsonb_object_agg(g, c), '{}'::jsonb), coalesce(max(c), 0) into cnts, mx from (select value->>'v' g, count(*)::integer c from jsonb_each(r.pl) where value->>'v' = any(enabled) and (value->>'seen')::bigint > t - 15000 group by 1) q2;
   if mx = 0 then tied := enabled;
   else tied := array(select key from jsonb_each_text(cnts) where value::integer = mx); end if;
   r.game := tied[1 + floor(random() * cardinality(tied))::integer];
  end if;
  select jsonb_object_agg(key, jsonb_build_object('s', 0, 'seen', (value->>'seen')::bigint, 'tk', value->>'tk')) into r.pl from jsonb_each(r.pl) where (value->>'seen')::bigint > t - 15000;
  r.rnd := 0; r.phase := 'intro'; r.tp := t; r.st := jsonb_build_object('vote', cnts);
 elsif p_op = 'vote' and r.phase = 'lobby' and p_arg = any(public._ffa_games()) and not (coalesce(r.cf->'ex', '[]'::jsonb) ? p_arg) then
  r.pl := jsonb_set(r.pl, array[p_name, 'v'], to_jsonb(p_arg));
 elsif p_op = 'ex' and r.host = p_name and r.phase = 'lobby' and p_arg = any(public._ffa_games()) then
  cur := coalesce(r.cf->'ex', '[]'::jsonb);
  if cur ? p_arg then cur := (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements_text(cur) e where e <> p_arg);
  elsif cardinality(public._ffa_games()) - jsonb_array_length(cur) > 2 then cur := cur || to_jsonb(p_arg); end if;
  r.cf := r.cf || jsonb_build_object('ex', cur);
 elsif p_op = 'tmode' and r.host = p_name and r.phase = 'lobby' then
  r.cf := r.cf || jsonb_build_object('tm', not coalesce((r.cf->>'tm')::boolean, false));
 elsif p_op = 'react' and p_arg in ('😂', '😡', '👏', '😱', '🔥', '🤔') and t - coalesce((r.pl->p_name->>'rt')::bigint, 0) >= 1000 then
  r.pl := jsonb_set(r.pl, array[p_name], (r.pl->p_name) || jsonb_build_object('rx', p_arg, 'rt', t));
 elsif p_op = 'cfg' and r.host = p_name and r.phase = 'lobby' then
  if p_n is not null then r.rounds := least(15, greatest(3, p_n)); end if;
 elsif p_op = 'again' and r.host = p_name and r.phase = 'done' then
  select jsonb_object_agg(key, jsonb_build_object('s', 0, 'seen', (value->>'seen')::bigint, 'tk', value->>'tk')) into r.pl from jsonb_each(r.pl) where (value->>'seen')::bigint > t - 30000;
  if r.tm is not null then r.rounds := coalesce((r.tm->>'orig')::integer, 8); end if;
  r.tm := null; r.phase := 'lobby'; r.rnd := 0; r.st := '{}'; r.tp := t;
 elsif p_op = 'grab' and r.phase = 'play' and r.game = 'flask' and r.st->'al' ? p_name then
  idx := p_n;
  if idx >= 0 and idx < jsonb_array_length(r.st->'b') then
   cur := r.st->'b'->idx;
   if cur->>'o' is distinct from p_name and not (cur->>'o' is not null and t - (cur->>'t')::bigint < 700) then
    select jsonb_agg(case when ord - 1 = idx then jsonb_build_object('o', p_name, 't', t) when b->>'o' = p_name then jsonb_build_object('o', null, 't', 0) else b end order by ord) into nb from jsonb_array_elements(r.st->'b') with ordinality as q3(b, ord);
    r.st := r.st || jsonb_build_object('b', nb);
   end if;
  end if;
 elsif p_op = 'tap' and r.phase = 'play' and r.game = 'dobble' and r.st->>'w' is null and r.st->'k' ? p_name then
  if coalesce((r.st->'lk'->>p_name)::bigint, 0) <= t then
   if r.st->'c' ? p_arg and r.st->'k'->p_name ? p_arg then
    r.st := r.st || jsonb_build_object('w', p_name);
    r.pl := jsonb_set(r.pl, array[p_name, 's'], to_jsonb((r.pl->p_name->>'s')::integer + 1));
    r.phase := 'between'; r.tp := t;
   else
    r.st := jsonb_set(r.st, array['lk', p_name], to_jsonb(t + 1500));
   end if;
  end if;
 elsif p_op = 'pass' and r.phase = 'play' and r.game = 'kartoffel' and r.st->>'h' = p_name and p_arg is not null and p_arg <> p_name and r.pl ? p_arg
   and t - (r.st->>'pt')::bigint >= 400 and (r.pl->p_arg->>'seen')::bigint > t - 15000
   and (p_arg is distinct from r.st->>'from' or (select count(*) from jsonb_each(r.pl) where (value->>'seen')::bigint > t - 15000) <= 2) then
  r.st := r.st || jsonb_build_object('h', p_arg, 'from', p_name, 'pt', t);
 elsif p_op = 'cnt' and r.phase = 'play' and r.game = 'sprint' and p_n is not null and t >= (r.st->>'go')::bigint - 300 then
  go := (r.st->>'go')::bigint;
  kk := least(p_n, ceil(greatest(0, least(t, go + 6000) - go + 400) / 1000.0 * 16)::integer + 4);
  if kk > coalesce((r.st->'c'->>p_name)::integer, 0) then r.st := jsonb_set(r.st, array['c', p_name], to_jsonb(kk)); end if;
 elsif p_op = 'seq' and r.phase = 'play' and r.game = 'merk' and p_n between 0 and 3 and t >= r.tp + (r.st->>'sh')::bigint - 150
   and coalesce((r.st->'pos'->>p_name)::integer, 0) >= 0 and ((r.st->'dn') ? p_name) is not true then
  idx := coalesce((r.st->'pos'->>p_name)::integer, 0);
  if (r.st->'sq'->>idx)::integer = p_n then
   idx := idx + 1;
   r.st := jsonb_set(r.st, array['pos', p_name], to_jsonb(idx));
   if idx >= jsonb_array_length(r.st->'sq') then r.st := jsonb_set(r.st, array['dn', p_name], to_jsonb(t)); end if;
  else
   r.st := jsonb_set(r.st, array['pos', p_name], to_jsonb(-1));
  end if;
 elsif p_op = 'hit' and r.phase = 'play' and r.game = 'reaktion' and r.st->>'w' is null and coalesce((r.st->'lk'->>p_name)::bigint, 0) <= t then
  if t >= (r.st->>'go')::bigint then
   r.st := r.st || jsonb_build_object('w', p_name);
   r.pl := jsonb_set(r.pl, array[p_name, 's'], to_jsonb((r.pl->p_name->>'s')::integer + 1));
   r.phase := 'between'; r.tp := t;
  else
   r.st := jsonb_set(r.st, array['lk', p_name], to_jsonb(t + 1500));
  end if;
 elsif p_op = 'pick' and r.phase = 'play' and r.game in ('minor', 'einzig', 'zaehl', 'zwei3') and p_n is not null and ((r.st->'p') ? p_name) is not true
   and ((r.game = 'minor' and p_n between 0 and 3) or (r.game = 'einzig' and p_n between 1 and (r.st->>'k')::integer) or (r.game = 'zaehl' and p_n between 0 and 40) or (r.game = 'zwei3' and p_n between 0 and 100)) then
  r.st := jsonb_set(r.st, array['p', p_name], to_jsonb(p_n));
 elsif p_op = 'leave' then
  if r.phase in ('lobby', 'done') then
   r.pl := r.pl - p_name;
   if r.pl = '{}'::jsonb then delete from public.ffa where code = r.code; return jsonb_build_object('r', 'none'); end if;
   if r.host = p_name then select key into r.host from jsonb_each(r.pl) limit 1; end if;
  else
   r.pl := jsonb_set(r.pl, array[p_name, 'seen'], to_jsonb(0::bigint));
  end if;
  update public.ffa set host = r.host, pl = r.pl where code = r.code;
  return jsonb_build_object('r', 'left');
 end if;
 r := public._ffa_tick(r);
 if r.phase is distinct from r0.phase or r.st is distinct from r0.st or r.pl is distinct from r0.pl or r.game is distinct from r0.game or r.rounds is distinct from r0.rounds or r.host is distinct from r0.host or r.tm is distinct from r0.tm or r.cf is distinct from r0.cf then
  update public.ffa set host = r.host, game = r.game, rounds = r.rounds, phase = r.phase, rnd = r.rnd, tp = r.tp, st = r.st, pl = r.pl, tm = r.tm, cf = r.cf where code = r.code;
 end if;
 return public._ffa_view(r, p_name);
end $$;
revoke all on function public._fnow(), public._ffa_games(), public._ffa_bd(text), public._ffa_pt(text), public._ffa_round(public.ffa), public._ffa_fin(public.ffa), public._ffa_next(public.ffa), public._ffa_tick(public.ffa), public._ffa_view(public.ffa, text) from public, anon, authenticated;
grant execute on function public.ffa_create(text, text, text, text, integer), public.ffa_join(text, text, text), public.ffa_do(text, text, text, text, text, integer) to anon, authenticated;

-- 16) Rekorde nur aus Ranked
alter table public.results add column if not exists rk boolean not null default false;
create index if not exists results_rk_idx on public.results(rk) where rk;
create or replace function public.submit_result(p_name text, p_pin text, p_code text, p_total integer, p_pen integer, p_games jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; tt integer := p_total; g jsonb := coalesce(p_games, '{}'::jsonb); isrk boolean := false; base text; rn integer; gk text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if (select count(*) from public.results where name = substr(s, 4) and created_at > now() - interval '60 seconds') >= 40 then return 'rate'; end if; if p_code not like '%-END' and tt < 700 then if p_code ~ '-R[0-9]+$' then tt := 700; else return 'implausible'; end if; end if; if p_code ~ '^1[A-Z0-9]{4}-R[0-9]+$' then base := regexp_replace(p_code, '-R[0-9]+$', ''); rn := substring(p_code from '-R([0-9]+)$')::integer; if exists (select 1 from public.ranked_rooms where code = base) then isrk := true; select r.stages->'g'->>(rn - 1) into gk from public.rooms r where r.code = base; if gk is not null and g ? gk and jsonb_typeof(g->gk) = 'number' then g := jsonb_build_object(gk, g->gk); else g := '{}'::jsonb; end if; end if; end if; insert into public.results(code, name, total_ms, pen_ms, games, rk) values (p_code, substr(s, 4), tt, p_pen, g, isrk); return 'ok'; end $$;
create or replace function public.best_times(p_days integer default null) returns table(n text, g text, ms integer, d text, t text) language sql stable security definer set search_path = public as $$ with x as (select r.name as nm, j.key as gm, case when jsonb_typeof(j.value) = 'number' then (j.value #>> '{}')::numeric end as v, r.created_at as ts from public.results r, lateral jsonb_each(case when jsonb_typeof(r.games) = 'object' then r.games else '{}'::jsonb end) j where r.rk and r.code <> 'ARCADE-SOLO' and r.total_ms >= 700 and (p_days is null or r.created_at >= now() - make_interval(days => p_days))), b as (select distinct on (gm, nm) nm, gm, v::integer as vi, ts from x where v >= 700 and v <= 600000 order by gm, nm, v, ts), k as (select nm, gm, vi, ts, row_number() over (partition by gm order by vi, ts) as rn from b) select k.nm, k.gm, k.vi, to_char(k.ts, 'YYYY-MM-DD'), (select pl.team from public.players pl where pl.name_key = lower(btrim(k.nm))) from k where k.rn <= 25 order by k.gm, k.vi $$;
create or replace function public.player_bests(p_name text) returns table(g text, ms integer, rk integer, cnt integer) language sql stable security definer set search_path = public as $$ with x as (select r.name as nm, j.key as gm, case when jsonb_typeof(j.value) = 'number' then (j.value #>> '{}')::numeric end as v, r.created_at as ts from public.results r, lateral jsonb_each(case when jsonb_typeof(r.games) = 'object' then r.games else '{}'::jsonb end) j where r.rk and r.code <> 'ARCADE-SOLO' and r.total_ms >= 700), b as (select distinct on (gm, lower(nm)) lower(nm) as nk, gm, v::integer as vi from x where v >= 700 and v <= 600000 order by gm, lower(nm), v), k as (select nk, gm, vi, rank() over (partition by gm order by vi) as rk, count(*) over (partition by gm) as cnt from b) select gm, vi, rk::integer, cnt::integer from k where nk = lower(btrim(p_name)) order by gm $$;
create or replace function public.season_top(p_from timestamptz, p_to timestamptz) returns table(n text, c integer) language sql stable security definer set search_path = public as $$ with x as (select r.name as nm, j.key as gm, case when jsonb_typeof(j.value) = 'number' then (j.value #>> '{}')::numeric end as v from public.results r, lateral jsonb_each(case when jsonb_typeof(r.games) = 'object' then r.games else '{}'::jsonb end) j where r.rk and r.code <> 'ARCADE-SOLO' and r.total_ms >= 700 and r.created_at >= p_from and r.created_at < p_to), b as (select distinct on (gm, nm) nm, gm, v from x where v >= 700 and v <= 600000 order by gm, nm, v), w as (select distinct on (gm) nm from b order by gm, v) select nm, count(*)::integer from w group by nm order by 2 desc, 1 limit 10 $$;

-- 17) Admin-Funktionen (nur Konto "Admin") und Sperren
create table if not exists public.bans (name_key text primary key, created_at timestamptz not null default now());
alter table public.bans enable row level security;
create or replace function public._auth(p_name text, p_pin text, p_create boolean) returns text language plpgsql security definer set search_path = public, extensions as $$ declare r public.players; k text := lower(btrim(p_name)); begin if char_length(btrim(p_name)) not between 1 and 14 or char_length(coalesce(p_pin, '')) not between 4 and 12 then return 'invalid'; end if; select * into r from public.players where name_key = k; if not found then if p_create then if public._bad_name(p_name) then return 'blocked'; end if; insert into public.players(name_key, name, pin_hash) values (k, btrim(p_name), crypt(p_pin, gen_salt('bf'))); return 'new:' || btrim(p_name); end if; return 'none'; end if; if r.locked_until is not null and r.locked_until > now() then return 'locked'; end if; if r.pin_hash = crypt(p_pin, r.pin_hash) then if exists (select 1 from public.bans where name_key = k) then return 'banned'; end if; update public.players set fails = 0, locked_until = null where name_key = k; return 'ok:' || r.name; end if; if r.fails >= 4 then update public.players set fails = 0, locked_until = now() + interval '5 minutes' where name_key = k; return 'locked'; end if; update public.players set fails = fails + 1 where name_key = k; return 'wrong'; end $$;
create or replace function public.best_times(p_days integer default null) returns table(n text, g text, ms integer, d text, t text) language sql stable security definer set search_path = public as $$ with x as (select r.name as nm, j.key as gm, case when jsonb_typeof(j.value) = 'number' then (j.value #>> '{}')::numeric end as v, r.created_at as ts from public.results r, lateral jsonb_each(case when jsonb_typeof(r.games) = 'object' then r.games else '{}'::jsonb end) j where r.rk and not exists (select 1 from public.bans bn where bn.name_key = lower(btrim(r.name))) and r.code <> 'ARCADE-SOLO' and r.total_ms >= 700 and (p_days is null or r.created_at >= now() - make_interval(days => p_days))), b as (select distinct on (gm, nm) nm, gm, v::integer as vi, ts from x where v >= 700 and v <= 600000 order by gm, nm, v, ts), k as (select nm, gm, vi, ts, row_number() over (partition by gm order by vi, ts) as rn from b) select k.nm, k.gm, k.vi, to_char(k.ts, 'YYYY-MM-DD'), (select pl.team from public.players pl where pl.name_key = lower(btrim(k.nm))) from k where k.rn <= 25 order by k.gm, k.vi $$;
create or replace function public.season_top(p_from timestamptz, p_to timestamptz) returns table(n text, c integer) language sql stable security definer set search_path = public as $$ with x as (select r.name as nm, j.key as gm, case when jsonb_typeof(j.value) = 'number' then (j.value #>> '{}')::numeric end as v from public.results r, lateral jsonb_each(case when jsonb_typeof(r.games) = 'object' then r.games else '{}'::jsonb end) j where r.rk and not exists (select 1 from public.bans bn where bn.name_key = lower(btrim(r.name))) and r.code <> 'ARCADE-SOLO' and r.total_ms >= 700 and r.created_at >= p_from and r.created_at < p_to), b as (select distinct on (gm, nm) nm, gm, v from x where v >= 700 and v <= 600000 order by gm, nm, v), w as (select distinct on (gm) nm from b order by gm, v) select nm, count(*)::integer from w group by nm order by 2 desc, 1 limit 10 $$;
create or replace function public.elo_top() returns table(n text, r integer, g integer, w integer) language sql stable security definer set search_path = public as $$ select e.name, e.r, e.g, e.w from public.elo e where e.g > 0 and not exists (select 1 from public.bans bn where bn.name_key = e.name_key) order by e.r desc, e.g desc limit 20 $$;
create or replace function public._adm(p_name text, p_pin text) returns boolean language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); return coalesce(s = 'ok:' || (select name from public.players where name_key = 'admin'), false); end $$;
create or replace function public.admin_list(p_name text, p_pin text, p_q text default '') returns jsonb language plpgsql security definer set search_path = public, extensions as $$ declare q text := '%' || lower(btrim(coalesce(p_q, ''))) || '%'; begin if not public._adm(p_name, p_pin) then return jsonb_build_object('r', 'no'); end if; return jsonb_build_object('r', 'ok', 'total', (select count(*) from public.players), 'active7', (select count(*) from public.players where last_seen > now() - interval '7 days'), 'banned', (select count(*) from public.bans), 'results', (select count(*) from public.results), 'list', coalesce((select jsonb_agg(x) from (select jsonb_build_object('n', p.name, 'av', p.avatar, 'team', p.team, 'created', to_char(p.created_at, 'YYYY-MM-DD'), 'seen', p.last_seen, 'banned', exists (select 1 from public.bans b where b.name_key = p.name_key), 'elo', (select e.r from public.elo e where e.name_key = p.name_key), 'res', (select count(*) from public.results r where lower(r.name) = p.name_key)) as x from public.players p where p.name_key like q order by p.last_seen desc nulls last, p.name_key limit 100) t), '[]'::jsonb)); end $$;
create or replace function public.admin_ban(p_name text, p_pin text, p_target text, p_ban boolean) returns text language plpgsql security definer set search_path = public, extensions as $$ declare k text := lower(btrim(p_target)); begin if not public._adm(p_name, p_pin) then return 'no'; end if; if k = 'admin' or not exists (select 1 from public.players where name_key = k) then return 'bad'; end if; if p_ban then insert into public.bans(name_key) values (k) on conflict do nothing; delete from public.queue where name_key = k; else delete from public.bans where name_key = k; end if; return 'ok'; end $$;
create or replace function public.admin_reset_pin(p_name text, p_pin text, p_target text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare k text := lower(btrim(p_target)); np text; begin if not public._adm(p_name, p_pin) then return 'no'; end if; if k = 'admin' or not exists (select 1 from public.players where name_key = k) then return 'bad'; end if; np := lpad((('x' || encode(gen_random_bytes(4), 'hex'))::bit(32)::bigint % 1000000)::text, 6, '0'); update public.players set pin_hash = crypt(np, gen_salt('bf')), fails = 0, locked_until = null where name_key = k; return 'ok:' || np; end $$;
create or replace function public.admin_wipe(p_name text, p_pin text, p_target text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare k text := lower(btrim(p_target)); n integer; begin if not public._adm(p_name, p_pin) then return 'no'; end if; if k = 'admin' or not exists (select 1 from public.players where name_key = k) then return 'bad'; end if; delete from public.results where lower(name) = k; get diagnostics n = row_count; delete from public.elo where name_key = k; delete from public.elo_season where name_key = k; return 'ok:' || n; end $$;
revoke all on function public._adm(text, text) from public, anon, authenticated;
grant execute on function public.admin_list(text, text, text), public.admin_ban(text, text, text, boolean), public.admin_reset_pin(text, text, text), public.admin_wipe(text, text, text) to anon, authenticated;

-- 18) Free-for-All-Statistik, Wochenaufgabe, Saison-Medaillen
create table if not exists public.ffa_stats (name_key text primary key, name text not null, g integer not null default 0, w integer not null default 0, by jsonb not null default '{}', wk text not null default '', wg integer not null default 0, ww integer not null default 0, wc integer not null default 0, wcw text not null default '');
alter table public.ffa_stats enable row level security;
create or replace function public._ffa_stat(r public.ffa) returns void language plpgsql set search_path = public as $$
declare x text; mx integer; cw text := to_char(now() at time zone 'Europe/Berlin', 'IYYY-IW'); gk text := case when r.tm is not null then 'tm' else r.game end; win boolean; nk text;
begin
 select max((value->>'s')::integer) into mx from jsonb_each(r.pl);
 for x in select key from jsonb_each(r.pl) loop
  win := coalesce(mx, 0) > 0 and (r.pl->x->>'s')::integer = mx;
  nk := lower(btrim(x));
  insert into public.ffa_stats(name_key, name) values (nk, x) on conflict (name_key) do nothing;
  update public.ffa_stats s set name = x, g = s.g + 1, w = s.w + (case when win then 1 else 0 end),
   by = jsonb_set(coalesce(s.by, '{}'::jsonb), array[gk], jsonb_build_object('g', coalesce((s.by->gk->>'g')::integer, 0) + 1, 'w', coalesce((s.by->gk->>'w')::integer, 0) + (case when win then 1 else 0 end)), true),
   wg = (case when s.wk = cw then s.wg else 0 end) + 1,
   ww = (case when s.wk = cw then s.ww else 0 end) + (case when win then 1 else 0 end),
   wk = cw
   where s.name_key = nk;
  update public.ffa_stats s set wc = s.wc + 1, wcw = cw where s.name_key = nk and s.wk = cw and s.wg >= 5 and s.ww >= 3 and s.wcw is distinct from cw;
 end loop;
end $$;
create or replace function public._ffa_fin(r public.ffa) returns public.ffa language plpgsql set search_path = public as $$
declare t bigint := public._fnow(); x text; cnt integer; pts integer; gp jsonb := '{}'; tot jsonb; q text[]; i integer;
begin
 if r.tm is null then r.phase := 'done'; r.tp := t; perform public._ffa_stat(r); return r; end if;
 tot := coalesce(r.tm->'tot', '{}'::jsonb);
 for x in select key from jsonb_each(r.pl) loop
  select count(*) into cnt from jsonb_each(r.pl) where (value->>'s')::integer > (r.pl->x->>'s')::integer;
  pts := greatest(0, 3 - cnt);
  gp := gp || jsonb_build_object(x, pts);
  tot := jsonb_set(tot, array[x], to_jsonb(coalesce((tot->>x)::integer, 0) + pts), true);
 end loop;
 i := (r.tm->>'i')::integer; q := array(select jsonb_array_elements_text(r.tm->'q'));
 r.tm := r.tm || jsonb_build_object('tot', tot);
 r.tp := t;
 if i + 1 < cardinality(q) then
  r.phase := 'inter'; r.st := jsonb_build_object('gp', gp, 'tot', tot, 'g', r.game, 'next', q[i + 2]);
 else
  select jsonb_object_agg(key, ((value - 'out') - 'w') || jsonb_build_object('s', coalesce((tot->>key)::integer, 0))) into r.pl from jsonb_each(r.pl);
  r.phase := 'done'; r.st := jsonb_build_object('tmfin', true);
  perform public._ffa_stat(r);
 end if;
 return r;
end $$;
create or replace function public.ffa_stats(p_name text) returns jsonb language sql stable security definer set search_path = public as $$
 select coalesce((select jsonb_build_object('g', g, 'w', w, 'by', by,
   'wg', case when wk = to_char(now() at time zone 'Europe/Berlin', 'IYYY-IW') then wg else 0 end,
   'ww', case when wk = to_char(now() at time zone 'Europe/Berlin', 'IYYY-IW') then ww else 0 end, 'wc', wc)
  from public.ffa_stats where name_key = lower(btrim(p_name))), jsonb_build_object('g', 0, 'w', 0, 'by', '{}'::jsonb, 'wg', 0, 'ww', 0, 'wc', 0)) $$;
create or replace function public.elo_medals() returns table(n text, p integer) language sql stable security definer set search_path = public as $$
 select e.name, min(e.pos)::integer from public.elo_season e where e.pos <= 3 and e.name_key not in (select name_key from public.bans) group by e.name $$;
revoke all on function public._ffa_stat(public.ffa), public._ffa_fin(public.ffa) from public, anon, authenticated;
grant execute on function public.ffa_stats(text), public.elo_medals() to anon, authenticated;
