import 'package:flutter/widgets.dart';

import '../domain/wird_models.dart';

/// Nom d'un wird dans la langue de l'interface : le nom arabe du corpus
/// validé en arabe, le nom français sinon. Les titres d'écran affichaient
/// toujours `nameFrench`, même en arabe (audit du 2026-10-04).
String wirdDisplayName(BuildContext context, Wird wird) {
  return Localizations.localeOf(context).languageCode == 'ar' ? wird.nameArabic : wird.nameFrench;
}
