import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/core/utils/app_logger.dart';
import 'package:goatvision/data/providers/providers.dart';
import 'package:goatvision/core/ml/weight_prediction_service.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  final List<String> _steps = const [
    'Detectando animal...',
    'Analizando silueta...',
    'Calculando medidas...',
    'Estimando peso...',
  ];

  int _currentIndex = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    final session = ref.read(analysisSessionProvider);
    if (session == null) {
      _fail();
      return;
    }

    final weightService = ref.read(weightPredictionServiceProvider);
    final features = _featuresFromSession(session);

    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _currentIndex = i);
    }

    try {
      final result = await weightService.run(features);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      setState(() => _currentIndex = 3);

      if (!result.valid) {
        _fail();
        return;
      }

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      AppLogger.instance
          .info('Analysis completed: ${result.prediction.estimatedWeightKg} kg');
      context.go('/result');
    } catch (e) {
      AppLogger.instance.error('Analysis failed', error: e);
      _fail();
    }
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _failed = true);
  }

  MorphometricFeatures _featuresFromSession(AnalysisSessionState session) {
    return MorphometricFeatures(
      bodyLengthCm: session.morphometrics['body_length'] ?? 0,
      withersHeightCm: session.morphometrics['withers_height'] ?? 0,
      rumpHeightCm: session.morphometrics['rump_height'] ?? 0,
      chestDepthCm: session.morphometrics['chest_depth'] ?? 0,
      chestWidthCm: session.morphometrics['chest_width'] ?? 0,
      rumpWidthCm: session.morphometrics['rump_width'] ?? 0,
      rumpLengthCm: session.morphometrics['rump_length'] ?? 0,
      pawHeightCm: session.morphometrics['paw_height'] ?? 0,
      bodyAreaCm2: session.morphometrics['body_area_cm2'] ?? 0,
      bodyAspectRatio: session.morphometrics['body_aspect_ratio'] ?? 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Text(
                'Analizando cabra...',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              if (_failed)
                _buildFailure()
              else
                for (int i = 0; i < _steps.length; i++)
                  _StepRow(
                    label: _steps[i],
                    state: i < _currentIndex
                        ? _StepState.complete
                        : i == _currentIndex
                            ? _StepState.running
                            : _StepState.pending,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFailure() {
    return Column(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 56),
        const SizedBox(height: 16),
        const Text(
          'No se puede realizar una estimación confiable con esta captura.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.go('/capture'),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Repetir captura'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}

enum _StepState { pending, running, complete }

class _StepRow extends StatelessWidget {
  final String label;
  final _StepState state;

  const _StepRow({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: switch (state) {
                _StepState.complete => AppColors.success,
                _StepState.running => AppColors.primary,
                _StepState.pending => Theme.of(context).colorScheme.outline,
              },
              border: state == _StepState.running
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: state == _StepState.running
                ? const Padding(
                    padding: EdgeInsets.all(5),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    state == _StepState.complete
                        ? Icons.check
                        : Icons.circle,
                    size: 14,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
          ),
          const SizedBox(width: 16),
          Text(label),
        ],
      ),
    );
  }
}