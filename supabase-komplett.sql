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
alter table public.friends enable row level security;
alter table public.inbox enable row level security;

create or replace function public.friend_request(p_name text, p_pin text, p_to text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; k text := lower(btrim(coalesce(p_to, ''))); begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); if k = me then return 'self'; end if; if not exists (select 1 from public.players where name_key = k) then return 'nf'; end if; if exists (select 1 from public.friends where a = me and b = k) then return 'already'; end if; if exists (select 1 from public.inbox where to_key = me and kind = 'friend' and lower(from_name) = k) then delete from public.inbox where to_key = me and kind = 'friend' and lower(from_name) = k; insert into public.friends values (me, k), (k, me) on conflict do nothing; return 'accepted'; end if; if exists (select 1 from public.inbox where to_key = k and kind = 'friend' and lower(from_name) = me) then return 'sent'; end if; insert into public.inbox(to_key, from_name, kind) values (k, substr(s, 4), 'friend'); return 'sent'; end $$;

create or replace function public.inbox_list(p_name text, p_pin text) returns table(id bigint, k text, f text, p text, c timestamptz) language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return; end if; update public.players set last_seen = now() where name_key = lower(substr(s, 4)); delete from public.inbox where kind = 'invite' and created < now() - interval '1 day'; return query select i.id, i.kind, i.from_name, i.payload, i.created from public.inbox i where i.to_key = lower(substr(s, 4)) order by i.created desc limit 40; end $$;

create or replace function public.inbox_answer(p_name text, p_pin text, p_id bigint, p_accept boolean) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; r public.inbox; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); select * into r from public.inbox where id = p_id and to_key = me; if not found then return 'nf'; end if; if r.kind = 'friend' and p_accept then insert into public.friends values (me, lower(r.from_name)), (lower(r.from_name), me) on conflict do nothing; end if; delete from public.inbox where id = p_id; return 'ok'; end $$;

drop function if exists public.friends_list(text, text);
create or replace function public.friends_list(p_name text, p_pin text) returns table(n text, a text, s integer) language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return; end if; return query select pl.name, pl.avatar, (extract(epoch from now() - pl.last_seen))::integer from public.friends f join public.players pl on pl.name_key = f.b where f.a = lower(substr(s, 4)) order by pl.name; end $$;

create or replace function public.friend_remove(p_name text, p_pin text, p_who text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; k text := lower(btrim(coalesce(p_who, ''))); begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); delete from public.friends where (a = me and b = k) or (a = k and b = me); return 'ok'; end $$;

create or replace function public.send_invite(p_name text, p_pin text, p_to text, p_payload text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; me text; k text := lower(btrim(coalesce(p_to, ''))); begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := lower(substr(s, 4)); if p_payload is null or p_payload !~ '^[A-Za-z0-9-]{4,30}$' then return 'invalid'; end if; if not exists (select 1 from public.friends where a = me and b = k) then return 'nofriend'; end if; if (select count(*) from public.inbox where to_key = k) >= 40 then return 'full'; end if; delete from public.inbox where to_key = k and kind = 'invite' and payload = p_payload and lower(from_name) = me; insert into public.inbox(to_key, from_name, kind, payload) values (k, substr(s, 4), 'invite', p_payload); return 'ok'; end $$;

grant execute on function public.friend_request(text, text, text), public.inbox_list(text, text), public.inbox_answer(text, text, bigint, boolean), public.friends_list(text, text), public.friend_remove(text, text, text), public.send_invite(text, text, text, text) to anon, authenticated;

-- 4) Direktes Schreiben ohne PIN sperren (alles läuft nur noch über die Funktionen oben)
do $$ declare p record; begin for p in select policyname, tablename from pg_policies where schemaname = 'public' and ((tablename in ('results', 'picks', 'rooms') and cmd = 'INSERT') or (tablename in ('picks', 'rooms') and cmd = 'UPDATE')) loop execute format('drop policy %I on public.%I', p.policyname, p.tablename); end loop; end $$;
