-- Gatilho que mantém `updated_at` de `events` sempre correto em qualquer
-- edição — sem depender do código Dart lembrar de enviar o campo.
-- (Versão simplificada da V1: sem sincronização externa, não precisa mais
-- distinguir "conteúdo" de "bookkeeping de sync".)

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_events_set_updated_at on events;
create trigger trg_events_set_updated_at
  before update on events
  for each row execute function public.set_updated_at();
