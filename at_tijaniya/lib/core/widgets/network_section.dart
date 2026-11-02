// Section d'écran alimentée par le réseau (kit de composants, fiche Notice) :
// chargement, erreur, ou dernier contenu reçu avec une mention. Déplacée de
// `features/home/presentation/home_sections.dart` (`HomeNetworkSection`,
// audit de l'accueil du 2026-10-26, P2-2 et P3-5) pour que les autres écrans
// refaits aient le même comportement que l'accueil.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../network/network_errors.dart';
import '../theme/app_colors.dart';
import 'notice.dart';

/// - chargement : un emplacement de [placeholderHeight], pour que la page ne
///   saute pas à l'arrivée du contenu ;
/// - erreur sans contenu : [Notice.error] (hors ligne distingué) et
///   « Réessayer », les autres sections de l'écran restant affichées ;
/// - échec d'une mise à jour : le dernier contenu reçu pendant la session
///   reste affiché, précédé d'une mention.
class NetworkSection<T> extends StatelessWidget {
  const NetworkSection({
    super.key,
    required this.value,
    required this.placeholderHeight,
    required this.errorMessage,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final double placeholderHeight;

  /// Message propre à la section quand l'erreur ne vient pas de la
  /// connexion (« Impossible de charger les évènements. »).
  final String errorMessage;
  final VoidCallback onRetry;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = value.error;
    if (value.hasValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null && !value.isLoading)
            SectionNote(isNetworkError(error) ? l10n.sectionOfflineStale : l10n.sectionStale),
          builder(value.requireValue),
        ],
      );
    }
    if (error != null && !value.isLoading) {
      return Notice.fromError(error, message: errorMessage, onRetry: onRetry);
    }
    return Semantics(
      label: l10n.sectionLoading,
      child: Container(
        height: placeholderHeight,
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bronze.withValues(alpha: 0.15)),
        ),
      ),
    );
  }
}

/// Courte mention au-dessus d'un contenu (« Hors ligne : dernières
/// informations reçues. »). Pas une [Notice] : le contenu est là, la mention
/// ne fait que le dater.
class SectionNote extends StatelessWidget {
  const SectionNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(text, style: TextStyle(color: AppColors.secondaryInk, fontSize: 12.5)),
    );
  }
}
