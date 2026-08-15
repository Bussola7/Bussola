-- Sprint 03 — Etapa 3.1, correção encontrada na auditoria final
--
-- BUG CRÍTICO: `EventModel.toUpdateJson()` nunca envia `updated_at` — e
-- não existia nenhum gatilho no banco para preencher isso automaticamente.
-- Resultado: a coluna `updated_at` de `events` só era escrita na CRIAÇÃO
-- e nunca mudava depois, mesmo quando o usuário editava o evento de
-- verdade. Isso quebra silenciosamente toda a lógica de "última alteração
-- vence" do `CalendarSyncService` — um evento editado localmente pareceria
-- "nunca modificado" e o Google Calendar nunca receberia a atualização.
--
-- Correção: um gatilho `before update` que força `updated_at = now()` em
-- toda atualização de `events` — não depende de nenhuma camada do app
-- lembrar de enviar o campo (mais seguro que corrigir só o Dart).
-- Aplicamos o mesmo gatilho em `integrations`, pelo mesmo motivo: o
-- `CalendarSyncService` também depende de `integrations.updated_at` para
-- saber quando o estado de conexão mudou pela última vez.

-- IMPORTANTE — segunda descoberta na mesma auditoria: um gatilho "cego"
-- (que sempre bate `updated_at = now()` em qualquer UPDATE) quebraria de
-- novo a mesma lógica, só que ao contrário: as próprias escritas de
-- bookkeeping do `CalendarSyncService` (gravar `google_event_id`,
-- `last_synced_at`, `sync_origin` depois de sincronizar) fariam
-- `updated_at` "andar junto" com `last_synced_at" — e a comparação
-- "o evento mudou depois do último sync?" nunca mais seria verdadeira
-- para uma edição real, pelo motivo oposto ao bug original.
--
-- Por isso o gatilho abaixo só atualiza `updated_at` quando algum campo
-- de CONTEÚDO de verdade muda — nunca quando só os campos de
-- sincronização (`google_event_id`, `last_synced_at`, `sync_origin`)
-- são os únicos alterados.

create or replace function public.set_updated_at()
returns trigger as $$
begin
  if (
    new.title is distinct from old.title or
    new.description is distinct from old.description or
    new.start_datetime is distinct from old.start_datetime or
    new.end_datetime is distinct from old.end_datetime or
    new.timezone is distinct from old.timezone or
    new.all_day is distinct from old.all_day or
    new.location is distinct from old.location or
    new.category_id is distinct from old.category_id or
    new.color is distinct from old.color or
    new.priority is distinct from old.priority or
    new.status is distinct from old.status or
    new.recurrence_rule is distinct from old.recurrence_rule or
    new.recurrence_until is distinct from old.recurrence_until or
    new.recurrence_count is distinct from old.recurrence_count or
    new.calendar_id is distinct from old.calendar_id or
    new.deleted_at is distinct from old.deleted_at
  ) then
    new.updated_at = now();
  else
    -- só bookkeeping de sincronização mudou — preserva o updated_at original.
    new.updated_at = old.updated_at;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_events_set_updated_at on events;
create trigger trg_events_set_updated_at
  before update on events
  for each row execute function public.set_updated_at();

-- Em `integrations` não há essa distinção de "conteúdo vs bookkeeping"
-- (a tabela inteira É bookkeeping de sincronização), então aqui o gatilho
-- pode ser incondicional.
create or replace function public.set_updated_at_unconditional()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_integrations_set_updated_at on integrations;
create trigger trg_integrations_set_updated_at
  before update on integrations
  for each row execute function public.set_updated_at_unconditional();

-- TERCEIRA DESCOBERTA da auditoria: `integrations` (criada na Sprint 01)
-- nunca teve uma constraint única em (user_id, provider). Sem isso, o
-- `upsert()` da Edge Function (que não tem outro jeito de saber "essa
-- linha já existe, atualiza-a") criaria uma linha NOVA a cada
-- conexão/reconexão, em vez de atualizar a existente — e
-- `IntegrationDataSource.getIntegration()` usa `.maybeSingle()`, que
-- lança erro se encontrar mais de uma linha. Isso quebraria a
-- integração na segunda vez que alguém conectasse o Google Calendar.
alter table integrations add constraint uq_integrations_user_provider unique (user_id, provider);

