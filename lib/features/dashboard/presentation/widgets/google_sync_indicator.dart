import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/integrations/presentation/providers/integration_provider.dart';
import 'package:bussola/features/integrations/presentation/screens/integrations_screen.dart';

/// Indicador discreto do status da sincronização com o Google Calendar,
/// para o Dashboard. De propósito minimalista — só mostra o status, sem
/// nenhum detalhe (isso mora na `IntegrationsScreen`); tocar nele leva
/// para lá.
///
/// CORREÇÃO (auditoria Etapa 3.2): a versão anterior era um
/// `ConsumerWidget` que chamava `loadStatus()` dentro do `build()`, toda
/// vez que a condição "ainda não carregado" fosse verdadeira. Só que
/// `loadStatus()`, para quem nunca conectou, grava um estado que CONTINUA
/// satisfazendo essa mesma condição — e cada nova gravação de estado
/// dispara um novo rebuild, que dispara `loadStatus()` de novo: um loop
/// infinito de consultas ao Supabase, a cada frame, para todo mundo que
/// nunca conectou o Google Calendar. Agora é `ConsumerStatefulWidget` e
/// `loadStatus()` só é chamado UMA VEZ, no `initState`.
class GoogleSyncIndicator extends ConsumerStatefulWidget {
  const GoogleSyncIndicator({super.key});

  @override
  ConsumerState<GoogleSyncIndicator> createState() => _GoogleSyncIndicatorState();
}

class _GoogleSyncIndicatorState extends ConsumerState<GoogleSyncIndicator> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authNotifierProvider).user?.id;
      if (userId != null) {
        ref.read(integrationNotifierProvider.notifier).loadStatus(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authNotifierProvider).user?.id;
    if (userId == null) return const SizedBox.shrink();

    final integrationState = ref.watch(integrationNotifierProvider);
    final (emoji, texto, cor) = _visual(integrationState.status);

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IntegrationsScreen())),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: cor.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text('Google Calendar', style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
            const SizedBox(width: 4),
            Text(texto, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12, color: cor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  (String, String, Color) _visual(IntegrationStatusUi status) {
    switch (status) {
      case IntegrationStatusUi.connected:
      case IntegrationStatusUi.synced:
        return ('🟢', 'Sincronizado', AppColors.secondary);
      case IntegrationStatusUi.syncing:
        return ('🟡', 'Sincronizando', AppColors.accent);
      case IntegrationStatusUi.conflict:
        return ('🟡', 'Conflitos', AppColors.accent);
      case IntegrationStatusUi.connecting:
        return ('🟡', 'Conectando', AppColors.accent);
      case IntegrationStatusUi.tokenExpired:
      case IntegrationStatusUi.error:
      case IntegrationStatusUi.disconnected:
        return ('🔴', 'Desconectado', AppColors.textMuted);
    }
  }
}
