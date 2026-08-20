# Bússola

Sistema pessoal de produtividade e performance — organiza vida
profissional, saúde, financeira e pessoal em um só lugar.

## MVP — 5 telas

1. **Hoje** — até 3 prioridades, tarefas do dia, compromissos do dia, tarefas atrasadas, resumo simples
2. **Tarefas** — criar, editar, concluir, excluir, por prioridade/prazo/área
3. **Agenda** — agenda própria (sem Google/Outlook), criar/editar/excluir compromissos, visão dia/semana
4. **Objetivos** — criar, escolher área, definir prazo, acompanhar progresso (%), concluir
5. **Performance** — tarefas concluídas, tarefas atrasadas, prioridades concluídas, objetivos em andamento, evolução semanal

Perfil/Configurações continuam existindo, acessados por um ícone na tela Hoje.

## Como rodar (num ambiente com Flutter instalado)

1. Gere as plataformas nativas, se ainda não existirem:
   ```
   flutter create --platforms=android,ios .
   ```
2. Copie `.env.example` para `.env` e preencha com a URL/chave anônima do seu projeto Supabase.
3. Rode as 7 migrações, em ordem, no seu banco Supabase (SQL Editor ou `supabase db push`):
   `supabase/migrations/0001` até `0007`.
4. `flutter pub get`
5. `flutter analyze`
6. `flutter test`
7. `flutter run`

## Arquitetura

```
lib/
├── core/                 → Design System, constantes, serviço do Supabase
├── shared/                → LifeArea (área de vida, usada por Tarefas e Objetivos)
├── app/                   → rotas, casca de navegação (5 abas), splash
└── features/
    ├── auth/              → cadastro, login, onboarding
    ├── agenda/            → calendário, eventos, categorias, recorrência
    ├── tasks/             → tarefas
    ├── goals/              → objetivos
    ├── performance/        → indicadores de execução
    ├── dashboard/         → tela "Hoje"
    ├── ai/                → placeholder da aba IA (fora do MVP atual)
    ├── profile/           → tela de Perfil
    └── settings/          → tela de Configurações
```

Arquitetura propositalmente simples: Model → Repository (fala direto com o Supabase) → Provider (Riverpod) → Tela. Sem camadas extras onde não trazem benefício real.

## Migrations (`supabase/migrations/`)

7 migrações, sequenciais, aditivas:
- `0001`–`0005`: fundação (perfis, configurações, agenda própria)
- `0006`: gatilho de `updated_at`
- `0007`: tabelas `tasks` e `goals`

## O que foi removido nesta versão

Toda a integração com Google Calendar e Outlook Calendar (OAuth, sincronização, Edge Functions, campos de sincronização no banco) — o Bússola agora é 100% independente de calendários externos.
