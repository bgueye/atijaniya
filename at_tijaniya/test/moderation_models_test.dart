import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:at_tijaniya/features/moderation/domain/moderation_errors.dart';
import 'package:at_tijaniya/features/moderation/domain/moderation_models.dart';

void main() {
  group('ContentReport.fromRow', () {
    test('parse une ligne complète', () {
      final row = {
        'id': 'report-1',
        'reporter_id': 'user-1',
        'content_type': 'live_stream',
        'content_id': 'stream-1',
        'reason': 'Contenu inapproprié',
        'status': 'pending',
        'created_at': '2026-08-18T10:00:00Z',
      };
      final report = ContentReport.fromRow(row);
      expect(report.id, 'report-1');
      expect(report.contentType, ReportableContentType.liveStream);
      expect(report.status, ReportStatus.pending);
      expect(report.reason, 'Contenu inapproprié');
    });

    test('reason absente reste null', () {
      final row = {
        'id': 'report-2',
        'reporter_id': 'user-2',
        'content_type': 'lineage_connection_request',
        'content_id': 'request-1',
        'reason': null,
        'status': 'resolved',
        'created_at': '2026-08-18T10:00:00Z',
      };
      final report = ContentReport.fromRow(row);
      expect(report.contentType, ReportableContentType.lineageConnectionRequest);
      expect(report.status, ReportStatus.resolved);
      expect(report.reason, isNull);
    });
  });

  group('reportableContentType conversions', () {
    test('aller-retour DB <-> enum', () {
      for (final type in ReportableContentType.values) {
        final dbValue = reportableContentTypeToDbValue(type);
        expect(reportableContentTypeFromDbValue(dbValue), type);
      }
    });

    test('valeur inconnue lève une erreur', () {
      expect(() => reportableContentTypeFromDbValue('autre_chose'), throwsArgumentError);
    });

    test('messages de groupe et messages privés portent les valeurs attendues par la base', () {
      expect(reportableContentTypeToDbValue(ReportableContentType.groupPost), 'group_post');
      expect(reportableContentTypeToDbValue(ReportableContentType.message), 'message');
    });
  });

  group('signalement d\'un message', () {
    test('lit la copie du message et son auteur, fournis par le serveur', () {
      final report = ContentReport.fromRow({
        'id': 'report-3',
        'reporter_id': 'user-1',
        'content_type': 'message',
        'content_id': 'message-1',
        'reason': null,
        'status': 'pending',
        'created_at': '2026-10-11T10:00:00Z',
        'content_snapshot': 'texte du message signalé',
        'content_author_id': 'user-2',
      });
      expect(report.contentType, ReportableContentType.message);
      expect(report.contentSnapshot, 'texte du message signalé');
      expect(report.contentAuthorId, 'user-2');
    });

    test('la copie est absente pour les autres contenus et une fois le signalement clos', () {
      final report = ContentReport.fromRow({
        'id': 'report-4',
        'reporter_id': 'user-1',
        'content_type': 'group_post',
        'content_id': 'post-1',
        'reason': null,
        'status': 'resolved',
        'created_at': '2026-10-11T10:00:00Z',
        'content_snapshot': null,
        'content_author_id': 'user-2',
      });
      expect(report.contentSnapshot, isNull);
    });
  });

  group('classifyReportError', () {
    test('code 23505 -> alreadyReported', () {
      const error = PostgrestException(message: 'duplicate key value violates unique constraint', code: '23505');
      expect(classifyReportError(error), ReportErrorKind.alreadyReported);
    });

    test('autre code Postgrest -> generic', () {
      const error = PostgrestException(message: 'permission denied', code: '42501');
      expect(classifyReportError(error), ReportErrorKind.generic);
    });

    test('erreur non-Postgrest -> generic', () {
      expect(classifyReportError(Exception('inattendu')), ReportErrorKind.generic);
    });
  });
}
