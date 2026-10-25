// Lecteur audio du guide d'un wird : comportements relevés par l'audit du
// 2026-10-25, vérifiés sans réseau ni lecteur réel. Le dépôt Supabase, le
// cache disque et `just_audio` sont remplacés par des doublures en mémoire ;
// chaque téléchargement reste en attente jusqu'à ce que le test le termine,
// pour rejouer exactement l'ordre des évènements.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show PlayerState;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/features/wird/data/wird_audio_player_service.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_asset_manifest.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_download_store.dart';
import 'package:at_tijaniya/features/wird/data/wird_recitation_repository.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_recitation.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_audio_controller.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_messages.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_pillar_audio_controller.dart';

/// Dépôt Supabase simulé : récitations fixées par le test, téléchargements
/// terminés à la main (`downloads[chemin].complete(...)`).
class _FakeRepository implements WirdRecitationRepository {
  Map<int, WirdRecitation> recitations = {};
  Object? metadataError;
  final downloads = <String, Completer<List<int>>>{};

  @override
  Future<Map<int, WirdRecitation>> fetchRecitationsForWird(String wirdKey) async {
    if (metadataError != null) throw metadataError!;
    return recitations;
  }

  @override
  Future<List<int>> downloadAudioBytes(String audioPath) => (downloads[audioPath] ??= Completer()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Cache disque simulé : un ensemble de chemins « présents sur l'appareil ».
class _FakeDownloadStore implements WirdRecitationDownloadStore {
  final files = <String>{};

  @override
  Future<File> localFileFor(String audioPath) async => File('cache/$audioPath');

  @override
  Future<bool> isDownloaded(String audioPath) async => files.contains(audioPath);

  @override
  Future<File> save(String audioPath, List<int> bytes) async {
    files.add(audioPath);
    return File('cache/$audioPath');
  }

  @override
  Future<File> copyFromAsset(String audioPath, String assetPath) => save(audioPath, const []);

  @override
  Future<void> delete(String audioPath) async => files.remove(audioPath);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyManifest implements WirdRecitationAssetManifest {
  @override
  Future<Map<String, WirdRecitationAsset>> load() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Lecteur simulé : retient les fichiers chargés, dans l'ordre.
class _FakePlayer implements WirdAudioPlayerService {
  final loaded = <String>[];
  bool disposed = false;
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _playerState = StreamController<PlayerState>.broadcast();

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<PlayerState> get playerStateStream => _playerState.stream;

  @override
  Future<void> load(String localPath) async => loaded.add(localPath);
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => disposed = true;
}

/// Laisse passer les micro-tâches en attente (chargement des métadonnées,
/// fin d'un téléchargement...).
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

WirdRecitation _recitation(String path) => WirdRecitation(id: path, audioPath: path, contentVersion: 1);

void main() {
  final wird = validatedWirds.firstWhere((w) => w.id == 'wazifa');
  late _FakeRepository repository;
  late _FakeDownloadStore store;
  late _FakePlayer player;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeRepository();
    store = _FakeDownloadStore();
    player = _FakePlayer();
    container = ProviderContainer(overrides: [
      wirdPillarAudioProvider.overrideWith(
        (ref, wird) => WirdPillarAudioController(
          wird: wird,
          repository: repository,
          downloadStore: store,
          assetManifest: _EmptyManifest(),
        ),
      ),
      wirdAudioControllerProvider.overrideWith(
        (ref, wird) => WirdAudioController(ref: ref, wird: wird, service: player),
      ),
    ]);
    addTearDown(container.dispose);
  });

  /// Écoutes ouvertes par [openGuide], comme le fait l'écran du guide ;
  /// les fermer revient à quitter le guide.
  late List<ProviderSubscription<Object?>> guideSubscriptions;

  /// Ouvre le « guide » : les deux contrôleurs restent écoutés, comme par
  /// l'écran, et les métadonnées sont chargées.
  Future<WirdAudioController> openGuide() async {
    guideSubscriptions = [
      container.listen(wirdPillarAudioProvider(wird), (_, __) {}),
      container.listen(wirdAudioControllerProvider(wird), (_, __) {}),
    ];
    await _settle();
    return container.read(wirdAudioControllerProvider(wird).notifier);
  }

  PillarAudioAvailability? availabilityOf(int index) =>
      container.read(wirdPillarAudioProvider(wird))[index]?.availability;

  test('retoucher un pilier en erreur relance le téléchargement puis la lecture', () async {
    repository.recitations = {0: _recitation('a.m4a')};
    final audio = await openGuide();

    unawaited(audio.playPillar(0));
    await _settle();
    repository.downloads['a.m4a']!.completeError(const SocketException('hors ligne'));
    await _settle();
    expect(availabilityOf(0), PillarAudioAvailability.error);
    expect(player.loaded, isEmpty);

    // Réseau revenu : nouveau toucher sur le même pilier.
    repository.downloads.remove('a.m4a');
    unawaited(audio.playPillar(0));
    await _settle();
    repository.downloads['a.m4a']!.complete(const [1, 2, 3]);
    await _settle();

    expect(player.loaded, [File('cache/a.m4a').path]);
    expect(availabilityOf(0), PillarAudioAvailability.downloaded);
  });

  test('changer de pilier pendant un téléchargement ne fait pas jouer l’ancien', () async {
    repository.recitations = {0: _recitation('a.m4a'), 1: _recitation('b.m4a')};
    store.files.add('b.m4a'); // B déjà sur l'appareil, A à télécharger.
    final audio = await openGuide();

    unawaited(audio.playPillar(0)); // téléchargement de A en attente
    await _settle();
    await audio.playPillar(1); // B se lance aussitôt
    await _settle();
    expect(player.loaded, [File('cache/b.m4a').path]);

    repository.downloads['a.m4a']!.complete(const [1, 2, 3]); // A arrive après coup
    await _settle();

    expect(player.loaded, [File('cache/b.m4a').path], reason: 'A ne doit pas remplacer B');
    expect(container.read(wirdAudioControllerProvider(wird)).activePillarIndex, 1);
  });

  test('liste des récitations manquée hors ligne : état distinct, puis nouvel essai au toucher', () async {
    repository.metadataError = const SocketException('hors ligne');
    final audio = await openGuide();

    // Ni « bientôt disponible » (aucune récitation) ni pilier jouable.
    expect(availabilityOf(0), PillarAudioAvailability.loadFailed);

    // Toujours hors ligne : le toucher redemande la liste et le dit.
    await audio.togglePlayPause();
    await _settle();
    expect(container.read(wirdAudioControllerProvider(wird)).errorMessage, wirdMsgAudioLoadFailed);

    // Connexion revenue : le même toucher recharge la liste et lit le pilier.
    repository.metadataError = null;
    repository.recitations = {0: _recitation('a.m4a')};
    store.files.add('a.m4a');
    await audio.playPillar(0);
    await _settle();
    expect(availabilityOf(0), PillarAudioAvailability.downloaded);
    expect(player.loaded, [File('cache/a.m4a').path]);
  });

  test('quitter le guide arrête la lecture et libère le lecteur', () async {
    repository.recitations = {0: _recitation('a.m4a')};
    store.files.add('a.m4a');
    final audio = await openGuide();
    await audio.playPillar(0);
    await _settle();
    expect(player.loaded, isNotEmpty);

    for (final subscription in guideSubscriptions) {
      subscription.close();
    }
    await _settle();

    expect(player.disposed, isTrue);
  });
}
