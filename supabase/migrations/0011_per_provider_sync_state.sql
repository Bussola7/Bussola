-- Correção da limitação residual identificada na correção anterior
-- (migration 0010): `last_synced_at`/`sync_origin` eram campos ÚNICOS por
-- evento, compartilhados entre qualquer provedor conectado.
--
-- INTERFERÊNCIA CONFIRMADA (não hipotética): um evento vinculado a Google
-- E Outlook ao mesmo tempo, editado localmente e sincronizado primeiro
-- com o Google, tinha `last_synced_at` atualizado para o momento da
-- sincronização do GOOGLE. Quando a sincronização do OUTLOOK rodava
-- depois (mesmo sem nenhuma edição nova), a comparação
-- `updated_at > last_synced_at` dava FALSO — porque `last_synced_at` já
-- tinha sido empurrado para depois de `updated_at` pelo Google — fazendo
-- o Outlook concluir, errado, que não precisava reenviar aquela edição,
-- quando na verdade ela nunca tinha chegado lá. Não perde dado (o pior
-- caso é uma atualização não propagada para o segundo provedor), mas é
-- uma inconsistência real, não presumida.
--
-- Nada é removido: `last_synced_at`/`sync_origin` continuam existindo,
-- intactos (não usados pela lógica nova, mas nenhum dado é apagado).
-- 100% reversível (drop das 4 colunas novas desfaz tudo).

alter table events add column if not exists google_last_synced_at timestamptz;
alter table events add column if not exists outlook_last_synced_at timestamptz;
alter table events add column if not exists google_sync_origin text;
alter table events add column if not exists outlook_sync_origin text;

alter table events add constraint events_google_sync_origin_check
  check (google_sync_origin is null or google_sync_origin in ('local', 'google', 'outlook', 'synced'));
alter table events add constraint events_outlook_sync_origin_check
  check (outlook_sync_origin is null or outlook_sync_origin in ('local', 'google', 'outlook', 'synced'));

-- Backfill SEGURO: os valores já existentes em `last_synced_at`/
-- `sync_origin` só podem ter vindo do Google — é logicamente impossível
-- existir um evento sincronizado pelo Outlook antes de hoje (a
-- integração com o Outlook nunca rodou contra infraestrutura real,
-- mesmo raciocínio já usado no backfill da migration 0010).
update events
  set google_last_synced_at = last_synced_at,
      google_sync_origin = sync_origin
  where last_synced_at is not null or sync_origin is distinct from 'local';
