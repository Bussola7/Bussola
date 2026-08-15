-- Sprint 02 — Etapa 2.4 (Inteligência da Agenda)
--
-- Por que 2 colunas novas: `events.recurrence_rule` (Etapa 1) já guarda o
-- TIPO da recorrência (ex: "semanal"), mas não tinha onde guardar até
-- quando ela se repete, nem um limite de quantas vezes. Sem isso, o
-- RecurrenceService não tem como saber quando parar de gerar ocorrências.
-- Não criamos uma tabela nova porque a informação pertence a UM evento
-- (o "pai" da recorrência) — uma coluna a mais é suficiente e mais barato
-- de consultar do que um JOIN.

alter table events add column if not exists recurrence_until timestamptz;
alter table events add column if not exists recurrence_count integer;

comment on column events.recurrence_until is 'Data/hora limite da recorrência (nulo = sem data final)';
comment on column events.recurrence_count is 'Número máximo de ocorrências (nulo = sem limite de quantidade)';
