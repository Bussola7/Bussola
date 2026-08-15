-- Sprint 03 — Etapa 3.2, auditoria final
--
-- Achado: a FK `sync_conflicts.event_id -> events(id)` foi criada sem
-- nenhuma ação de `on delete` (padrão do Postgres: `no action`, que
-- bloqueia a exclusão do evento referenciado). Hoje isso nunca é testado
-- na prática porque `events` só usa soft delete (nunca um DELETE de
-- verdade) — mas é uma bomba-relógio: se algum dia alguém rodar uma
-- limpeza física de eventos antigos, essa FK quebraria a exclusão sem
-- nenhum motivo funcional (o log de conflito não PRECISA do evento
-- continuar existindo — é só uma referência para consulta).
--
-- Correção: recriar a FK com `on delete set null`, para o log de
-- conflito sobreviver mesmo se o evento referenciado for excluído de
-- verdade algum dia.

alter table sync_conflicts drop constraint if exists sync_conflicts_event_id_fkey;
alter table sync_conflicts
  add constraint sync_conflicts_event_id_fkey
  foreign key (event_id) references events(id) on delete set null;
