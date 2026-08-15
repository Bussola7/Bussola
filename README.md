# Bússola

## Como rodar
1. Copie `.env.example` para `.env` e preencha com a URL e a chave anônima do seu projeto Supabase.
2. Rode as migrações, em ordem, no seu banco Supabase (SQL Editor ou CLI):
   - `supabase/migrations/0001_init.sql` (Sprint 01)
   - `supabase/migrations/0002_agenda_module.sql` (Sprint 02 — Etapa 1)
   - `supabase/migrations/0003_agenda_soft_delete_and_audit.sql` (Sprint 02 — Etapa 1, ajustes)
3. `flutter pub get`
4. `flutter run`

## Arquitetura: Clean Architecture + Feature First

```
lib/
├── core/                 → Design System, constantes, serviço do Supabase, utils
├── shared/                → widgets/utils usados por 2+ features (vazio por enquanto)
├── app/                   → composição do app: rotas (go_router), casca de navegação, splash
└── features/
    ├── auth/              → cadastro, login, onboarding
    │   ├── data/          → AuthRepository
    │   ├── domain/         → AuthNotifier + AuthState (Riverpod)
    │   └── presentation/   → telas de login/cadastro/onboarding
    ├── agenda/            → módulo Agenda Inteligente (Sprint 02)
    │   ├── data/           → models, datasources, repositories
    │   ├── domain/         → services (regra de negócio)
    │   └── presentation/   → providers (Riverpod) e telas
    ├── dashboard/         → tela "Hoje"
    ├── ai/                → placeholder da aba IA
    ├── profile/           → tela de Perfil
    ├── settings/          → tela de Configurações
    └── organizations/      → reservada para recursos corporativos (ainda sem código)
```

Cada feature tem sua própria fatia de apresentação/domínio/dados — times diferentes conseguem trabalhar em features diferentes sem esbarrar um no outro.

**Gerenciamento de estado**: `flutter_riverpod`. Nenhuma tela acessa o Supabase diretamente — o fluxo é sempre Provider → Service → Repository → Data Source → Supabase.

## Sprint 02 — Etapa 1 (fundação do módulo Agenda) — ajustada e aprovada

- Tabelas: `calendars`, `categories`, `events` (com soft delete via `deleted_at`, e auditoria via `created_by`/`updated_by`), `event_reminders`, `event_participants` — todas com RLS e chave primária `uuid`.
- Índices em `user_id`, `calendar_id`, `start_datetime`, `end_datetime` (+ um índice composto para a consulta mais comum: eventos de um usuário num período).
- Enums fortemente tipados: `Priority`, `EventStatus`, `RecurrenceType`, `ReminderType`, `ParticipantStatus`.
- Todos os models (`CalendarModel`, `CategoryModel`, `EventModel`, `ReminderModel`, `ParticipantModel`) com `fromJson`, `toJson` completo, `copyWith` e igualdade (`==`/`hashCode`).
- Categorias padrão e calendário padrão criados automaticamente no cadastro (gatilho no banco).

## Próximos passos — Sprint 02, Etapa 2 (sugestão)

1. `EventEditor` (formulário completo de criação/edição de evento)
2. Visualizações Lista e Dia do calendário
3. Visualizações Semana e Mês
4. `RecurrenceService` (cálculo das ocorrências repetidas)
5. `ConflictService` (aviso de sobreposição de horário)
6. `NorteDoDiaService` e `RadarService`, plugados no Dashboard
