-- Sprint 02 — Etapa 2.3 (Experiência de Organização)
--
-- Nenhuma tabela ou coluna nova é necessária nesta etapa: `events.category_id`
-- e `events.priority` já existem desde 0002/0003, e `event_reminders` já
-- cobre múltiplos lembretes por evento. Esta migração só troca o VALOR do
-- ícone das 8 categorias padrão de um nome semântico ("briefcase") para o
-- emoji pedido no documento da etapa ("💼") — dado, não schema.

update categories set icon = '💼' where is_default = true and name = 'Trabalho';
update categories set icon = '👨‍👩‍👧' where is_default = true and name = 'Família';
update categories set icon = '❤️' where is_default = true and name = 'Saúde';
update categories set icon = '📚' where is_default = true and name = 'Estudos';
update categories set icon = '✈️' where is_default = true and name = 'Viagens';
update categories set icon = '🛒' where is_default = true and name = 'Compras';
update categories set icon = '🏃' where is_default = true and name = 'Exercícios';
update categories set icon = '🎉' where is_default = true and name = 'Lazer';

-- Atualiza o gatilho de boas-vindas (Etapa 1) para que todo NOVO cadastro
-- já receba as categorias com o emoji certo, não só quem já existia.
create or replace function public.seed_default_categories()
returns trigger as $$
begin
  insert into public.categories (user_id, name, icon, color, is_default) values
    (new.id, 'Trabalho',   '💼', '#2563EB', true),
    (new.id, 'Família',    '👨‍👩‍👧', '#10B981', true),
    (new.id, 'Saúde',      '❤️', '#EF4444', true),
    (new.id, 'Estudos',    '📚', '#F59E0B', true),
    (new.id, 'Viagens',    '✈️', '#0EA5E9', true),
    (new.id, 'Compras',    '🛒', '#A855F7', true),
    (new.id, 'Exercícios', '🏃', '#14B8A6', true),
    (new.id, 'Lazer',      '🎉', '#F97316', true);

  insert into public.calendars (user_id, name, color, is_default) values
    (new.id, 'Meu calendário', '#2563EB', true);

  return new;
end;
$$ language plpgsql security definer;
