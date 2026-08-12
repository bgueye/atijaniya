/// Classification des erreurs de suppression d'évènement Khadara — logique
/// pure, sans dépendance à `BuildContext`/`AppLocalizations` (la traduction
/// se fait côté présentation, voir `event_detail_screen.dart`), même
/// pattern que `classifyAuthError` (`auth/domain/auth_error_message.dart`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

enum EventDeleteErrorKind { blockedByLiveStream, generic }

/// Code Postgres `23503` = violation de clé étrangère — ici
/// `live_streams.event_id`, qui référence l'évènement sans `on delete
/// cascade` (volontaire, voir `database/schema.sql`) : suppression bloquée
/// tant qu'un direct y est rattaché.
EventDeleteErrorKind classifyEventDeleteError(Object error) {
  if (error is PostgrestException && error.code == '23503') {
    return EventDeleteErrorKind.blockedByLiveStream;
  }
  return EventDeleteErrorKind.generic;
}
