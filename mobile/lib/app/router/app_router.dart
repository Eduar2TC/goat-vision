import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/features/onboarding/presentation/onboarding_screen.dart';
import 'package:goatvision/features/dashboard/presentation/dashboard_screen.dart';
import 'package:goatvision/features/animals/presentation/animal_list_screen.dart';
import 'package:goatvision/features/animal_detail/presentation/animal_detail_screen.dart';
import 'package:goatvision/features/capture/presentation/capture_screen.dart';
import 'package:goatvision/features/analysis/presentation/analysis_screen.dart';
import 'package:goatvision/features/results/presentation/result_screen.dart';
import 'package:goatvision/features/history/presentation/history_screen.dart';
import 'package:goatvision/features/settings/presentation/settings_screen.dart';
import 'package:goatvision/features/animals/presentation/add_animal_screen.dart';
import 'package:goatvision/domain/entities/animal.dart';
import 'package:goatvision/core/storage/app_storage.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final hasSeenOnboarding = AppStorage.hasSeenOnboarding;
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!hasSeenOnboarding && !isOnboarding) {
        return '/onboarding';
      }
      if (hasSeenOnboarding && isOnboarding) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/dashboard',
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/animals',
        builder: (context, state) => const AnimalListScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const AddAnimalScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => AnimalDetailScreen(
              animalId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'edit',
            builder: (context, state) => AddAnimalScreen(
              animal: state.extra as Animal?,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/capture',
        builder: (context, state) {
          final animalId = state.uri.queryParameters['animalId'];
          return CaptureScreen(animalId: animalId);
        },
      ),
      GoRoute(
        path: '/analysis',
        builder: (context, state) => const AnalysisScreen(),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) => const ResultScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
