// Vérifie le parsing des modèles du workflow Mouqaddam depuis une ligne
// Supabase : statut, demande de parrainage, parrain disponible, maillon de
// silsila d'ijaza (automatique et manuel).

import 'package:flutter_test/flutter_test.dart';

import 'package:at_tijaniya/features/mouqaddam/domain/mouqaddam_models.dart';

void main() {
  group('MouqaddamStatus.fromRow', () {
    test('parse un statut vérifié fondateur', () {
      final status = MouqaddamStatus.fromRow({
        'status': 'verified',
        'is_founder': true,
        'verified_at': '2026-08-05T11:25:36.068507+00:00',
      });
      expect(status.status, MouqaddamVerificationStatus.verified);
      expect(status.isVerified, isTrue);
      expect(status.isFounder, isTrue);
    });

    test('statut inconnu retombe sur none', () {
      final status = MouqaddamStatus.fromRow({'status': 'inconnu', 'is_founder': false, 'verified_at': null});
      expect(status.status, MouqaddamVerificationStatus.none);
      expect(status.isVerified, isFalse);
    });
  });

  group('SponsorshipRequest.fromRow', () {
    test('parse une demande en attente', () {
      final request = SponsorshipRequest.fromRow({
        'id': 'r1',
        'candidate_user_id': 'c1',
        'sponsor_user_id': 's1',
        'ijaza_year': 2024,
        'status': 'pending',
        'requested_at': '2026-08-08T10:00:00.000000+00:00',
      });
      expect(request.status, SponsorshipRequestStatus.pending);
      expect(request.ijazaYear, 2024);
      expect(request.candidateName, isNull);
    });

    test('withNames complète les noms résolus séparément', () {
      final request = SponsorshipRequest.fromRow({
        'id': 'r1',
        'candidate_user_id': 'c1',
        'sponsor_user_id': 's1',
        'ijaza_year': null,
        'status': 'accepted',
        'requested_at': '2026-08-08T10:00:00.000000+00:00',
      }).withNames(candidateName: 'Fatou', sponsorName: 'Cheikh');
      expect(request.candidateName, 'Fatou');
      expect(request.sponsorName, 'Cheikh');
    });
  });

  group('AvailableSponsor.fromRow', () {
    test('parse un parrain disponible avec zawiya', () {
      final sponsor = AvailableSponsor.fromRow({'user_id': 'u1', 'display_name': 'Modou', 'zawiya_name': 'Zawiya de Tivaouane'});
      expect(sponsor.displayName, 'Modou');
      expect(sponsor.zawiyaName, 'Zawiya de Tivaouane');
    });

    test('zawiya absente reste nulle', () {
      final sponsor = AvailableSponsor.fromRow({'user_id': 'u1', 'display_name': 'Modou', 'zawiya_name': null});
      expect(sponsor.zawiyaName, isNull);
    });
  });

  group('IjazaChainLink', () {
    test('maillon automatique affiche le nom résolu', () {
      final link = IjazaChainLink.fromRow({
        'depth': 1,
        'user_id': 'u1',
        'ijaza_year': 2020,
        'is_manual': false,
        'name_text': null,
        'year_text': null,
      }).withResolvedName('Cheikh Ahmed');
      expect(link.isManual, isFalse);
      expect(link.displayName('—'), 'Cheikh Ahmed');
    });

    test('maillon manuel affiche name_text et year_text sans résolution', () {
      final link = IjazaChainLink.fromRow({
        'depth': 3,
        'user_id': null,
        'ijaza_year': null,
        'is_manual': true,
        'name_text': 'Ancêtre inconnu',
        'year_text': 'vers 1950',
      });
      expect(link.isManual, isTrue);
      expect(link.displayName('—'), 'Ancêtre inconnu');
      expect(link.yearText, 'vers 1950');
    });

    test('maillon automatique sans résolution retombe sur le fallback', () {
      final link = IjazaChainLink.fromRow({
        'depth': 0,
        'user_id': 'u1',
        'ijaza_year': null,
        'is_manual': false,
        'name_text': null,
        'year_text': null,
      });
      expect(link.displayName('—'), '—');
    });
  });
}
