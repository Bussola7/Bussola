import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bussola/core/constants/app_constants.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';

/// Tela inicial exibida enquanto o app decide para onde navegar: direto
/// para /home se já existe uma sessão do Supabase válida (restaurada
/// automaticamente no Supabase.initialize() do main.dart), ou para
/// /login caso contrário.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.9, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logado = ref.read(authNotifierProvider).user != null;
      context.go(logado ? '/home' : '/login');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: const Icon(Icons.explore, size: 96, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(AppConstants.appName, style: AppTextStyles.heading1.copyWith(color: Colors.white)),
            const SizedBox(height: 4),
            Text(AppConstants.appTagline, style: AppTextStyles.bodyMuted.copyWith(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
