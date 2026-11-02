// Les quatre états de la maquette du Profil (`docs/maquettes/ecran-profil.html`) :
// sans compte, disciple (sans zawiya ni lignée), parrainage confirmé, admin.
// Partagés par les tests de l'écran et par ses captures. Noms, zawiya, bio et
// chiffres sont des exemples, comme dans la maquette ; aucune donnée de lignée
// réelle (le nom du moqaddam n'est de toute façon jamais affiché).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:at_tijaniya/core/date/current_day.dart';
import 'package:at_tijaniya/features/lineage/domain/lineage_models.dart';
import 'package:at_tijaniya/features/lineage/presentation/lineage_providers.dart';
import 'package:at_tijaniya/features/moderation/data/blocks_repository.dart';
import 'package:at_tijaniya/features/moderation/domain/moderation_models.dart';
import 'package:at_tijaniya/features/moderation/presentation/block_user.dart';
import 'package:at_tijaniya/features/moderation/presentation/moderation_providers.dart';
import 'package:at_tijaniya/features/mouqaddam/domain/mouqaddam_models.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/mouqaddam_providers.dart';
import 'package:at_tijaniya/features/profil/domain/profile_models.dart';
import 'package:at_tijaniya/features/profil/presentation/profil_screen.dart';
import 'package:at_tijaniya/features/profil/presentation/profile_providers.dart';
import 'package:at_tijaniya/features/settings/domain/privacy_settings_models.dart';
import 'package:at_tijaniya/features/settings/presentation/privacy_settings_providers.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_overview_provider.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

import 'wird_overview_fixtures.dart';

enum ProfilState { guest, disciple, mouqaddam, admin }

/// Profil d'exemple de la maquette.
Profile _profile(ProfilState state) => Profile(
      userId: 'u1',
      displayName: 'Bocar Gueye',
      locale: 'fr',
      zawiyaId: state == ProfilState.disciple ? null : 'z1',
      zawiyaName: state == ProfilState.disciple ? null : 'Zawiya de Tivaouane',
      bio: state == ProfilState.disciple ? null : 'Disciple à Thiès. Wazifa du jeudi avec la dahira du quartier.',
      isAdmin: state == ProfilState.admin,
    );

ContentReport _report(int i) => ContentReport(
      id: 'r$i',
      reporterId: 'x',
      contentType: ReportableContentType.post,
      contentId: 'p$i',
      status: ReportStatus.pending,
      createdAt: DateTime(2026, 11, 1),
    );

List<Override> profilOverrides(ProfilState state) {
  final evening = sundayEvening();
  final signedIn = state != ProfilState.guest;
  final verified = state == ProfilState.mouqaddam;
  final filled = state != ProfilState.disciple;
  return [
    currentUserIdProvider.overrideWithValue(signedIn ? 'u1' : null),
    clockProvider.overrideWithValue(() => evening.now),
    wirdOverviewProvider.overrideWith((ref) async => evening.entries),
    myProfileProvider.overrideWith((ref) async => _profile(state)),
    myMouqaddamStatusProvider.overrideWith(
      (ref) async => MouqaddamStatus(
        status: verified ? MouqaddamVerificationStatus.verified : MouqaddamVerificationStatus.none,
        isFounder: false,
      ),
    ),
    myLineageProvider.overrideWith(
      (ref) async => filled ? const LineageDeclaration(foyer: Foyer.tivaouane, moqaddamNameText: 'exemple') : null,
    ),
    lineageMatchesProvider.overrideWith(
      (ref) async => const [
        LineageMatch(userId: 'a', displayName: 'A'),
        LineageMatch(userId: 'b', displayName: 'B'),
      ],
    ),
    myPrivacySettingsProvider.overrideWith(
      (ref) async => PrivacySettings(lineageVisible: filled, availableAsSponsor: verified),
    ),
    blockedUsersProvider.overrideWith((ref) async => const <BlockedUser>[]),
    receivedSponsorshipRequestsProvider.overrideWith(
      (ref) async => [
        SponsorshipRequest(
          id: 's1',
          candidateUserId: 'c',
          sponsorUserId: 'u1',
          status: SponsorshipRequestStatus.pending,
          requestedAt: DateTime(2026, 10, 30),
        ),
      ],
    ),
    pendingReportsProvider.overrideWith(
      (ref) async => [for (var i = 0; i < 3; i++) ReportWithPreview(report: _report(i))],
    ),
  ];
}

void setUpProfilMocks() {
  SharedPreferences.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: 'At-Tijaniya',
    packageName: 'sn.attijaniya',
    version: '1.0.0',
    buildNumber: '5',
    buildSignature: '',
  );
}

Widget profilApp(ProfilState state, {Locale locale = const Locale('fr'), ThemeData? theme}) {
  return ProviderScope(
    overrides: profilOverrides(state),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ProfilScreen(),
    ),
  );
}
