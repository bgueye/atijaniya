/// Enrobe `speech_to_text` pour le mode "reconnaissance vocale" du Tasbih
/// digital (docs/03-architecture-ecrans.md, P0) et du Wird libre.
///
/// Principe retenu (cohérent avec les compteurs de dhikr vocaux usuels) :
/// la reconnaissance fine du texte arabe récité par un moteur de
/// speech-to-text grand public n'est pas fiable, donc on ne cherche pas à
/// faire correspondre le texte reconnu à la formule attendue. Chaque énoncé
/// détecté (segment de parole séparé d'un silence) compte pour une
/// répétition : le disciple récite, marque une courte pause, le compteur
/// avance.
///
/// La segmentation par silence est faite **côté Dart**, pas via le paramètre
/// natif `pauseFor` de `speech_to_text` : constaté en conditions réelles,
/// `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS` (ce à quoi `pauseFor`
/// se traduit côté Android) est plafonné par l'OS/le moteur sur cet appareil
/// — le demander à 8s n'empêchait pas des coupures en pleine récitation
/// d'une longue formule (Salatoul Fatihi). [startListening] ouvre donc une
/// session d'écoute continue avec `partialResults: true`, et détecte
/// lui-même la fin d'un énoncé via un [Timer] réarmé à chaque nouveau texte
/// partiel reçu — fiable car non soumis aux plafonds internes du moteur
/// natif. Le moteur natif met par ailleurs fin à une session après
/// quelques secondes même en pleine parole continue (constaté en
/// conditions réelles) : ce [Timer] est donc conservé **à travers** les
/// redémarrages forcés (voir [_silenceTimer]) plutôt que réinitialisé à
/// chaque nouvelle session, pour ne pas perdre la progression d'un énoncé
/// encore en cours.
///
/// Le moteur natif (`SpeechToText`) est **partagé par toute l'app** — usage
/// recommandé par le plugin — plutôt qu'une instance par wird/écran : Android
/// ne permet qu'une session de reconnaissance active à la fois. Avoir un
/// `SpeechToText` séparé par contrôleur (un par wird + un pour le Wird libre)
/// faisait échouer tous les autres écrans avec `error_busy` dès que l'un
/// d'eux quittait sans que son moteur ait eu le temps de se libérer
/// pleinement (constaté en conditions réelles : le moteur de Lazim restait
/// actif et bloquait Wazifa et le Wird libre plusieurs dizaines de secondes
/// après avoir quitté l'écran). Chaque [TasbihVoiceService] revendique la
/// propriété du moteur partagé à l'appel de [initialize] ; les évènements
/// natifs arrivant après qu'une autre instance a pris la main sont ignorés
/// plutôt que d'être livrés à un contrôleur qui n'est plus le bon
/// destinataire.
library;

import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class TasbihVoiceService {
  TasbihVoiceService();

  static final SpeechToText _speech = SpeechToText();
  static bool _engineReady = false;
  static Object? _currentOwner;

  // Les callbacks natifs (`onStatus`/`onError`) ne sont enregistrés **qu'une
  // fois** auprès de `_speech.initialize()` (première ligne 51-58) : ils
  // forwardent en permanence vers ces références mutables, réassignées à
  // chaque appel de [initialize] par le nouveau propriétaire. Sans cette
  // indirection, un deuxième écran qui prend la main via [initialize] ne
  // reçoit jamais aucun évènement — les callbacks natifs restent liés pour
  // toujours au tout premier appelant (`_engineReady` étant déjà vrai, le
  // vrai `_speech.initialize()` ne se relance jamais), et son bouton "Voix"
  // reste bloqué en silence, sans passer par `onError`.
  static void Function(String status)? _activeOnStatus;
  static void Function(String error)? _activeOnError;

  /// Résolue une fois au premier [initialize], à partir des locales
  /// réellement installées sur l'appareil (voir [initialize]) : un code en
  /// dur `'ar'` ne correspond à aucune locale sur certains moteurs Android
  /// (qui n'acceptent que des codes précis type `ar-SA`), et le moteur tourne
  /// alors sans jamais reconnaître un seul mot — silencieusement, uniquement
  /// des `error_no_match` en boucle.
  static String _localeId = 'ar';

  final Object _owner = Object();

  bool get _isOwner => identical(_currentOwner, _owner);

  /// Initialise le moteur de reconnaissance vocale (demande la permission
  /// micro au premier appel de l'app) et fait de cette instance la
  /// propriétaire courante du moteur partagé. Retourne `false` si le moteur
  /// ou la permission ne sont pas disponibles sur l'appareil.
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    _currentOwner = _owner;
    _activeOnStatus = onStatus;
    _activeOnError = onError;
    if (_engineReady) return true;
    _engineReady = await _speech.initialize(
      onStatus: (status) => _activeOnStatus?.call(status),
      onError: (error) => _activeOnError?.call(error.errorMsg),
    );
    if (_engineReady) {
      final locales = await _speech.locales();
      final arabicLocale = locales.where((l) => l.localeId.toLowerCase().startsWith('ar'));
      if (arabicLocale.isNotEmpty) {
        _localeId = arabicLocale.first.localeId;
      }
    }
    return _engineReady;
  }

  bool get isListening => _speech.isListening;

  /// Décompte le silence depuis le dernier mot reconnu, **à travers** les
  /// redémarrages forcés d'une session native (voir plus haut) : ne doit
  /// surtout pas être annulé/oublié dans [startListening] lui-même — sinon
  /// chaque coupure forcée en pleine récitation effacerait la progression
  /// d'un énoncé pourtant toujours en cours, et le disciple ne serait plus
  /// jamais compté au bout de quelques secondes de récitation continue
  /// (constaté en conditions réelles).
  Timer? _silenceTimer;

  /// Démarre (ou reprend après une coupure forcée) une session d'écoute
  /// continue. [onUtteranceDetected] est appelé une fois par énoncé
  /// détecté : dès qu'aucun nouveau mot n'est arrivé depuis
  /// [utteranceSilence], que ce silence ait eu lieu au sein d'une même
  /// session native ou à cheval sur un redémarrage forcé. L'appelant
  /// (contrôleur) est notifié d'une fin de session (forcée ou réelle) via
  /// le `onStatus` fourni à [initialize] et décide alors de relancer
  /// [startListening] — voir le commentaire d'en-tête du fichier : le
  /// moteur natif met fin à une session après quelques secondes même en
  /// pleine parole continue, indépendamment de tout silence réel. No-op si
  /// cette instance n'est plus propriétaire du moteur partagé (écran
  /// quitté entre-temps).
  Future<void> startListening({
    required void Function() onUtteranceDetected,
    required Duration utteranceSilence,
  }) {
    if (!_isOwner) return Future.value();
    return _speech.listen(
      onResult: (result) {
        if (!_isOwner) return;
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        _silenceTimer?.cancel();
        _silenceTimer = Timer(utteranceSilence, () {
          if (!_isOwner) return;
          onUtteranceDetected();
        });
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        // La segmentation réelle se fait côté Dart via [utteranceSilence]
        // (voir le commentaire d'en-tête) : ce timeout ne sert qu'à borner
        // une session qui n'a reçu aucune coupure native.
        listenFor: const Duration(minutes: 10),
        localeId: _localeId,
      ),
    );
  }

  /// No-op si cette instance n'est plus propriétaire — évite d'interrompre
  /// la session d'un autre écran qui a entre-temps pris la main.
  Future<void> stop() {
    _silenceTimer?.cancel();
    return _isOwner ? _speech.stop() : Future.value();
  }

  Future<void> cancel() {
    _silenceTimer?.cancel();
    return _isOwner ? _speech.cancel() : Future.value();
  }
}
