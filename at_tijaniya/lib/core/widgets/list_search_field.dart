import 'package:flutter/material.dart';

/// Champ de recherche d'une liste déjà en mémoire (figures, lieux de
/// l'annuaire), avec un bouton pour l'effacer dès qu'il contient du texte.
/// [onChanged] reconstruit la liste à chaque frappe : aucune requête n'est
/// envoyée. Écrit pour l'onglet Figures, partagé avec l'onglet Zawiyas depuis
/// l'audit Zawiyas du 2026-10-25 (P2-1). Libellés fournis par l'écran.
class ListSearchField extends StatelessWidget {
  const ListSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
    required this.clearTooltip,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String hint;
  final String clearTooltip;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: clearTooltip,
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
      ),
    );
  }
}
