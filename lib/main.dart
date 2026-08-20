import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const ProviderScope(child: BussolaApp()));
}

class BussolaApp extends ConsumerStatefulWidget {
  const BussolaApp({super.key});

  @override
  ConsumerState<BussolaApp> createState() => _BussolaAppState();
}

class _BussolaAppState extends ConsumerState<BussolaApp> {
  // Criado uma única vez: se fosse recriado a cada build (como antes,
  // dentro do próprio método build), o GoRouter perderia a navegação
  // atual e voltaria para /splash toda vez que o app precisasse
  // reconstruir por causa do Modo escuro — ou de qualquer outra mudança.
  final _router = AppRouter().router;

  @override
  Widget build(BuildContext context) {
    final darkModeEnabled = ref.watch(settingsNotifierProvider.select((s) => s.darkModeEnabled));

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}
