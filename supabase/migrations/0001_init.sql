-- Fundação do banco de dados do Bússola (V1 simplificada — sem
-- integrações externas de calendário).

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

-- Preferências inteligentes do usuário, base para a futura camada de IA.
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
alter table user_preferences enable row level security;

create policy "profiles: dono acessa" on profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "settings: dono acessa" on settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "user_preferences: dono acessa" on user_preferences
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
