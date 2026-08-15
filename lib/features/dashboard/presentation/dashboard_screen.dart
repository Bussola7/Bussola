import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/components/loading_state.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/dashboard/data/dashboard_repository.dart';
import 'package:bussola/features/dashboard/presentation/widgets/day_statistics_card.dart';
import 'package:bussola/features/dashboard/presentation/widgets/google_sync_indicator.dart';
import 'package:bussola/features/dashboard/presentation/widgets/north_of_day_card.dart';

/// Tela "Hoje": primeira tela que a pessoa vê depois de logada.
///
/// O cartão "Norte do Dia" (Etapa 2.4) já usa dados reais, calculados só
/// com regras de negócio (ver `DaySummaryService`). "Radar", "Próximo
/// compromisso" e a linha do tempo ainda usam o [DashboardRepository] com
/// dados simulados — ficam para uma etapa futura ligarem à Agenda de verdade.
class DashboardScreen extends ConsumerWidget {
  final String nomeUsuario;
  final String userId;
  final DashboardRepository _repository = DashboardRepository();

  DashboardScreen({super.key, required this.nomeUsuario, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAtual = _formatarData(DateTime.now());

    return FutureBuilder(
      future: Future.wait([
        _repository.getResumoAgenda(),
        _repository.getProximoCompromisso(),
        _repository.getTimelineDoDia(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingState();

        final resumo = snapshot.data![0] as String;
        final proximo = snapshot.data![1] as TimelineItem;
        final timeline = snapshot.data![2] as List<TimelineItem>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 24, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bom dia, $nomeUsuario 👋', style: AppTextStyles.heading2),
                        Text(dataAtual, style: AppTextStyles.bodyMuted),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const GoogleSyncIndicator(),
              const SizedBox(height: 24),
              NorthOfDayCard(userId: userId),
              const SizedBox(height: 16),
              DayStatisticsCard(userId: userId),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Radar', style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 8),
                    Text('🟢 $resumo', style: AppTextStyles.body),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Próximo compromisso', style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 8),
                    Text('${proximo.horario} — ${proximo.titulo}', style: AppTextStyles.body),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Linha do tempo', style: AppTextStyles.heading2),
              const SizedBox(height: 12),
              ...timeline.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(width: 56, child: Text(item.horario, style: AppTextStyles.bodyMuted)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.titulo, style: AppTextStyles.body)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatarData(DateTime data) {
    const meses = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    return '${data.day} de ${meses[data.month - 1]}';
  }
}
