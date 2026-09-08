import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/core/storage/app_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _steps = const [
    _OnboardingStep(
      icon: Icons.camera_alt,
      title: 'Colócala de perfil',
      description:
          'La cabra debe verse de costado, con el cuerpo completo visible.',
    ),
    _OnboardingStep(
      icon: Icons.crop_square,
      title: 'Coloca el marcador',
      description:
          'Deja el marcador de calibración de 30 cm junto a la cabra.',
    ),
    _OnboardingStep(
      icon: Icons.monitor_weight,
      title: 'Escanea y estima',
      description:
          'Captura la foto y obtén al instante el peso estimado con su rango '
          'de incertidumbre. Sin balanzas ni cintas, todo lo mide la visión '
          'artificial.',
    ),
    _OnboardingStep(
      icon: Icons.history,
      title: 'Guarda y da seguimiento',
      description:
          'Registra la medición en tu historial. Si escaneas sin elegir cabra '
          'la registramos por ti; puedes nombrarla después.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            step.icon,
                            size: 56,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          step.title,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _currentPage
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      child: const Text('Anterior'),
                    )
                  else
                    const SizedBox(width: 100),
                  const Spacer(),
                  FilledButton(
                    onPressed: _currentPage < _steps.length - 1
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        : () async {
                            await AppStorage.setOnboardingSeen();
                            if (context.mounted) {
                              context.go('/dashboard');
                            }
                          },
                    child: Text(
                      _currentPage < _steps.length - 1
                          ? 'Siguiente'
                          : 'Comenzar',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}