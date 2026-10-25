// Comptage à la voix du Tasbih et du Wird libre : trois cas où le disciple
// restait bloqué (audit du 2026-10-25, P2-5). Le moteur de reconnaissance
// est remplacé par une doublure dont le test déclenche lui-même les statuts
// et les erreurs natives.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/wird/data/tasbih_voice_service.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/presentation/free_wird_controller.dart';
import 'package:at_tijaniya/features/wird/presentation/tasbih_controller.dart';
import 'package:at_tijaniya/features/wird/presentation/voice_error_message.dart';

class _FakeVoice implements TasbihVoiceService {
  bool ready = true;
  int listenCalls = 0;
  void Function(String status)? onStatus;
  void Function(String error)? onError;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    this.onStatus = onStatus;
    this.onError = onError;
    return ready;
  }

  @override
  Future<void> startListening({required void Function() onUtteranceDetected, required Duration utteranceSilence}) async =>
      listenCalls++;

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  bool get isListening => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Les deux contrôleurs exposent les mêmes gestes vocaux ; on les teste à
/// travers cette petite façade commune.
class _Subject {
  _Subject(this.name, this.start, this.voiceError, this.voiceSupported, this.dispose);

  final String name;
  final Future<void> Function() start;
  final String? Function() voiceError;

  /// `false` cache le bouton « Démarrer l'écoute » (`TasbihCounterPanel`).
  final bool Function() voiceSupported;
  final void Function() dispose;
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeVoice voice;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    voice = _FakeVoice();
  });

  final subjects = <String, _Subject Function()>{
    'Tasbih': () {
      final c = TasbihController(wird: validatedWirds.first, voice: voice);
      return _Subject('Tasbih', c.startListening, () => c.state.voiceError, () => c.state.voiceSupported, c.dispose);
    },
    'Wird libre': () {
      final c = FreeWirdController(voice: voice);
      return _Subject('Wird libre', c.startListening, () => c.state.voiceError, () => c.state.voiceSupported, c.dispose);
    },
  };

  subjects.forEach((name, create) {
    group(name, () {
      test('micro refusé : message, puis nouvel essai possible', () async {
        final subject = create();
        addTearDown(subject.dispose);
        await _settle();

        voice.ready = false;
        await subject.start();
        expect(subject.voiceError(), voiceErrorMicUnavailable);
        expect(subject.voiceSupported(), isTrue, reason: 'le bouton doit rester visible');

        // Permission accordée ensuite dans les réglages : le même bouton marche.
        voice.ready = true;
        await subject.start();
        expect(subject.voiceError(), isNull);
        expect(voice.listenCalls, 1);
      });

      test('des pauses sans parole ne coupent pas l’écoute', () async {
        final subject = create();
        addTearDown(subject.dispose);
        await _settle();
        await subject.start();

        for (var i = 0; i < 5; i++) {
          voice.onError!('error_no_match');
          voice.onError!('error_speech_timeout');
        }
        expect(subject.voiceError(), isNull);

        // Une vraie panne répétée, elle, arrête l'écoute avec son message.
        for (var i = 0; i < 3; i++) {
          voice.onError!('error_busy');
        }
        expect(subject.voiceError(), voiceErrorRepeatedFailure);
      });

      test('une erreur passagère disparaît dès que l’écoute reprend', () async {
        final subject = create();
        addTearDown(subject.dispose);
        await _settle();
        await subject.start();

        voice.onError!('error_network');
        expect(subject.voiceError(), 'error_network');

        voice.onStatus!('listening');
        expect(subject.voiceError(), isNull);
      });
    });
  });
}
