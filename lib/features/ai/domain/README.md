# features/ai/domain/

Reservada para a lógica de negócio da futura integração com IA (ex: um
`AiSuggestionService`, casos de uso de sugestão de horários, etc.).

Nenhum código ainda — esta etapa (2.4) só prepara o lugar na arquitetura
Feature First. Toda a "inteligência" atual do Bússola (recorrência,
conflitos, tempo livre, Norte do Dia) mora em `features/agenda/domain/`,
porque ainda é 100% baseada em regras, não em IA.
