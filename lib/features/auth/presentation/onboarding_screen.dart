import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/components/primary_button.dart';

class _OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  const _OnboardingPageData(this.title, this.description, this.icon);
}

const _pages = [
  _OnboardingPageData(
    'Tenha direção para seu tempo',
    'Organize compromissos, tarefas e objetivos em um único lugar.',
    Icons.explore_outlined,
  ),
  _OnboardingPageData(
    'Conecte seus calendários',
    'Sincronize suas agendas e tenha tudo em um só lugar.',
    Icons.calendar_month_outlined,
  ),
  _OnboardingPageData(
    'Planeje com inteligência',
    'A IA ajuda você a tomar melhores decisões.',
    Icons.auto_awesome_outlined,
  ),
];

/// Onboarding de 3 páginas mostrado apenas no primeiro acesso.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 96, color: AppColors.primary),
                        const SizedBox(height: 32),
                        Text(page.title, style: AppTextStyles.heading1, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(page.description, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.primary : AppColors.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                label: isLast ? 'Começar' : 'Próximo',
                onPressed: () {
                  if (isLast) {
                    widget.onFinish();
                  } else {
                    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
