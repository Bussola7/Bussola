# shared/

Aqui entram widgets, modelos ou utilitários usados por **duas ou mais
features**, mas que não são primitivas do Design System (essas ficam em
`core/`).

Exemplo de quando algo vem parar aqui: se o módulo `agenda` e o módulo
`ai` (Sprint 03+) precisarem do mesmo widget de "seletor de horário", ele
sai da feature onde nasceu e vem para cá — assim nenhuma feature depende
diretamente da outra.

Vazio por enquanto: nada em Agenda, Auth, Dashboard, AI, Profile ou
Settings precisou ser compartilhado ainda.
