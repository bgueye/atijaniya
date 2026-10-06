import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demande de retour à l'écran de connexion, émise depuis n'importe quel écran
/// (aujourd'hui : l'état « connectez-vous » du profil). `AtTijaniyaApp` écoute
/// ce compteur et repasse à l'étape d'authentification.
///
/// Ajouté lors de l'audit du 2026-10-04 : un invité arrivé dans l'app n'avait
/// aucun moyen de revenir à la connexion sans tuer puis relancer l'app.
/// Un compteur plutôt qu'un booléen : chaque demande est un évènement
/// distinct, même deux fois de suite.
final signInRequestProvider = StateProvider<int>((ref) => 0);
