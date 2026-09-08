import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goatvision/core/constants/app_constants.dart';
import 'package:goatvision/core/constants/app_colors.dart';
import 'package:goatvision/core/storage/app_storage.dart';
import 'package:goatvision/core/theme/theme_mode_provider.dart';
import 'package:goatvision/data/providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late String _unit = AppStorage.preferredUnit;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(runModeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('Unidad'),
              subtitle: Text(
                _unit == 'kg' ? '$_unit (kilogramos)' : '$_unit (libras)',
              ),
              trailing: DropdownButton<String>(
                value: _unit,
                items: const [
                  DropdownMenuItem(value: 'kg', child: Text('kg')),
                  DropdownMenuItem(value: 'lb', child: Text('lb')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _unit = value);
                    AppStorage.setPreferredUnit(value);
                  }
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Tema'),
              subtitle: Text(_themeLabel(themeMode)),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Claro'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Oscuro'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('Sistema'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                    AppStorage.setThemeMode(themeModeToPref(value));
                  }
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science),
              title: const Text('Modo de desarrollo'),
              subtitle: Text(mode == RunMode.mock
                  ? 'Modo mock (modelos simulados)'
                  : 'Modo real (modelos TFLite)'),
              trailing: Switch(
                value: mode == RunMode.mock,
                onChanged: (value) {
                  ref.read(runModeProvider.notifier).state =
                      value ? RunMode.mock : RunMode.real;
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.smartphone),
              title: const Text('Modelos'),
              subtitle: const Text('Estado de los modelos ML'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showModelsModal(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Información científica'),
              subtitle: const Text(
                'Metodología basada en agrupación de caracterización morfométrica',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showScienceInfo(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacidad'),
              subtitle: const Text(
                'Todos los datos permanecen en tu dispositivo',
              ),
            ),
            const Divider(),
            const AboutListTile(
              icon: Icon(Icons.pets, color: AppColors.primary),
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
              applicationLegalese:
                  'Estimación de peso caprino mediante visión artificial.\n'
                  'Los resultados son estimaciones, no mediciones de báscula.',
              child: Text('Acerca de GoatVision'),
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Sigue al sistema';
      default:
        return 'Claro';
    }
  }

  void _showModelsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modelos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'La detección/segmentación/landmarks son mocks de desarrollo. '
              'El peso usa una fórmula de referencia publicada hasta que '
              'integres un modelo TFLite propio.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            const _ModelTile(
              name: 'goat_detector.tflite',
              version: 'mock-v1.0',
              status: 'Mock',
            ),
            const _ModelTile(
              name: 'goat_segmenter.tflite',
              version: 'mock-v1.0',
              status: 'Mock',
            ),
            const _ModelTile(
              name: 'goat_landmarks.tflite',
              version: 'mock-v1.0',
              status: 'Mock',
            ),
            const _ModelTile(
              name: 'weight_reference',
              version: 'ref-paredes-chocce-2025',
              subtitle:
                  'R²=0.644 · RSE=6.305 kg · n=356 '
                  '(Biodiversitas 26(7), DOI 10.13057/biodiv/d260710)',
              status: 'Fórmula (literatura)',
            ),
          ],
        ),
      ),
    );
  }

  void _showScienceInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Información científica',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'El peso de la cabra se estima a partir de medidas biométricas '
                'obtenidas mediante visión artificial:\n\n'
                '· Longitud corporal\n'
                '· Altura a la cruz\n'
                '· Altura de grupa\n'
                '· Profundidad de pecho\n'
                '· Anchos de pecho y grupa\n\n'
                'Las medidas se convierten a centímetros usando un marcador '
                'de calibración. El peso se calcula con una ecuación de '
                'regresión publicada (Paredes-Chocce et al. 2025, cabras '
                'criollas peruanas). Con tus propios datos puedes entrenar un '
                'modelo personalizado que sustituya esta referencia.\n\n'
                'El resultado incluye un rango de incertidumbre. '
                'Este NO es un valor de báscula exacto.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final String name;
  final String version;
  final String status;
  final String? subtitle;

  const _ModelTile({
    required this.name,
    required this.version,
    required this.status,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle ?? 'Versión: $version'),
      trailing: Chip(
        label: Text(
          status,
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: AppColors.info.withValues(alpha: 0.1),
        labelStyle: const TextStyle(color: AppColors.info),
      ),
    );
  }
}