-- Sprint 03 — Etapa 3.1 (Google Calendar)
--
-- Por que estas mudanças, e não outras:
--
-- 1. `events` precisa saber se um evento já existe no Google, e quando foi
--    sincronizado pela última vez — sem isso, a sincronização incremental
--    não tem como saber "o que já mandei" vs "o que ainda falta".
-- 2. `integrations` (criada vazia na Sprint 01) ganha os campos que
--    faltavam para guardar o estado real de uma conexão: token de
--    sincronização incremental do Google (`sync_token`), quando sincronizou
--    pela última vez, e quais permissões (`scopes`) foram concedidas.
--    NUNCA guardamos aqui o Client Secret do Google — isso mora só na
--    Edge Function (`supabase/functions/google-oauth-exchange`), nunca no
--    banco nem no app. Ver explicação completa no relatório desta etapa.
-- 3. `sync_conflicts` é uma tabela nova porque é um LOG — histórico de
--    decisões de sincronização, algo que não pertence a nenhuma linha de
--    `events` especificamente (um conflito pode envolver um evento que já
--    foi excluído de um dos lados).

-- =========================================================
-- events: rastreamento de sincronização
-- =========================================================
alter table events add column if not exists google_event_id text;
alter table events add column if not exists last_synced_at timestamptz;
alter table events add column if not exists sync_origin text not null default 'local'
  check (sync_origin in ('local', 'google', 'synced'));

create unique index if not exists idx_events_google_event_id
  on events (user_id, google_event_id)
  where google_event_id is not null;

-- =========================================================
-- integrations: completar o que a Sprint 01 deixou reservado
-- =========================================================
alter table integrations add column if not exists sync_token text;
alter table integrations add column if not exists last_sync_at timestamptz;
alter table integrations add column if not exists scopes text;
alter table integrations add column if not exists updated_at timestamptz not null default now();
alter table integrations add column if not exists refresh_token text;

comment on column integrations.refresh_token is 'Só a Edge Function (google-oauth-exchange) escreve/lê esta coluna. O app Flutter nunca deve buscar esta coluna — nem existe um método no app para isso.';
comment on column integrations.token is 'Access token de curta duração (nunca o refresh token — esse fica só no backend/Edge Function)';
comment on column integrations.sync_token is 'syncToken oficial da Google Calendar API, para sincronização incremental (evita baixar tudo de novo a cada sync)';

-- =========================================================
-- sync_conflicts: log de conflitos de sincronização
-- =========================================================
create table if not exists sync_conflicts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  event_id uuid references events(id),
  google_event_id text,
  conflict_type text not null check (conflict_type in ('updated_both', 'deleted_one_side', 'concurrent_update')),
  resolution_strategy text not null default 'last_write_wins',
  resolution_details text,
  created_at timestamptz not null default now()
);

alter table sync_conflicts enable row level security;

create policy "sync_conflicts_select_own" on sync_conflicts for select using (auth.uid() = user_id);
create policy "sync_conflicts_insert_own" on sync_conflicts for insert with check (auth.uid() = user_id);

create index if not exists idx_sync_conflicts_user_id on sync_conflicts(user_id);
