import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/presentation/profile_providers.dart';
import '../data/wird_repair_repository.dart';
import '../domain/wird_repair_models.dart';

final wirdRepairRepositoryProvider = Provider<WirdRepairRepository>((ref) => const WirdRepairRepository());

/// Contenu de « Rattraper son wird ». Dépend de [isAdminProvider] : le
/// brouillon n'est demandé que pour l'admin, et le contenu est rechargé si le
/// statut change (connexion, déconnexion). Partagé par la carte de l'écran
/// Wirds (affichée seulement s'il y a du contenu) et par l'écran lui-même.
final wirdRepairContentProvider = FutureProvider<WirdRepairContent>((ref) {
  final isAdmin = ref.watch(isAdminProvider);
  return ref.watch(wirdRepairRepositoryProvider).fetchContent(includeDrafts: isAdmin);
});
