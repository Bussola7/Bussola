import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/custom_text_field.dart';
import 'package:bussola/core/components/primary_button.dart';
import 'package:bussola/core/components/secondary_button.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/validators.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';

/// Tela de login: email/senha + botões de Google e Apple.
/// Lê o estado via `ref.watch(authNotifierProvider)` e chama as ações via
/// `ref.read(authNotifierProvider.notifier)` — nunca fala com o Supabase direto.
class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onGoToRegister;

  const LoginScreen({super.key, required this.onLoginSuccess, required this.onGoToRegister});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authNotifierProvider.notifier).login(
          email: _emailController.text.trim(),
          senha: _senhaController.text,
        );
    if (success && mounted) widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text('Bem-vindo de volta', style: AppTextStyles.heading1),
                const SizedBox(height: 8),
                Text('Entre para continuar organizando seu tempo.', style: AppTextStyles.bodyMuted),
                const SizedBox(height: 32),
                SecondaryButton(
                  label: 'Continuar com Google',
                  icon: Icons.g_mobiledata,
                  onPressed: authState.isLoading ? null : () => ref.read(authNotifierProvider.notifier).loginWithGoogle(),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Continuar com Apple',
                  icon: Icons.apple,
                  onPressed: authState.isLoading ? null : () => ref.read(authNotifierProvider.notifier).loginWithApple(),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('ou', style: AppTextStyles.bodyMuted)),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 24),
                CustomTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Senha',
                  controller: _senhaController,
                  obscureText: true,
                  validator: Validators.password,
                ),
                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(authState.errorMessage!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(label: 'Entrar com Email', isLoading: authState.isLoading, onPressed: _submit),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: widget.onGoToRegister,
                    child: const Text('Ainda não tem conta? Cadastre-se'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
