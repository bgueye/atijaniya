import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/presentation/profile_providers.dart';
import '../data/tariqa_benefits_repository.dart';

final tariqaBenefitsRepositoryProvider = Provider<TariqaBenefitsRepository>((ref) => const TariqaBenefitsRepository());

/// Contenu brut de « Bienfaits de la Tijaniyya ». Dépend de [isAdminProvider] :
/// le brouillon n'est demandé que pour l'admin, et le contenu est rechargé si
/// le statut change (connexion, déconnexion). Partagé par la carte de l'écran
/// Wirds (affichée seulement s'il y a du contenu) et par l'écran lui-même.
final tariqaBenefitsRowsProvider = FutureProvider<TariqaBenefitsRows>((ref) {
  final isAdmin = ref.watch(isAdminProvider);
  return ref.watch(tariqaBenefitsRepositoryProvider).fetchRows(includeDrafts: isAdmin);
});
