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
alter table public.players enable row level security;

create or replace function public._auth(p_name text, p_pin text, p_create boolean) returns text language plpgsql security definer set search_path = public, extensions as $$ declare r public.players; k text := lower(btrim(p_name)); begin if char_length(btrim(p_name)) not between 1 and 14 or char_length(coalesce(p_pin, '')) not between 4 and 12 then return 'invalid'; end if; select * into r from public.players where name_key = k; if not found then if p_create then insert into public.players(name_key, name, pin_hash) values (k, btrim(p_name), crypt(p_pin, gen_salt('bf'))); return 'new:' || btrim(p_name); end if; return 'none'; end if; if r.locked_until is not null and r.locked_until > now() then return 'locked'; end if; if r.pin_hash = crypt(p_pin, r.pin_hash) then update public.players set fails = 0, locked_until = null where name_key = k; return 'ok:' || r.name; end if; if r.fails >= 4 then update public.players set fails = 0, locked_until = now() + interval '5 minutes' where name_key = k; return 'locked'; end if; update public.players set fails = fails + 1 where name_key = k; return 'wrong'; end $$;

create or replace function public.claim_name(p_name text, p_pin text) returns text language sql security definer set search_path = public, extensions as $$ select public._auth(p_name, p_pin, true) $$;

create or replace function public.submit_result(p_name text, p_pin text, p_code text, p_total integer, p_pen integer, p_games jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; insert into public.results(code, name, total_ms, pen_ms, games) values (p_code, substr(s, 4), p_total, p_pen, coalesce(p_games, '{}'::jsonb)); return 'ok'; end $$;

create or replace function public.join_room(p_name text, p_pin text, p_code text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; insert into public.picks(code, name) values (p_code, substr(s, 4)) on conflict do nothing; return 'ok'; end $$;

create or replace function public.create_room(p_name text, p_pin text, p_code text, p_seed integer, p_size integer, p_stages jsonb) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; if char_length(coalesce(p_code, '')) not between 4 and 8 or p_size not between 2 and 5 then return 'invalid'; end if; insert into public.rooms(code, seed, size, host, stages) values (p_code, p_seed, p_size, substr(s, 4), p_stages); return 'ok'; exception when unique_violation then return 'exists'; end $$;

create or replace function public.set_room(p_name text, p_pin text, p_code text, p_stages jsonb, p_start timestamptz, p_expect integer) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; r public.rooms; me text; duel boolean; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; me := substr(s, 4); select * into r from public.rooms where code = p_code; if not found then return 'stale'; end if; duel := left(p_code, 1) = '1' and r.stages is not null and jsonb_typeof(r.stages) = 'object'; if r.host <> me and not (duel and exists (select 1 from public.picks where code = p_code and name = me)) then return 'denied'; end if; if p_stages is not null and not duel and r.stages is not null then return 'stale'; end if; update public.rooms set stages = coalesce(p_stages, stages), start_at = coalesce(p_start, start_at) where code = p_code and (p_expect is null or (stages ->> 'r')::integer = p_expect); if not found then return 'stale'; end if; return 'ok'; end $$;

create or replace function public.set_pick(p_name text, p_pin text, p_code text, p_game text) returns text language plpgsql security definer set search_path = public, extensions as $$ declare s text; begin s := public._auth(p_name, p_pin, false); if s not like 'ok:%' then return s; end if; update public.picks set game = p_game, picked_at = now() where code = p_code and name = substr(s, 4); return 'ok'; exception when unique_violation then return 'taken'; end $$;

create or replace function public.best_times(p_days integer default null) returns table(n text, g text, ms integer, d text) language sql stable security definer set search_path = public as $$ with x as (select r.name as nm, j.key as gm, case when jsonb_typeof(j.value) = 'number' then (j.value #>> '{}')::numeric end as v, r.created_at as ts from public.results r, lateral jsonb_each(case when jsonb_typeof(r.games) = 'object' then r.games else '{}'::jsonb end) j where r.code <> 'ARCADE-SOLO' and r.total_ms >= 700 and (p_days is null or r.created_at >= now() - make_interval(days => p_days))), b as (select distinct on (gm, nm) nm, gm, v::integer as vi, ts from x where v >= 700 and v <= 600000 order by gm, nm, v, ts), k as (select nm, gm, vi, ts, row_number() over (partition by gm order by vi, ts) as rn from b) select nm, gm, vi, to_char(ts, 'YYYY-MM-DD') from k where rn <= 25 order by gm, vi $$;

revoke all on function public._auth(text, text, boolean) from public, anon, authenticated;
grant execute on function public.claim_name(text, text), public.submit_result(text, text, text, integer, integer, jsonb), public.join_room(text, text, text), public.create_room(text, text, text, integer, integer, jsonb), public.set_room(text, text, text, jsonb, timestamptz, integer), public.set_pick(text, text, text, text), public.best_times(integer) to anon;

-- 4) Direktes Schreiben ohne PIN sperren (alles läuft nur noch über die Funktionen oben)
do $$ declare p record; begin for p in select policyname, tablename from pg_policies where schemaname = 'public' and ((tablename in ('results', 'picks', 'rooms') and cmd = 'INSERT') or (tablename in ('picks', 'rooms') and cmd = 'UPDATE')) loop execute format('drop policy %I on public.%I', p.policyname, p.tablename); end loop; end $$;
