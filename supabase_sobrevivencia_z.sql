-- Supabase SQL para o jogo "Sobrevivência Z"
-- Execute este script no SQL Editor do seu projeto Supabase.

create extension if not exists pgcrypto;

create table if not exists public.players (
  user_id uuid primary key,
  username text not null check (length(username) >= 3 and length(username) <= 18),
  email text,
  skin text not null default 'azul',
  best_score bigint not null default 0,
  progress jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.players enable row level security;

create or replace function public.set_player_user_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if new.user_id is null then
    new.user_id := auth.uid();
  elsif new.user_id <> auth.uid() then
    raise exception 'Você só pode alterar seus próprios dados.';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_set_player_user_id on public.players;
create trigger trg_set_player_user_id
before insert or update on public.players
for each row execute function public.set_player_user_id();

create policy "Jogadores podem visualizar seu próprio perfil"
on public.players
for select
using (auth.uid() = user_id);

create policy "Jogadores podem inserir seu próprio perfil"
on public.players
for insert
with check (auth.uid() = user_id);

create policy "Jogadores podem atualizar seu próprio perfil"
on public.players
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Ranking público"
on public.players
for select
using (true);

create or replace function public.get_public_leaderboard(limit_count integer default 20)
returns table (
  username text,
  best_score bigint
)
language sql
stable
as $$
  select
    p.username,
    p.best_score
  from public.players p
  where p.best_score > 0
  order by p.best_score desc, p.updated_at asc
  limit limit_count;
$$;

grant usage on schema public to anon, authenticated;
grant select on public.players to anon;
grant insert, update on public.players to authenticated;
grant select on public.get_public_leaderboard to anon, authenticated;

-- Ajuste opcional de autenticação:
-- 1. Vá em Authentication > Settings e habilite Email signup.
-- 2. No Supabase, configure o envio de email de confirmação se quiser validar contas.
