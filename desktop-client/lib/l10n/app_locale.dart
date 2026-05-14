import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _load();
    return const Locale('de');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);
    if (saved == 'en' || saved == 'de') {
      state = Locale(saved!);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  Future<void> toggle() async {
    await setLocale(
      state.languageCode == 'de' ? const Locale('en') : const Locale('de'),
    );
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

const supportedLocales = <Locale>[Locale('de'), Locale('en')];
