import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/components/primary_button.dart';
import 'package:bussola/core/components/secondary_button.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/data/models/calendar_model.dart';
import 'package:bussola/features/integrations/data/models/sync_conflict_model.dart';
import 'package:bussola/features/agenda/presentation/providers/calendar_provider.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/presentation/providers/integration_provider.dart';

/// Tela de Integrações. Só fala com `IntegrationNotifier` (Riverpod) —
/// nunca com `GoogleAuthService`/`OutlookAuthService`/`CalendarSyncService`/
/// Repository direto.
///
/// ETAPA 1.11: passou a mostrar dois blocos independentes — Google Calendar
/// e Outlook Calendar — cada um observando seu próprio provider
/// (`integrationNotifierProvider`/`outlookIntegrationNotifierProvider`,
/// já criados na Etapa 1.10). O mapeamento "estado → UI" (os 8 estados de
/// `IntegrationStatusUi`) é o MESMO para os dois — por isso vive uma única
/// vez, em `_ProviderIntegrationCard`, parametrizado, em vez de duplicado
/// em dois widgets quase iguais.
class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Integrações'), backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ProviderIntegrationCard(
              title: 'Google Calendar',
              notifierProvider: integrationNotifierProvider,
              connectLabel: 'Conectar Google Calendar',
              reconnectLabel: 'Reconectar Google Calendar',
              disconnectedMessage: 'Conecte seu Google Calendar ao Bússola para manter seus compromissos sincronizados.',
              // Só o Google tem `GetGoogleSyncConflictsUseCase` — não existe
              // equivalente para o Outlook ainda (não criado nesta etapa,
              // conforme "não criar novos UseCases se os existentes forem
              // suficientes"). Ver limitação no relatório desta etapa.
              conflictsProvider: syncConflictsProvider,
              showAutoSync: true,
            ),
            const SizedBox(height: 20),
            _ProviderIntegrationCard(
              title: 'Outlook Calendar',
              notifierProvider: outlookIntegrationNotifierProvider,
              connectLabel: 'Conectar Outlook Calendar',
              reconnectLabel: 'Reconectar Outlook Calendar',
              disconnectedMessage: 'Conecte seu Outlook Calendar ao Bússola para manter seus compromissos sincronizados.',
              conflictsProvider: null, // ver nota acima
              // Auto-sync do Outlook não foi implementado (Etapa 1.10:
              // `IntegrationNotifier.forOutlook` não tem `toggleAutoSync`,
              // de propósito) — por isso o alternador nem aparece aqui,
              // em vez de aparecer e não fazer nada.
              showAutoSync: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloco de UI para UM provedor de calendário — encapsula todo o
/// mapeamento dos 8 estados de `IntegrationStatusUi` para widgets. Cada
/// instância observa seu próprio `notifierProvider`
/// (`StateNotifierProvider<IntegrationNotifier, IntegrationState>`) — é
/// esse parâmetro que diferencia Google de Outlook; a lógica de UI em si
/// é idêntica para os dois.
class _ProviderIntegrationCard extends ConsumerStatefulWidget {
  final String title;
  final StateNotifierProvider<IntegrationNotifier, IntegrationState> notifierProvider;
  final String connectLabel;
  final String reconnectLabel;
  final String disconnectedMessage;
  final AutoDisposeFutureProviderFamily<List<SyncConflictModel>, String>? conflictsProvider;
  final bool showAutoSync;

  const _ProviderIntegrationCard({
    required this.title,
    required this.notifierProvider,
    required this.connectLabel,
    required this.reconnectLabel,
    required this.disconnectedMessage,
    required this.conflictsProvider,
    required this.showAutoSync,
  });

  @override
  ConsumerState<_ProviderIntegrationCard> createState() => _ProviderIntegrationCardState();
}

class _ProviderIntegrationCardState extends ConsumerState<_ProviderIntegrationCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authNotifierProvider).user?.id;
      if (userId != null) ref.read(widget.notifierProvider.notifier).loadStatus(userId);
    });
  }

  String _defaultCalendarId(List<CalendarModel> calendars) {
    if (calendars.isEmpty) return '';
    final padrao = calendars.where((c) => c.isDefault);
    return padrao.isNotEmpty ? padrao.first.id : calendars.first.id;
  }

  Future<void> _conectar(String userId, List<CalendarModel> calendars) async {
    final sucesso = await ref.read(widget.notifierProvider.notifier).connect();
    if (!sucesso || !mounted) return;

    // "Ao retornar do OAuth... iniciar o fluxo da primeira sincronização."
    final direcao = await _perguntarDirecaoDaPrimeiraSincronizacao();
    if (direcao == null || !mounted) return; // pessoa fechou o diálogo sem escolher — não sincroniza sozinho

    await ref.read(widget.notifierProvider.notifier).syncNow(
          userId: userId,
          defaultCalendarId: _defaultCalendarId(calendars),
          direction: direcao,
        );
  }

  Future<SyncDirection?> _perguntarDirecaoDaPrimeiraSincronizacao() {
    return showDialog<SyncDirection>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Como deseja sincronizar sua agenda?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OpcaoDirecao(
              label: 'Importar eventos do ${widget.title} para o Bússola',
              onTap: () => Navigator.of(context).pop(SyncDirection.apenasImportar),
            ),
            _OpcaoDirecao(
              label: 'Enviar eventos do Bússola para o ${widget.title}',
              onTap: () => Navigator.of(context).pop(SyncDirection.apenasExportar),
            ),
            _OpcaoDirecao(
              label: 'Sincronizar os dois lados',
              onTap: () => Navigator.of(context).pop(SyncDirection.ambos),
            ),
          ],
        ),
      ),
    );
  }

  void _verConflitos(String userId) {
    final provider = widget.conflictsProvider;
    if (provider == null) return; // este provedor não tem lista de conflitos disponível ainda
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConflictsSheet(userId: userId, conflictsProvider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final integrationState = ref.watch(widget.notifierProvider);
    final userId = ref.watch(authNotifierProvider).user?.id;
    final calendars = ref.watch(calendarNotifierProvider).calendars;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: AppTextStyles.heading2),
          const SizedBox(height: 16),
          if (userId == null)
            Text('Faça login para conectar seu ${widget.title}.', style: AppTextStyles.bodyMuted)
          else
            _buildEstado(integrationState, userId, calendars),
        ],
      ),
    );
  }

  Widget _buildEstado(IntegrationState state, String userId, List<CalendarModel> calendars) {
    switch (state.status) {
      case IntegrationStatusUi.disconnected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.disconnectedMessage, style: AppTextStyles.bodyMuted),
            const SizedBox(height: 16),
            PrimaryButton(label: widget.connectLabel, onPressed: () => _conectar(userId, calendars)),
          ],
        );

      case IntegrationStatusUi.connecting:
        return const _LinhaStatus(icone: null, texto: 'Conectando...', mostrarSpinner: true);

      case IntegrationStatusUi.connected:
      case IntegrationStatusUi.synced:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LinhaStatus(icone: '🟢', texto: 'Conectado'),
            const SizedBox(height: 8),
            Text('Última sincronização: ${_formatarData(state.lastSyncAt)}', style: AppTextStyles.bodyMuted),
            if (state.lastSyncDirection != null)
              Text('Direção: ${_formatarDirecao(state.lastSyncDirection!)}', style: AppTextStyles.bodyMuted),
            const SizedBox(height: 16),
            if (widget.showAutoSync)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: state.autoSyncEnabled,
                onChanged: (v) => ref.read(widget.notifierProvider.notifier).setAutoSync(userId: userId, enabled: v),
                title: Text('Sincronização automática', style: AppTextStyles.body),
              ),
            if (widget.showAutoSync) const SizedBox(height: 12),
            PrimaryButton(
              label: 'Sincronizar agora',
              onPressed: () => ref.read(widget.notifierProvider.notifier).syncNow(
                    userId: userId,
                    defaultCalendarId: _defaultCalendarId(calendars),
                  ),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Desconectar',
              onPressed: () => ref.read(widget.notifierProvider.notifier).disconnect(userId),
            ),
          ],
        );

      case IntegrationStatusUi.syncing:
        return const _LinhaStatus(icone: '⟳', texto: 'Sincronizando...', mostrarSpinner: true);

      case IntegrationStatusUi.tokenExpired:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.friendlyErrorMessage ?? 'Sua conexão expirou. É necessário reconectar.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: widget.reconnectLabel, onPressed: () => _conectar(userId, calendars)),
          ],
        );

      case IntegrationStatusUi.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nunca mostra exceção técnica/stacktrace — só a mensagem
            // amigável que o Notifier já preparou.
            Text(
              state.friendlyErrorMessage ?? 'Algo deu errado. Tente novamente mais tarde.',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Tentar novamente',
              onPressed: () => ref.read(widget.notifierProvider.notifier).syncNow(
                    userId: userId,
                    defaultCalendarId: _defaultCalendarId(calendars),
                  ),
            ),
          ],
        );

      case IntegrationStatusUi.conflict:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LinhaStatus(icone: '🟡', texto: 'Sincronizado com conflitos'),
            const SizedBox(height: 8),
            Text(
              '${state.conflictsInLastSync} conflito${state.conflictsInLastSync == 1 ? '' : 's'} resolvido${state.conflictsInLastSync == 1 ? '' : 's'} automaticamente (última alteração venceu).',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: 12),
            if (widget.conflictsProvider != null)
              TextButton(onPressed: () => _verConflitos(userId), child: const Text('Ver lista de conflitos')),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Sincronizar agora',
              onPressed: () => ref.read(widget.notifierProvider.notifier).syncNow(
                    userId: userId,
                    defaultCalendarId: _defaultCalendarId(calendars),
                  ),
            ),
          ],
        );
    }
  }

  String _formatarData(DateTime? data) {
    if (data == null) return 'nunca';
    final hoje = DateTime.now();
    final ehHoje = data.year == hoje.year && data.month == hoje.month && data.day == hoje.day;
    final hora = '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    return ehHoje ? 'Hoje às $hora' : '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')} às $hora';
  }

  String _formatarDirecao(SyncDirection direcao) {
    switch (direcao) {
      case SyncDirection.apenasImportar:
        return 'Importando';
      case SyncDirection.apenasExportar:
        return 'Enviando';
      case SyncDirection.ambos:
        return 'Bidirecional';
    }
  }
}

class _OpcaoDirecao extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OpcaoDirecao({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SecondaryButton(label: label, onPressed: onTap),
    );
  }
}

class _LinhaStatus extends StatelessWidget {
  final String? icone;
  final String texto;
  final bool mostrarSpinner;

  const _LinhaStatus({this.icone, required this.texto, this.mostrarSpinner = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (mostrarSpinner)
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        else if (icone != null)
          Text(icone!, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(texto, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ConflictsSheet extends ConsumerWidget {
  final String userId;
  final AutoDisposeFutureProviderFamily<List<SyncConflictModel>, String> conflictsProvider;

  const _ConflictsSheet({required this.userId, required this.conflictsProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflitosAsync = ref.watch(conflictsProvider(userId));

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Conflitos de sincronização', style: AppTextStyles.heading2),
          const SizedBox(height: 4),
          Text(
            'Resolvidos automaticamente — a alteração mais recente venceu. Escolher manualmente ainda não é possível nesta versão.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 16),
          Flexible(
            child: conflitosAsync.when(
              data: (conflitos) => conflitos.isEmpty
                  ? Text('Nenhum conflito registrado.', style: AppTextStyles.bodyMuted)
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: conflitos.length,
                      itemBuilder: (context, i) {
                        final c = conflitos[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(c.resolutionDetails ?? c.conflictType.toDb(), style: AppTextStyles.body),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text('Não foi possível carregar os conflitos.', style: AppTextStyles.bodyMuted),
            ),
          ),
        ],
      ),
    );
  }
}
