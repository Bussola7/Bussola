-- Sprint 03 — Etapa 3.1, fase final
--
-- Coluna nova, motivo: a tela de Integrações agora tem um alternador de
-- "sincronização automática" — precisa de algum lugar para lembrar a
-- preferência da pessoa entre sessões. Não guarda nenhuma lógica de
-- execução em si (ver limitação no relatório: o agendamento em segundo
-- plano de verdade não foi implementado nesta etapa, só a preferência).

alter table integrations add column if not exists auto_sync_enabled boolean not null default false;
