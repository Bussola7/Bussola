-- V1 do Bússola: tabelas de Tarefas e Objetivos, organizadas pelas 4
-- áreas de vida (profissional, saúde, financeiro, pessoal).

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  title text not null,
  description text,
  area text not null default 'pessoal' check (area in ('profissional', 'saude', 'financeiro', 'pessoal')),
  priority text not null default 'media' check (priority in ('muito_alta', 'alta', 'media', 'baixa')),
  status text not null default 'pendente' check (status in ('pendente', 'concluida')),
  due_date date,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_tasks_user_due_date on tasks (user_id, due_date);
create index if not exists idx_tasks_user_status on tasks (user_id, status);

create table if not exists goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  title text not null,
  description text,
  area text not null default 'pessoal' check (area in ('profissional', 'saude', 'financeiro', 'pessoal')),
  due_date date,
  progress_percent integer not null default 0 check (progress_percent between 0 and 100),
  status text not null default 'em_andamento' check (status in ('em_andamento', 'concluido')),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_goals_user_status on goals (user_id, status);

alter table tasks enable row level security;
alter table goals enable row level security;

create policy "tasks: dono acessa" on tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "goals: dono acessa" on goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Mesmo gatilho de updated_at usado em events, aplicado aqui também.
drop trigger if exists trg_tasks_set_updated_at on tasks;
create trigger trg_tasks_set_updated_at
  before update on tasks
  for each row execute function public.set_updated_at();

drop trigger if exists trg_goals_set_updated_at on goals;
create trigger trg_goals_set_updated_at
  before update on goals
  for each row execute function public.set_updated_at();
