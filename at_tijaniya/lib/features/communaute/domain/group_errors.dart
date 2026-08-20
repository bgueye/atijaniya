/// Classification des erreurs de suppression d'un groupe — logique pure,
/// sans dépendance à `BuildContext`/`AppLocalizations` (la traduction se
/// fait côté présentation, voir `group_detail_screen.dart`), même pattern
/// que `classifyEventDeleteError` (`khadara/domain/khadara_errors.dart`).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

enum GroupDeleteErrorKind { blockedByLiveStream, generic }

/// Code Postgres `23503` = violation de clé étrangère — ici
/// `live_streams.group_id`, qui référence le groupe sans `on delete cascade`
/// (volontaire, voir `database/schema.sql`) : suppression bloquée tant qu'un
/// direct y est rattaché. `group_memberships`/`group_posts` ont, eux, un
/// `on delete cascade` sur `group_id` : ils ne peuvent jamais bloquer une
/// suppression de groupe.
GroupDeleteErrorKind classifyGroupDeleteError(Object error) {
  if (error is PostgrestException && error.code == '23503') {
    return GroupDeleteErrorKind.blockedByLiveStream;
  }
  return GroupDeleteErrorKind.generic;
}
