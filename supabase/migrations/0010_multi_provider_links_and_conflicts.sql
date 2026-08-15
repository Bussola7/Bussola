-- Correção de 2 limitações arquiteturais confirmadas na auditoria pós-Etapa 1.15.
--
-- Nada aqui remove ou renomeia coluna existente — só adiciona. 100%
-- reversível (drop column/drop constraint desfaz tudo).

-- =========================================================
-- 1. events: permitir vínculo simultâneo Google + Outlook
-- =========================================================
--
-- Por que uma coluna nova (`outlook_event_id`), e não reaproveitar/renomear
-- `google_event_id`: um usuário pode conectar Google E Outlook ao mesmo
-- tempo (a UI já permite isso desde a Etapa 1.11) — se os dois
-- sincronizassem para o MESMO evento local usando uma única coluna de ID
-- remoto, o segundo provedor a sincronizar sobrescreveria o vínculo do
-- primeiro, perdendo a capacidade de atualizar/excluir aquele evento no
-- provedor que perdeu a referência. `google_event_id` continua existindo,
-- sem nenhuma mudança — só ganha um "irmão" para o Outlook.
alter table events add column if not exists outlook_event_id text;

create unique index if not exists idx_events_outlook_event_id
  on events (user_id, outlook_event_id)
  where outlook_event_id is not null;

-- `sync_origin` tinha um CHECK que só aceitava 'local'/'google'/'synced' —
-- um evento sincronizado a partir do Outlook estava sendo gravado com o
-- valor 'google' (INCORRETO, achado real da auditoria). Recria o
-- constraint incluindo 'outlook'. O nome do constraint segue a convenção
-- padrão do Postgres para um `check` inline sem nome explícito
-- (<tabela>_<coluna>_check), como foi criado na migration 0006.
alter table events drop constraint if exists events_sync_origin_check;
alter table events add constraint events_sync_origin_check
  check (sync_origin in ('local', 'google', 'outlook', 'synced'));

-- =========================================================
-- 2. sync_conflicts: registrar qual provedor causou o conflito
-- =========================================================
--
-- Coluna nova, nullable primeiro (nunca se apaga dado existente).
alter table sync_conflicts add column if not exists provider text;

-- Backfill dos registros históricos: SEGURO assumir 'google_calendar' aqui
-- porque, até este exato commit, o `CalendarSyncService` só era chamado
-- com `provider = CalendarProvider.googleCalendar` em qualquer ambiente
-- real (a integração com o Outlook nunca rodou contra infraestrutura real
-- — Azure/Android/iOS continuam bloqueados, confirmado nos relatórios
-- anteriores). Não é uma suposição arbitrária: é logicamente impossível
-- existir uma linha aqui causada pelo Outlook antes de hoje.
update sync_conflicts set provider = 'google_calendar' where provider is null;

alter table sync_conflicts alter column provider set not null;
alter table sync_conflicts alter column provider set default 'google_calendar';
alter table sync_conflicts add constraint sync_conflicts_provider_check
  check (provider in ('google_calendar', 'outlook'));

create index if not exists idx_sync_conflicts_provider on sync_conflicts(provider);
