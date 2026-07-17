/// Minimal two-language support (English / Portuguese).
///
/// Deliberately lightweight rather than `flutter_localizations` + gen-l10n:
/// the app is EN/PT only and has no plurals/date formatting to localize, so a
/// codegen pipeline would cost more than it returns. If a third language or
/// App Store listing localization ever lands, swap this for gen-l10n — call
/// sites already funnel through one function.
///
/// Usage: `tr('Nearby', 'Perto')`
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLang { en, pt }

/// Current language. Read by [tr]; set via [setLang].
AppLang appLang = AppLang.en;

const _prefsKey = 'app_lang';

/// English or Portuguese, whichever [appLang] is set to.
String tr(String en, String pt) => appLang == AppLang.pt ? pt : en;

/// Load the saved choice, else follow the device locale (pt-* -> Portuguese).
Future<void> loadLang() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_prefsKey);
  if (saved != null) {
    appLang = saved == 'pt' ? AppLang.pt : AppLang.en;
    return;
  }
  final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  appLang = device == 'pt' ? AppLang.pt : AppLang.en;
}

Future<void> setLang(AppLang lang) async {
  appLang = lang;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, lang == AppLang.pt ? 'pt' : 'en');
}
