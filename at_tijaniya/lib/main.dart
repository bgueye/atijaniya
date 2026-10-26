import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/locale_controller.dart';
import 'features/wird/data/wird_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  // Rappels du Wird (docs/03-architecture-ecrans.md) : initialise le moteur
  // de notifications locales au démarrage — la permission n'est demandée que
  // plus tard, quand le disciple active son premier rappel (voir
  // WirdReminderController.setEnabled).
  await WirdNotificationService.instance.init();
  // Langue enregistrée (audit de l'accueil du 2026-10-26, P2-1) : connue dès
  // le premier affichage, l'étape de choix de langue est sautée.
  final savedLocale = await LocaleStore.load();
  runApp(ProviderScope(
    overrides: [initialLocaleProvider.overrideWithValue(savedLocale)],
    child: const AtTijaniyaApp(),
  ));
}
