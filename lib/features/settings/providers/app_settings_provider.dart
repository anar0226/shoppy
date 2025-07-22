import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider with ChangeNotifier {
  static const String _languageKey = 'language';
  static const String _themeKey = 'theme';

  // Current settings
  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.light;

  // Getters
  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  String get languageCode => _locale.languageCode;

  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('mn'), // Mongolian
  ];

  AppSettingsProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load language
      final savedLanguage = prefs.getString(_languageKey);
      if (savedLanguage != null) {
        _locale = Locale(savedLanguage);
      }

      // Load theme
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedTheme,
          orElse: () => ThemeMode.light,
        );
      }

      notifyListeners();
    } catch (e) {
      // Error loading settings
    }
  }

  // Change language
  Future<void> setLanguage(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);
    } catch (e) {
      // Error saving language
    }
  }

  // Toggle between English and Mongolian
  Future<void> toggleLanguage() async {
    final newLocale =
        _locale.languageCode == 'en' ? const Locale('mn') : const Locale('en');
    await setLanguage(newLocale);
  }

  // Change theme
  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) return;

    _themeMode = themeMode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, themeMode.toString());
    } catch (e) {
      // Error saving theme
    }
  }

  // Toggle theme
  Future<void> toggleTheme() async {
    final newTheme =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newTheme);
  }

  // Get language name for display
  String getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'mn':
        return 'Mongolian';
      default:
        return code.toUpperCase();
    }
  }

  // Get theme name for display
  String getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System';
    }
  }
}
