import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/supabase/supabase_config.dart';
import 'features/wird/data/wird_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  // Rappels du Wird (docs/03-architecture-ecrans.md) : initialise le moteur
  // de notifications locales au démarrage — la permission n'est demandée que
  // plus tard, quand le disciple active son premier rappel (voir
  // WirdReminderController.setEnabled).
  await WirdNotificationService.instance.init();
  runApp(const ProviderScope(child: AtTijaniyaApp()));
}
