/// Detects response language from user text (question), with app locale fallback.
class UserLanguageUtils {
  UserLanguageUtils._();

  static final _cyrillic = RegExp(r'[\u0400-\u04FF\u0500-\u052F]');
  static final _latin = RegExp(r'[a-zA-Z]');

  /// Prefer the language of the user's message; fall back to app UI locale.
  static String resolveResponseLanguageCode({
    required String question,
    required String appLanguageCode,
  }) {
    final text = question.trim();
    if (text.isEmpty) return appLanguageCode;

    final hasCyrillic = _cyrillic.hasMatch(text);
    final hasLatin = _latin.hasMatch(text);

    if (hasCyrillic && !hasLatin) return 'ru';
    if (hasCyrillic && hasLatin) return 'ru';
    if (hasLatin) return 'en';

    return appLanguageCode;
  }

  static String languageDisplayName(String code) => switch (code) {
        'ru' => 'Russian (русский)',
        'en' => 'English',
        _ => code,
      };
}
