import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/models/sync_conflict_model.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/services/outlook_auth_service.dart';
import 'package:bussola/features/integrations/domain/usecases/connect_google_calendar_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/disconnect_google_calendar_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/get_google_integration_status_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/get_google_sync_conflicts_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/sync_google_calendar_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/sync_outlook_calendar_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/toggle_google_auto_sync_usecase.dart';

/// Os 8 estados da integração — a UI (`IntegrationScreen`, indicador do
/// Dashboard) só olha para isto, nunca para o token ou para o resultado
/// técnico de uma chamada HTTP. Já era genérico antes desta etapa (nenhum
/// valor menciona "Google") — por isso serve para qualquer provedor sem
/// nenhuma mudança.
enum IntegrationStatusUi {
  disconnected,
  connecting,
  connected,
  syncing,
  synced,
  error,
  tokenExpired,
  conflict,
}

/// Estado imutável exposto pelo `IntegrationNotifier`. **Nunca** contém
/// `access_token`, `refresh_token` ou qualquer segredo — só o que a UI
/// precisa para se desenhar. Já era genérico antes desta etapa — cada
/// instância de `IntegrationNotifier` representa UM provedor (Google OU
/// Outlook); a distinção entre os dois está em QUAL provider Riverpod
/// você está observando, não num campo dentro deste estado.
class IntegrationState {
  final IntegrationStatusUi status;
  final DateTime? lastSyncAt;
  final SyncDirection? lastSyncDirection;
  final String? friendlyErrorMessage;
  final int conflictsInLastSync;
  final bool autoSyncEnabled;

  const IntegrationState({
    this.status = IntegrationStatusUi.disconnected,
    this.lastSyncAt,
    this.lastSyncDirection,
    this.friendlyErrorMessage,
    this.conflictsInLastSync = 0,
    this.autoSyncEnabled = false,
  });

  /// Se nunca sincronizou antes — é o sinal que a `IntegrationScreen` usa
  /// para saber se deve perguntar a direção da primeira sincronização.
  bool get preciseEscolherPrimeiraSincronizacao => lastSyncAt == null;

  IntegrationState copyWith({
    IntegrationStatusUi? status,
    DateTime? lastSyncAt,
    SyncDirection? lastSyncDirection,
    String? friendlyErrorMessage,
    int? conflictsInLastSync,
    bool? autoSyncEnabled,
  }) {
    return IntegrationState(
      status: status ?? this.status,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncDirection: lastSyncDirection ?? this.lastSyncDirection,
      friendlyErrorMessage: friendlyErrorMessage,
      conflictsInLastSync: conflictsInLastSync ?? this.conflictsInLastSync,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
    );
  }
}

/// Orquestra os Use Cases/Services de UM provedor de calendário —
/// Google ou Outlook. A `IntegrationScreen` e o indicador do Dashboard só
/// falam com este Notifier — nunca com `GoogleAuthService`/
/// `OutlookAuthService`/`CalendarSyncService` direto.
///
/// GENERALIZADO NA ETAPA 1.10: antes, este Notifier só existia para o
/// Google, com os 5 Use Cases concretos do Google como dependências
/// diretas do construtor. Agora o construtor recebe FUNÇÕES genéricas —
/// a lógica de estado (loading/erro/sucesso/reconexão/trava contra
/// sincronizações simultâneas) não muda nada entre provedores, só QUEM
/// implementa cada operação muda. Isso evita duplicar toda essa lógica
/// numa classe `OutlookIntegrationNotifier` separada.
///
/// Duas fábricas nomeadas montam as funções certas para cada provedor:
/// [IntegrationNotifier.forGoogle] (comportamento idêntico a antes desta
/// etapa — nenhuma mudança para quem já usa `integrationNotifierProvider`)
/// e [IntegrationNotifier.forOutlook] (novo).
class IntegrationNotifier extends StateNotifier<IntegrationState> {
  final Future<bool> Function() _connect;
  final Future<void> Function(String userId) _disconnect;
  final Future<SyncResult> Function({required String userId, required String defaultCalendarId, SyncDirection direction}) _sync;
  final Future<CalendarIntegrationModel?> Function(String userId) _getStatus;

  /// `null` quando o provedor ainda não suporta alternar sincronização
  /// automática — é o caso do Outlook nesta etapa (ver pendências no
  /// relatório). `setAutoSync()` vira um no-op seguro nesse caso, não um erro.
  final Future<void> Function({required String userId, required bool enabled})? _toggleAutoSync;

  bool _sincronizando = false; // trava contra sincronizações simultâneas

  IntegrationNotifier({
    required Future<bool> Function() connect,
    required Future<void> Function(String userId) disconnect,
    required Future<SyncResult> Function({required String userId, required String defaultCalendarId, SyncDirection direction}) sync,
    required Future<CalendarIntegrationModel?> Function(String userId) getStatus,
    Future<void> Function({required String userId, required bool enabled})? toggleAutoSync,
  })  : _connect = connect,
        _disconnect = disconnect,
        _sync = sync,
        _getStatus = getStatus,
        _toggleAutoSync = toggleAutoSync,
        super(const IntegrationState());

  /// Fábrica para o Google — comportamento 100% idêntico ao Notifier de
  /// antes desta etapa (mesmos 5 Use Cases, mesmos valores-padrão).
  factory IntegrationNotifier.forGoogle({
    ConnectGoogleCalendarUseCase? connect,
    DisconnectGoogleCalendarUseCase? disconnect,
    SyncGoogleCalendarUseCase? sync,
    GetGoogleIntegrationStatusUseCase? getStatus,
    ToggleGoogleAutoSyncUseCase? toggleAutoSync,
  }) {
    final connectUC = connect ?? ConnectGoogleCalendarUseCase();
    final disconnectUC = disconnect ?? DisconnectGoogleCalendarUseCase();
    final syncUC = sync ?? SyncGoogleCalendarUseCase();
    final statusUC = getStatus ?? GetGoogleIntegrationStatusUseCase();
    final toggleUC = toggleAutoSync ?? ToggleGoogleAutoSyncUseCase();
    return IntegrationNotifier(
      connect: connectUC.execute,
      disconnect: disconnectUC.execute,
      sync: syncUC.execute,
      getStatus: statusUC.execute,
      toggleAutoSync: toggleUC.execute,
    );
  }

  /// Fábrica para o Outlook — usa só o que já existe
  /// (`OutlookAuthService`, `SyncOutlookCalendarUseCase`). Sem alternância
  /// de sincronização automática ainda (`toggleAutoSync` fica `null`) —
  /// não existe `ToggleOutlookAutoSyncUseCase`, e criar um não fazia
  /// parte desta etapa.
  factory IntegrationNotifier.forOutlook({
    OutlookAuthService? authService,
    SyncOutlookCalendarUseCase? sync,
  }) {
    final auth = authService ?? OutlookAuthService();
    final syncUC = sync ?? SyncOutlookCalendarUseCase();
    return IntegrationNotifier(
      connect: auth.connect,
      // `OutlookAuthService.disconnect` usa parâmetro NOMEADO
      // (`{required userId}`), diferente do `DisconnectGoogleCalendarUseCase.execute`
      // (posicional) — por isso precisa deste adaptador, em vez de um tear-off direto.
      disconnect: (userId) => auth.disconnect(userId: userId),
      sync: syncUC.execute,
      getStatus: auth.getIntegrationStatus,
    );
  }

  Future<void> loadStatus(String userId) async {
    final integration = await _getStatus(userId);
    if (integration == null || !integration.isConnected) {
      state = state.copyWith(status: IntegrationStatusUi.disconnected);
      return;
    }
    state = state.copyWith(
      status: IntegrationStatusUi.connected,
      lastSyncAt: integration.lastSyncAt,
      autoSyncEnabled: integration.autoSyncEnabled,
    );
  }

  /// Se o provedor não suporta alternar sincronização automática ainda
  /// (`_toggleAutoSync == null` — caso do Outlook nesta etapa), não faz
  /// nada — não é um erro, é uma capacidade que simplesmente não existe
  /// ainda para esse provedor.
  Future<void> setAutoSync({required String userId, required bool enabled}) async {
    if (_toggleAutoSync == null) return;
    // Otimista: atualiza a UI na hora, sem esperar o round-trip do banco
    // (é só uma preferência — não há risco real em mostrar antes de salvar).
    state = state.copyWith(autoSyncEnabled: enabled);
    await _toggleAutoSync(userId: userId, enabled: enabled);
  }

  Future<bool> connect() async {
    state = state.copyWith(status: IntegrationStatusUi.connecting, friendlyErrorMessage: null);
    try {
      final sucesso = await _connect();
      if (!sucesso) {
        state = state.copyWith(status: IntegrationStatusUi.disconnected);
        return false;
      }
      state = state.copyWith(status: IntegrationStatusUi.connected);
      return true;
    } catch (_) {
      state = state.copyWith(
        status: IntegrationStatusUi.error,
        friendlyErrorMessage: 'Não foi possível conectar agora. Tente novamente.',
      );
      return false;
    }
  }

  Future<void> disconnect(String userId) async {
    await _disconnect(userId);
    state = const IntegrationState(status: IntegrationStatusUi.disconnected);
  }

  /// Sincroniza — nunca deixa duas chamadas rodarem ao mesmo tempo
  /// (a trava [_sincronizando] garante isso, independentemente de quantas
  /// vezes a UI chame `syncNow` seguidas).
  Future<void> syncNow({
    required String userId,
    required String defaultCalendarId,
    SyncDirection direction = SyncDirection.ambos,
  }) async {
    if (_sincronizando) return;
    _sincronizando = true;
    state = state.copyWith(status: IntegrationStatusUi.syncing, friendlyErrorMessage: null);

    try {
      final resultado = await _sync(userId: userId, defaultCalendarId: defaultCalendarId, direction: direction);
      state = state.copyWith(
        status: resultado.conflitos > 0 ? IntegrationStatusUi.conflict : IntegrationStatusUi.synced,
        lastSyncAt: DateTime.now(),
        lastSyncDirection: direction,
        conflictsInLastSync: resultado.conflitos,
      );
    } on GoogleReconnectRequiredException {
      state = state.copyWith(
        status: IntegrationStatusUi.tokenExpired,
        friendlyErrorMessage: 'Sua conexão expirou. Reconecte para continuar sincronizando.',
      );
    } catch (_) {
      state = state.copyWith(
        status: IntegrationStatusUi.error,
        friendlyErrorMessage: 'Não foi possível sincronizar agora. Tente novamente em instantes.',
      );
    } finally {
      _sincronizando = false;
    }
  }
}

/// Provider do Google — inalterado: mesmo tipo (`StateNotifierProvider`
/// simples, não `.family`), mesmo nome, mesmo comportamento observável.
/// Nenhuma tela existente precisa mudar nada por causa desta etapa.
final integrationNotifierProvider = StateNotifierProvider<IntegrationNotifier, IntegrationState>(
  (ref) => IntegrationNotifier.forGoogle(),
);

/// Provider do Outlook — novo nesta etapa. Provider SEPARADO do Google
/// (não um `.family` compartilhado) de propósito: evita qualquer risco de
/// quebrar a fiação já existente da UI do Google, que hoje só conhece
/// `integrationNotifierProvider`. Unificar os dois num único `.family`
/// fica para quando a UI de múltiplos provedores for construída (próxima
/// etapa) — é nesse momento que faz sentido decidir a forma final.
final outlookIntegrationNotifierProvider = StateNotifierProvider<IntegrationNotifier, IntegrationState>(
  (ref) => IntegrationNotifier.forOutlook(),
);

/// Conflitos registrados para o usuário (Google) — carregado sob demanda
/// quando a pessoa toca em "ver lista" no estado de conflito (não fica
/// sendo buscado o tempo todo).
///
/// `autoDispose` de propósito: sem isso, a primeira busca ficava em cache
/// para sempre — reabrir "Ver lista de conflitos" depois de uma NOVA
/// sincronização (com conflitos diferentes) continuaria mostrando a
/// lista antiga. Com `autoDispose`, a lista é buscada de novo toda vez
/// que a tela que a observa é reconstruída.
final syncConflictsProvider = FutureProvider.autoDispose.family<List<SyncConflictModel>, String>((ref, userId) {
  return GetGoogleSyncConflictsUseCase().execute(userId);
});
