import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/data/models/calendar_model.dart';
import 'package:bussola/features/agenda/presentation/providers/calendar_provider.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/integrations/presentation/providers/integration_provider.dart';
import 'package:bussola/features/integrations/presentation/screens/integrations_screen.dart';

/// Tela de Configurações. Notificações, modo escuro e idioma continuam
/// só estrutura visual (Sprint 01) — a seção "Google Calendar" (Etapa
/// 3.1) já reflete o estado real da integração via `IntegrationNotifier`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Preferência ainda só local/em memória — persistir isso (tabela
  // `settings`, já criada na Sprint 01) e realmente agendar a
  // sincronização automática ficam para uma próxima etapa. Ver
  // limitações no relatório desta etapa.
  bool _sincronizacaoAutomatica = false;

  String _defaultCalendarId(List<CalendarModel> calendars) {
    if (calendars.isEmpty) return '';
    final padrao = calendars.where((c) => c.isDefault);
    return padrao.isNotEmpty ? padrao.first.id : calendars.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final integrationState = ref.watch(integrationNotifierProvider);
    final userId = ref.watch(authNotifierProvider).user?.id;
    final calendars = ref.watch(calendarNotifierProvider).calendars;
    final conectado = integrationState.status != IntegrationStatusUi.disconnected;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Configurações', style: AppTextStyles.heading1),
        const SizedBox(height: 24),
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: Text('Notificações', style: AppTextStyles.body),
        ),
        SwitchListTile(
          value: false,
          onChanged: (_) {},
          title: Text('Modo escuro', style: AppTextStyles.body),
        ),
        ListTile(
          title: Text('Idioma', style: AppTextStyles.body),
          trailing: Text('Português', style: AppTextStyles.bodyMuted),
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        Text('Google Calendar', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Integrações', style: AppTextStyles.body),
          subtitle: Text(conectado ? 'Conectado' : 'Não conectado', style: AppTextStyles.bodyMuted),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IntegrationsScreen())),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _sincronizacaoAutomatica,
          onChanged: conectado ? (v) => setState(() => _sincronizacaoAutomatica = v) : null,
          title: Text('Sincronização automática', style: AppTextStyles.body),
          subtitle: Text(
            conectado ? 'Estrutura pronta — agendamento real ainda não implementado' : 'Conecte o Google Calendar primeiro',
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Última sincronização', style: AppTextStyles.body),
          trailing: Text(_formatarData(integrationState.lastSyncAt), style: AppTextStyles.bodyMuted),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Sincronizar agora', style: AppTextStyles.body.copyWith(color: AppColors.primary)),
          enabled: conectado && userId != null && integrationState.status != IntegrationStatusUi.syncing,
          onTap: userId == null
              ? null
              : () => ref.read(integrationNotifierProvider.notifier).syncNow(
                    userId: userId,
                    defaultCalendarId: _defaultCalendarId(calendars),
                  ),
        ),
      ],
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return 'nunca';
    final hora = '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    return 'Hoje às $hora';
  }
}
