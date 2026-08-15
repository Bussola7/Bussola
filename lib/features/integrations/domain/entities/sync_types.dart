/// Direção da sincronização. Usada principalmente na PRIMEIRA
/// sincronização (quando a pessoa escolhe como quer começar) — nas
/// seguintes, o padrão é sempre `ambos` (bidirecional de verdade).
enum SyncDirection { apenasImportar, apenasExportar, ambos }

/// Lançada quando as credenciais do calendário remoto (Google, Outlook,
/// ...) expiraram ou são inválidas NO MEIO de uma chamada — o
/// `CalendarSyncService` a captura para tentar renovar o token uma vez.
///
/// Tipo de domínio, neutro de propósito: cada provedor tem seu próprio
/// erro específico (ex: `GoogleTokenExpiredException`, na camada de
/// dados do Google) — é responsabilidade do Repository concreto de cada
/// provedor capturar o erro específico e relançar este, na fronteira
/// entre a camada de dados e o domínio. O `CalendarSyncService` nunca
/// deve conhecer o erro específico de nenhum provedor.
class RemoteCalendarAuthExpiredException implements Exception {
  final String message;
  const RemoteCalendarAuthExpiredException(this.message);
}

/// Resultado de uma tentativa de renovação de token — quem chama usa
/// [reconnectRequired] para saber se deve pedir para a pessoa reconectar
/// em vez de tentar de novo sozinho (evita loop).
///
/// Vive aqui (não dentro de `GoogleAuthService`) pelo mesmo motivo do
/// [SyncResult]: é o tipo de retorno de `RemoteAuthService.refreshAccessToken`
/// — precisa ser neutro para a interface não vazar nada do Google.
class RefreshResult {
  final bool success;
  final bool reconnectRequired;

  const RefreshResult({required this.success, required this.reconnectRequired});
}

/// Lançada quando a conexão não pode continuar porque a conexão com o
/// calendário remoto precisa ser refeita (refresh_token inválido/revogado).
/// Tipo dedicado — em vez de a Presentation ter que "adivinhar" isso lendo
/// o texto de uma mensagem de erro genérica.
class GoogleReconnectRequiredException implements Exception {
  final String message;
  const GoogleReconnectRequiredException(this.message);
}

/// Resumo de uma rodada de sincronização — devolvido para a UI mostrar
/// algo mais útil que só "sincronizado com sucesso".
///
/// Vive em `domain/entities` (não dentro do `CalendarSyncService`) de
/// propósito: é o único jeito de a Presentation conhecer `SyncDirection`
/// e `SyncResult` sem precisar importar o Service — a Presentation só
/// pode depender de Use Cases e de entidades de domínio, nunca de Services
/// diretamente (nem para "só pegar um tipo").
class SyncResult {
  final int criadosNoBussola;
  final int criadosNoGoogle;
  final int atualizados;
  final int excluidos;
  final int conflitos;

  const SyncResult({
    this.criadosNoBussola = 0,
    this.criadosNoGoogle = 0,
    this.atualizados = 0,
    this.excluidos = 0,
    this.conflitos = 0,
  });
}
