# Architecture de l'information & inventaire des écrans

## Navigation principale
Barre d'onglets inférieure, 5 destinations (icônes + libellés en Jost, jamais en Amiri) :
**Accueil · Wird · Khadara · Figures · Communauté**. Profil accessible via une icône
avatar en en-tête sur toutes les sections principales.

Priorités : P0 = socle indispensable, P1 = enrichissement, P2 = communauté élargie,
P3 = consolidation avant lancement. Détail du séquencement : `04-roadmap-developpement.md`.

## Onboarding & compte

| Écran | Description | Priorité |
|---|---|---|
| Splash screen | Logo Sceau-rosace fond zaytoune, animation discrète | P0 |
| Choix de la langue | FR/AR au premier lancement, bascule RTL immédiate | P0 |
| Inscription / Connexion | Email ou téléphone. Mode consultation sans compte possible pour le module Wirds seul (à valider) | P0 |
| Onboarding — présentation | 3-4 écrans d'introduction (wirds, khadara, communauté) | P1 |

> Recommandation à valider : autoriser la pratique du Wird sans compte (données locales
> sur l'appareil) ; compte requis uniquement pour les fonctionnalités communautaires
> (silsila, messagerie, groupes) et la synchronisation multi-appareils.

## Module Wirds

| Écran | Description | Priorité |
|---|---|---|
| Accueil / Tableau de bord | Statut du jour, accès rapide, prochain horaire | P0 |
| Liste des Wirds | Lazim, Wazifa, Hadratou-l-Jouma | P0 |
| Guide d'un Wird | Arabe, translittération, traduction, lecture séquencée | P0 |
| Lecteur audio du Wird | Récitation modèle, synchronisée au texte | P0 |
| Tasbih digital | Tape manuel, reconnaissance vocale, reprise de session | P0 |
| Historique & progression | Régularité, jours consécutifs, taux de complétion | P1 |
| Paramètres de rappels | Notifications calées sur horaires de prière | P0 |

## Module Khadara

| Écran | Description | Priorité |
|---|---|---|
| Calendrier des évènements | Liste + carte, évènements/ziyaras géolocalisés | P1 |
| Détail d'un évènement | Lieu, date, description, rejoindre/démarrer un direct | P1 |
| Direct | Lecteur natif + agrégation de flux externes | P2 |
| Rediffusions | Directs passés, lecture différée | P2 |
| Annuaire des zawiyas/daaras | Liste + fiche détail | P1 |
| Comprendre la Khadara | Contenu pédagogique nouveaux disciples | P1 |

## Module Figures et enseignements

| Écran | Description | Priorité |
|---|---|---|
| Liste des figures | Fondateurs et familles religieuses | P1 |
| Biographie détaillée | Texte, citations, ziyara associée | P1 |
| Silsila (généalogie) | Arbre navigable, chaîne historique de la tarikha | P2 |
| Recueil de citations | Classable par figure/thème | P2 |

## Module Communauté

| Écran | Description | Priorité |
|---|---|---|
| Fil d'actualité | Publications communauté + zawiyas suivies | P1 |
| Détail d'une publication | Contenu, commentaires, likes | P1 |
| Groupes | Liste par zawiya/région + fil de discussion | P2 |
| Messagerie privée | Liste de conversations + fil individuel | P2 |
| Mon profil | Infos de base, zawiya, "Ma lignée spirituelle" | P0 |
| Renseigner ma lignée spirituelle | Foyer, nom du moqaddam (suggestions), année, zawiya (optionnel) | P1 |
| Retrouver mes condisciples (lignée) | Activation mise en relation, résultats (aperçu minimal), action "Se mettre en relation" | P1 |
| Devenir Mouqaddam | Déclaration du statut : choix du parrain (mouqaddam ayant donné l'ijaza) + date ; envoi de la demande de parrainage | P2 |
| Demandes de parrainage | Côté mouqaddam vérifié : demandes reçues, accepter/refuser | P2 |
| Rechercher un parrain | Recherche des mouqaddamines "disponibles comme parrain", pour l'écran Devenir Mouqaddam | P2 |
| Ma silsila d'ijaza | Chaîne reconstruite automatiquement via le graphe de parrainage + complément manuel au-delà de l'app | P2 |
| Paramètres de confidentialité | Visibilité de la lignée ET du statut mouqaddam (opt-in), disponibilité comme parrain, qui peut contacter | P0 |

## Fonctionnalités transverses

| Écran | Description | Priorité |
|---|---|---|
| Paramètres généraux | Langue, notifications, confidentialité, à propos | P0 |
| Faire un don | Don ponctuel/récurrent, moyens de paiement | P1 |

## Notes de conception transverses
- Toutes les maquettes doivent être déclinées en version arabe (RTL) dès la Phase 1,
  en particulier les écrans denses (historique, calendrier, fil d'actualité, formulaire
  de lignée spirituelle).
- Écrans de pratique (Wird, Direct en cours) : fond zaytoune immersif. Tous les autres :
  fond ivoire parchemin.
- Le champ "nom du moqaddam" est une donnée sensible : chiffrement au repos recommandé,
  journalisation d'accès, exclusion des exports/API publics tant que la mise en relation
  n'est pas activée par l'utilisateur (cf. `01-perimetre-fonctionnel.md` § 5.4.1).
- Le statut "Mouqaddam vérifié" et la silsila d'ijaza suivent la même règle de sensibilité
  des données que ci-dessus (cf. § 5.4.2). Le graphe de parrainage (qui-a-parrainé-qui)
  doit être modélisé comme une structure de données à part, interrogeable pour la
  reconstruction de chaîne, mais non exposée publiquement.
