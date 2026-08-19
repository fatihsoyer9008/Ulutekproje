import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingPreferencesProvider = Provider<OnboardingPreferences>(
  (ref) => const OnboardingPreferences(),
);

class OnboardingPreferences {
  const OnboardingPreferences();

  static const _completedKey = 'onboarding_completed_v1';

  Future<bool> isCompleted() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_completedKey) ?? false;
    } on Exception {
      return false;
    }
  }

  Future<void> complete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
  }
}
