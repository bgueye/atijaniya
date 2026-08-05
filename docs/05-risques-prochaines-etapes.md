# Risques et prochaines étapes

## Risques identifiés

| Risque | Impact | Mesure d'atténuation |
|---|---|---|
| Erreur/approximation dans un contenu religieux | Perte de crédibilité, controverse | Validation systématique par des érudits avant publication |
| Sous-représentation d'une famille religieuse | Sentiment d'exclusion | Compilation exhaustive et itérative, ouverte aux retours |
| Usage détourné du direct natif ouvert à tous | Contenu non conforme diffusé | Modération a posteriori en V1, rôles prévus en V2 |
| Exposition non consentie de la lignée spirituelle | Atteinte à la vie privée, tensions communautaires | Opt-in strict, mise en relation par correspondance sans annuaire public, données chiffrées, exclues des exports/API |
| Variantes de nom du moqaddam | Disciples d'un même moqaddam ne se retrouvent pas | Suggestions à la saisie, normalisation légère, référentiel structuré envisagé en V2 |
| Usurpation du statut de mouqaddam (fausse revendication d'autorité spirituelle) | Confusion des disciples, atteinte à la crédibilité | Statut jamais auto-proclamé : parrainage obligatoire, amorçage contrôlé par le porteur de projet, révocation possible (§ 5.4.2) |
| Chaîne de parrainage rompue ou erronée | Silsila affichée incorrecte, tension communautaire | Révocation par le porteur de projet en cas de signalement ; correction d'un maillon sans réécrire toute la silsila |
| Tension confidentialité / besoin de trouver un parrain | Un candidat ne trouve aucun parrain disponible | Réglage opt-in distinct "disponible comme parrain", indépendant de la visibilité générale du statut |
| Dépendance aux dons | Difficulté à couvrir les coûts d'infrastructure | Suivi des coûts dès la V1, modèle freemium préparé en V2 |
| Reconnaissance calligraphique arabe (saisie/lecture) | Erreurs d'affichage RTL, problèmes de police | Tests spécifiques sur l'affichage bilingue dès les maquettes |

## Prochaines étapes

1. Valider le document de projet (v2.0) comme référence commune, en tranchant
   explicitement le modèle de visibilité de la lignée spirituelle (§ 5.4.1).
2. Engager la Phase 1 (conception) : maquettes haute-fidélité de tous les écrans
   (FR + AR).
3. Faire enregistrer les récitations audio modèles du module Wirds.
4. Poursuivre la compilation/validation des biographies (figures et familles
   religieuses), en priorité pour les écrans P1.
5. Identifier, le cas échéant, des moqaddamines référents supplémentaires par foyer.
6. Constituer, avec le porteur de projet, la liste initiale des mouqaddamines fondateurs
   qui seront validés manuellement pour amorcer le mécanisme de parrainage (§ 5.4.2).
7. Définir l'architecture technique détaillée (Flutter, backend, BDD, streaming,
   chiffrement des données de lignée spirituelle et du graphe de parrainage) en Phase 2.
