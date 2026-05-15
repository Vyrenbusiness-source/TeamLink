import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingDoneProvider = StateProvider<bool>((ref) => false);

Future<void> markOnboardingDone(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_done', true);
  ref.read(onboardingDoneProvider.notifier).state = true;
}

/// Setzt das Onboarding zurueck, damit ein bestehender Nutzer im
/// Login-Screen mit "Einladungscode beitreten" wieder in den
/// Joiner-Flow zurueck springen kann.
Future<void> resetOnboarding(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_done', false);
  ref.read(onboardingDoneProvider.notifier).state = false;
}
