-- Sprint 01 — Fundação do banco de dados do Bússola

create table if not exists profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  nome text,
  foto text,
  tema text default 'claro',
  idioma text default 'pt-BR',
  tipo_usuario text default 'pessoal',
  created_at timestamptz default now()
);

create table if not exists settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  notifications_enabled boolean default true,
  dark_mode boolean default false,
  timezone text default 'America/Sao_Paulo',
  created_at timestamptz default now()
);

create table if not exists integrations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  provider text not null,
  status text default 'pendente',
  token text,
  created_at timestamptz default now()
);

-- Nova tabela: preferências inteligentes do usuário, base para a futura
-- camada de IA (Sprint 03+).
create table if not exists user_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  productivity_style text,
  preferred_work_hours text,
  planning_mode text,
  ai_enabled boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Segurança: cada pessoa só acessa os próprios dados.
alter table profiles enable row level security;
alter table settings enable row level security;
alter table integrations enable row level security;
alter table user_preferences enable row level security;

create policy "profiles: dono acessa" on profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "settings: dono acessa" on settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "integrations: dono acessa" on integrations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "user_preferences: dono acessa" on user_preferences
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
