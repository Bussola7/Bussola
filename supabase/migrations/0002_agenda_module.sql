-- Sprint 02 — Etapa 1: fundação do módulo Agenda
-- Substitui a tabela "integrations" da Sprint 01 nada — este arquivo só ADICIONA tabelas novas.

-- =========================================================
-- 1. calendars — permite múltiplos calendários no futuro
-- =========================================================
create table if not exists calendars (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  name text not null,
  color text not null default '#2563EB',
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================================================
-- 2. categories — 8 categorias padrão + personalizadas
-- =========================================================
create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  name text not null,
  icon text not null default 'label',
  color text not null default '#64748B',
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================================================
-- 3. events
-- =========================================================
create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  calendar_id uuid references calendars(id) not null,
  user_id uuid references auth.users(id) not null,
  title text not null,
  description text,
  start_datetime timestamptz not null,
  end_datetime timestamptz not null,
  timezone text not null default 'America/Sao_Paulo',
  all_day boolean not null default false,
  location text,
  -- Nota de implementação: o documento da Sprint pedia o campo "category" (texto livre).
  -- Como já existe uma tabela "categories" própria, usei "category_id" (uuid, com FK)
  -- em vez de um texto solto — assim a categoria de um evento sempre aponta para uma
  -- categoria real, e nunca fica com nome digitado errado ou duplicado.
  category_id uuid references categories(id),
  color text,
  priority text not null default 'media' check (priority in ('muito_alta', 'alta', 'media', 'baixa')),
  status text not null default 'confirmado' check (status in ('confirmado', 'pendente', 'cancelado')),
  recurrence_rule text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_event_dates check (end_datetime >= start_datetime)
);

create index if not exists idx_events_user_id on events(user_id);
create index if not exists idx_events_calendar_id on events(calendar_id);
create index if not exists idx_events_start_datetime on events(start_datetime);

-- =========================================================
-- 4. event_reminders
-- =========================================================
create table if not exists event_reminders (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  minutes_before integer not null default 0,
  type text not null default 'no_horario'
    check (type in ('no_horario', '5_min', '15_min', '30_min', '1_hora', '1_dia', 'personalizado')),
  created_at timestamptz not null default now()
);

create index if not exists idx_event_reminders_event_id on event_reminders(event_id);

-- =========================================================
-- 5. event_participants
-- =========================================================
create table if not exists event_participants (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  participant_name text not null,
  participant_email text,
  status text not null default 'pendente' check (status in ('pendente', 'aceito', 'recusado')),
  created_at timestamptz not null default now()
);

create index if not exists idx_event_participants_event_id on event_participants(event_id);

-- =========================================================
-- Row Level Security — cada usuário só acessa os próprios dados
-- =========================================================
alter table calendars enable row level security;
alter table categories enable row level security;
alter table events enable row level security;
alter table event_reminders enable row level security;
alter table event_participants enable row level security;

-- calendars: dono acessa (leitura, inserção, atualização, exclusão)
create policy "calendars_select_own" on calendars for select using (auth.uid() = user_id);
create policy "calendars_insert_own" on calendars for insert with check (auth.uid() = user_id);
create policy "calendars_update_own" on calendars for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "calendars_delete_own" on calendars for delete using (auth.uid() = user_id);

-- categories: dono acessa
create policy "categories_select_own" on categories for select using (auth.uid() = user_id);
create policy "categories_insert_own" on categories for insert with check (auth.uid() = user_id);
create policy "categories_update_own" on categories for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "categories_delete_own" on categories for delete using (auth.uid() = user_id);

-- events: dono acessa
create policy "events_select_own" on events for select using (auth.uid() = user_id);
create policy "events_insert_own" on events for insert with check (auth.uid() = user_id);
create policy "events_update_own" on events for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "events_delete_own" on events for delete using (auth.uid() = user_id);

-- event_reminders: acesso indireto — só quem é dono do evento relacionado
create policy "event_reminders_select_own" on event_reminders for select
  using (exists (select 1 from events e where e.id = event_reminders.event_id and e.user_id = auth.uid()));
create policy "event_reminders_insert_own" on event_reminders for insert
  with check (exists (select 1 from events e where e.id = event_reminders.event_id and e.user_id = auth.uid()));
create policy "event_reminders_update_own" on event_reminders for update
  using (exists (select 1 from events e where e.id = event_reminders.event_id and e.user_id = auth.uid()))
  with check (exists (select 1 from events e where e.id = event_reminders.event_id and e.user_id = auth.uid()));
create policy "event_reminders_delete_own" on event_reminders for delete
  using (exists (select 1 from events e where e.id = event_reminders.event_id and e.user_id = auth.uid()));

-- event_participants: acesso indireto — só quem é dono do evento relacionado
create policy "event_participants_select_own" on event_participants for select
  using (exists (select 1 from events e where e.id = event_participants.event_id and e.user_id = auth.uid()));
create policy "event_participants_insert_own" on event_participants for insert
  with check (exists (select 1 from events e where e.id = event_participants.event_id and e.user_id = auth.uid()));
create policy "event_participants_update_own" on event_participants for update
  using (exists (select 1 from events e where e.id = event_participants.event_id and e.user_id = auth.uid()))
  with check (exists (select 1 from events e where e.id = event_participants.event_id and e.user_id = auth.uid()));
create policy "event_participants_delete_own" on event_participants for delete
  using (exists (select 1 from events e where e.id = event_participants.event_id and e.user_id = auth.uid()));

-- =========================================================
-- Categorias padrão automáticas para todo novo usuário
-- =========================================================
create or replace function public.seed_default_categories()
returns trigger as $$
begin
  insert into public.categories (user_id, name, icon, color, is_default) values
    (new.id, 'Trabalho',   'briefcase',   '#2563EB', true),
    (new.id, 'Família',    'home',        '#10B981', true),
    (new.id, 'Saúde',      'heart',       '#EF4444', true),
    (new.id, 'Estudos',    'book',        '#F59E0B', true),
    (new.id, 'Viagens',    'plane',       '#0EA5E9', true),
    (new.id, 'Compras',    'shopping',    '#A855F7', true),
    (new.id, 'Exercícios', 'run',         '#14B8A6', true),
    (new.id, 'Lazer',      'sun',         '#F97316', true);

  insert into public.calendars (user_id, name, color, is_default) values
    (new.id, 'Meu calendário', '#2563EB', true);

  return new;
end;
$$ language plpgsql security definer;

-- Dispara assim que um novo usuário é criado no Supabase Auth
drop trigger if exists on_auth_user_created_seed_agenda on auth.users;
create trigger on_auth_user_created_seed_agenda
  after insert on auth.users
  for each row execute function public.seed_default_categories();
