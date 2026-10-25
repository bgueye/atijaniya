import '../../../l10n/app_localizations.dart';

/// Codes d'erreur vocale posés par `TasbihController` et
/// `FreeWirdController` dans `voiceError`. Avant l'audit du 2026-10-04, les
/// contrôleurs y écrivaient directement une phrase en français (affichée
/// telle quelle en arabe), voire le code brut du moteur de reconnaissance
/// (`error_no_match`).
const voiceErrorMicUnavailable = 'mic_unavailable';
const voiceErrorRepeatedFailure = 'repeated_failure';

/// Codes du moteur natif qui signifient seulement « personne n'a parlé » :
/// une pause du disciple, pas une panne. Ni message ni décompte d'erreurs
/// (audit du 2026-10-25, P2-5).
bool isSilenceVoiceError(String code) => code == 'error_no_match' || code == 'error_speech_timeout';

/// Texte à afficher pour [code] — `null` quand il n'y a rien à afficher.
/// Tout code inconnu (erreur passagère du moteur) donne le message
/// générique, jamais le code lui-même.
String? voiceErrorMessage(AppLocalizations l10n, String? code) {
  if (code == null) return null;
  return switch (code) {
    voiceErrorMicUnavailable => l10n.wirdVoiceMicUnavailable,
    voiceErrorRepeatedFailure => l10n.wirdVoiceRepeatedFailure,
    _ => l10n.wirdVoiceTemporaryError,
  };
}
