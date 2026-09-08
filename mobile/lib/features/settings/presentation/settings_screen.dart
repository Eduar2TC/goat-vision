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
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informe científico',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Modelo de referencia de peso — Paredes-Chocce et al. (2025)',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'BW (kg) = -45.642 + 0.71·TG + 0.21·RH + 0.99·RW\n\n'
                  'R² ajustado = 0.644 · RSE = 6.305 kg · n = 356',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cómo se obtienen las medidas\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Las medidas biométricas (longitud corporal, altura a la '
                'cruz, altura de grupa, profundidad de pecho, anchos de '
                'pecho y grupa, etc.) se derivan de la imagen por visión '
                'artificial; un marcador de 30 cm convierte píxeles a '
                'centímetros. El perímetro torácico (TG) no es medible en '
                'una vista lateral, por lo que se estima como el perímetro '
                'de la elipse del pecho (aproximación de Ramanujan) a partir '
                'de la profundidad y el ancho del pecho.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Para qué animales aplica\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Cabras criollas peruanas. Rango observado en el estudio: '
                'peso 23.2–75 kg, perímetro torácico 65–103 cm. La app '
                'valida las medidas contra estos rangos y avisa si salen '
                'de ellos.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Referencia completa\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                'Paredes-Chocce, J. F. et al. (2025). Predicting body weight '
                'using body measurements in Peruvian creole goats. '
                'Biodiversitas 26(7): 3193-3198.\n'
                'DOI: 10.13057/biodiv/d260710',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Advertencias',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '· La estimación NO es un valor de báscula.\n'
                '· La confianza (64%) y el intervalo provienen del R² y el '
                'RSE publicados; NO son una cobertura (PICP) medida por '
                'GoatVision con sus propios datos.\n'
                '· Para tu rebaño puede ser más precisa: entrena un modelo '
                'con tus propios datos (medidas + peso real en báscula) y '
                'sustituirá a esta referencia.\n'
                '· El error crece con iluminación pobre y condiciones '
                'extremas del animal.',
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