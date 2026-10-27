// Intitulés et sections réseau de l'accueil (chargement, erreur, hors ligne).
// Extrait de `home_screen.dart` (audit de l'accueil du 2026-10-26, P3-5).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/content_text.dart';

/// Section de l'accueil alimentée par le réseau (audit de l'accueil du
/// 2026-10-26, P2-2) :
/// - chargement : un emplacement de [placeholderHeight], pour que la page ne
///   saute pas à l'arrivée du contenu ;
/// - erreur sans contenu : message local (hors ligne distingué) et
///   « Réessayer », les autres sections restant affichées ;
/// - échec d'une mise à jour : le dernier contenu reçu pendant la session
///   reste affiché, avec une mention.
class HomeNetworkSection<T> extends StatelessWidget {
  const HomeNetworkSection({
    super.key,
    required this.value,
    required this.placeholderHeight,
    required this.errorMessage,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final double placeholderHeight;
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
            HomeSectionNotice(isNetworkError(error) ? l10n.homeSectionOfflineStale : l10n.homeSectionStale),
          builder(value.requireValue),
        ],
      );
    }
    if (error != null && !value.isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(isNetworkError(error) ? Icons.wifi_off : Icons.error_outline, color: AppColors.bronze, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isNetworkError(error) ? l10n.khadaraOfflineError : errorMessage,
                  style: TextStyle(color: AppColors.secondaryInk, fontSize: 13),
                ),
              ),
              TextButton(onPressed: onRetry, child: Text(l10n.homeRetry)),
            ],
          ),
        ),
      );
    }
    return Semantics(
      label: l10n.homeSectionLoading,
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

/// Court message sous un intitulé de section (vide, hors ligne).
class HomeSectionNotice extends StatelessWidget {
  const HomeSectionNotice(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(text, style: TextStyle(color: AppColors.secondaryInk, fontSize: 12.5)),
    );
  }
}

class HomeSectionLabel extends StatelessWidget {
  const HomeSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      // Annoncé comme titre (P2-6) : TalkBack peut passer de section en
      // section ; encre secondaire plutôt que bronze (3,72:1).
      child: Semantics(
        header: true,
        child: ContentText(
          text,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            color: AppColors.secondaryInk,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
