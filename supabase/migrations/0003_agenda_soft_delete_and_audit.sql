-- Sprint 02 — Etapa 1 (ajustes pós-revisão)
-- Adiciona soft delete, auditoria (created_by/updated_by) e índices que
-- faltavam na tabela events. Não altera dados existentes.

-- Soft delete: evento "excluído" continua no banco, só marcado.
alter table events add column if not exists deleted_at timestamptz;

-- Auditoria — quem criou/editou. Hoje sempre é o próprio dono (user_id),
-- mas fica pronto para quando outra pessoa puder editar um evento
-- compartilhado.
alter table events add column if not exists created_by uuid references auth.users(id);
alter table events add column if not exists updated_by uuid references auth.users(id);

-- Preenche as colunas novas para linhas que já existirem (nesta etapa,
-- não deve haver nenhuma ainda, mas a migração fica segura de qualquer forma).
update events set created_by = user_id where created_by is null;
update events set updated_by = user_id where updated_by is null;

-- Confirmação: todas as chaves primárias do módulo já usam uuid com
-- gen_random_uuid() por padrão (ver 0002_agenda_module.sql) — nenhuma
-- mudança necessária aqui, só o registro de que foi conferido.

-- Índices que faltavam (user_id e calendar_id já existiam desde 0002).
create index if not exists idx_events_end_datetime on events(end_datetime);
create index if not exists idx_events_deleted_at on events(deleted_at);
create index if not exists idx_calendars_user_id on calendars(user_id);
create index if not exists idx_categories_user_id on categories(user_id);

-- Índice composto: consulta mais comum do app é "eventos do usuário X
-- num intervalo de datas" — este índice cobre exatamente essa consulta.
create index if not exists idx_events_user_period on events(user_id, start_datetime, end_datetime);
