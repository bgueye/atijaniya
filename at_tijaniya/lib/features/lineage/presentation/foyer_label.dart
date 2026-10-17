import '../../../l10n/app_localizations.dart';
import '../domain/lineage_models.dart';

/// Nom d'un foyer dans la langue de l'interface. Partagé par « Ma lignée
/// spirituelle », le formulaire admin d'une figure, le filtre de l'écran
/// Figures et la fiche d'une figure — il était recopié dans les deux premiers
/// écrans avant l'ajout de trois foyers, le 2026-10-18.
String foyerLabel(Foyer foyer, AppLocalizations l10n) {
  return switch (foyer) {
    Foyer.tivaouane => l10n.lineageFoyerTivaouane,
    Foyer.kaolack => l10n.lineageFoyerKaolack,
    Foyer.medinaBaye => l10n.lineageFoyerMedinaBaye,
    Foyer.omarienne => l10n.lineageFoyerOmarienne,
    Foyer.ainMadhi => l10n.lineageFoyerAinMadhi,
    Foyer.fes => l10n.lineageFoyerFes,
    Foyer.autre => l10n.lineageFoyerAutre,
  };
}
