-- Áreas de vida: "profissional" vira "trabalho" (o valor salvo muda de
-- verdade, não é só troca de rótulo na exibição), e "estudos" entra como
-- área nova — pedido pra bater com os 4 ícones da tela Hoje (Saúde,
-- Trabalho, Pessoal, Estudos). "financeiro" continua um valor válido no
-- banco, só não tem botão correspondente na Hoje por enquanto.

-- Solta a constraint antes de migrar os dados (senão a linha antiga com
-- 'profissional' não conseguiria virar 'trabalho' — a constraint velha
-- não conhece esse valor ainda).
alter table tasks drop constraint tasks_area_check;
alter table goals drop constraint goals_area_check;

update tasks set area = 'trabalho' where area = 'profissional';
update goals set area = 'trabalho' where area = 'profissional';

alter table tasks add constraint tasks_area_check
  check (area in ('trabalho', 'saude', 'financeiro', 'pessoal', 'estudos'));
alter table goals add constraint goals_area_check
  check (area in ('trabalho', 'saude', 'financeiro', 'pessoal', 'estudos'));

-- Compromissos não tinham nenhuma área de vida até agora — coluna nova,
-- opcional (nem todo evento precisa estar associado a uma área).
alter table events add column life_area text
  check (life_area in ('trabalho', 'saude', 'financeiro', 'pessoal', 'estudos'));
