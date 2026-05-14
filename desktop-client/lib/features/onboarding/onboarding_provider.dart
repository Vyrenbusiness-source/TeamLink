import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingDoneProvider = StateProvider<bool>((ref) => false);

Future<void> markOnboardingDone(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_done', true);
  ref.read(onboardingDoneProvider.notifier).state = true;
}
