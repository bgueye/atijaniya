# Spec — Animation de révélation de la silsila d'ijaza

> Addendum à l'écran existant **« Ma silsila d'ijaza »** (module Communauté,
> §5.4.2 du document de projet, priorité P2 — `03-architecture-ecrans.md`).
> Cette spec ajoute une animation de révélation et une carte de partage à un
> écran déjà prévu dans l'app ; elle ne redéfinit pas l'écran lui-même.
>
> Prototype visuel (HTML, à ouvrir dans un navigateur) : voir le fichier
> `silsila-animation-prototype.html` fourni séparément — il fait foi pour le
> timing et l'enchaînement visuel exact. Ce document donne la spec
> d'implémentation Flutter correspondante.

## 1. Objectif

Transformer un moment technique (chaîne de parrainage reconstruite par
`get_ijaza_chain()`) en un moment émotionnel : l'utilisateur voit sa lignée
spirituelle "remonter" jusqu'à Cheikh Ahmed Tijani, maillon par maillon.
C'est le candidat le plus fort à l'effet "waouh" de l'app — à ce titre,
cette animation doit être fluide et sans bug, quitte à réduire son
ambition plutôt que de la livrer approximative.

## 2. Déclenchement — une seule fois, au bon moment

- **Déclencheur principal** : notification push "Votre parrainage a été
  accepté" → tap → ouverture directe sur l'écran silsila → l'animation se
  joue automatiquement, immédiatement.
- **Accès permanent** : entrée de menu "Ma silsila d'ijaza" (déjà prévue).
  Hors du contexte de la notification, l'écran s'ouvre à l'état final
  statique (pas de replay automatique) avec un bouton "▶ Revivre
  l'ascension".
- Stocker un flag local (`silsila_intro_played_at`, SharedPreferences/Hive)
  pour ne jouer l'auto-lecture qu'une fois par acceptation de parrainage
  (pas à chaque ouverture de l'app).

## 3. Source de données

Appel à la fonction Postgres déjà déployée `get_ijaza_chain(mouqaddam_id)`
(voir `database/schema.sql` §3), puis enrichissement côté client :

```
ChainLink {
  String? userId;         // null si maillon manuel
  String displayName;     // profiles.display_name, ou name_text si manuel
  String? yearLabel;      // ijaza_year ou year_text
  bool isManual;          // is_manual de get_ijaza_chain()
  bool isSelf;            // userId == utilisateur courant
  bool isFounder;         // voir §6, ne JAMAIS déduire du nom par string-match
  bool isVisibleForSharing; // privacy_settings.mouqaddam_status_visible du maillon
}
```

`isVisibleForSharing` : jointure supplémentaire sur `privacy_settings` pour
chaque `userId` non-nul de la chaîne. Un maillon manuel (`isManual = true`)
est toujours traité comme visible dans le partage (c'est déjà un texte
libre, pas une donnée personnelle d'un utilisateur de l'app).

## 4. Séquence d'animation

Ordre bas → haut : `self` en bas, remontée vers le maillon le plus ancien.
Ce sens est délibéré : il fonctionne à l'identique en RTL (arabe), aucune
logique miroir à gérer.

Pour chaque maillon `i` (sauf le premier) :
1. Un trait doré se dessine du maillon précédent vers le futur maillon
   (grandeur de 0 à la hauteur cible, ~520ms, easing standard).
2. Le nœud suivant apparaît : fade-in + léger scale (0.94→1) et
   translateY (14px→0), ~400ms.
3. `HapticFeedback.lightImpact()` au moment où le nœud devient visible.
4. Pause ~450ms avant le maillon suivant.

**Dernier maillon = climax UNIQUEMENT si `isFounder == true`** (voir §6) :
rosace du logo qui s'anime en fondu + rotation (-25°→0°) + scale (0.4→1)
autour du nœud, ~700-900ms, puis pulsation douce en boucle (glow subtil,
jamais agressif). Si le dernier maillon n'est pas le fondateur, l'animation
s'arrête sobrement — pas de climax forcé (voir §6).

**Accessibilité** : si `MediaQuery.of(context).disableAnimations` (lit le
réglage système "réduire les animations"), sauter directement à l'état
final statique, tous les maillons visibles, sans étapes. Prévoir aussi un
toggle explicite dans les paramètres d'accessibilité de l'app (cf.
`design/design_tokens.yaml` — mode contraste renforcé déjà prévu pour les
utilisateurs âgés, même logique).

## 5. Style visuel (tokens existants — voir `design/design_tokens.yaml`)

| Élément | Traitement |
|---|---|
| Fond de l'écran | `AppColors.zaytoune`, immersif (même famille que Wird/Khadara en direct) |
| Trait de connexion | `AppColors.gold`, degradé vers transparent |
| Nœud standard / vérifié | `AppColors.offWhite`, texte `AppColors.zaytoune` |
| Nœud "moi" (self) | Même carte + bordure 2px `AppColors.gold` |
| Nœud manuel (hors app) | Fond à motif diagonal léger + bordure pointillée `AppColors.bronze` — signale honnêtement que la donnée n'est plus vérifiée par le graphe, sans rupture brutale de style |
| Nœud fondateur (climax) | Fond `AppColors.zaytoune` plein, texte en `AppFonts.sacredAndArabic` (Amiri), taille supérieure, halo doré animé |

Respecter la règle typographique déjà actée : `AppFonts.sacredAndArabic`
réservée au nom du fondateur et aux textes religieux, jamais aux libellés
d'interface (boutons, titres d'écran).

## 6. Règle importante : ne jamais forcer le climax

Le nœud "fondateur" ne doit recevoir le traitement climax que si l'app est
certaine qu'il s'agit bien de Cheikh Ahmed Tijani — jamais par déduction
sur le fait que c'est "le dernier maillon disponible". Une chaîne
incomplète (mouqaddam qui n'a pas encore renseigné son complément manuel
jusqu'au fondateur) ne doit pas se voir attribuer un faux climax sur un
ancêtre intermédiaire.

**Recommandation d'implémentation** : ajouter un champ explicite plutôt que
de comparer des chaînes de texte (fragile, sensible aux variantes
orthographiques déjà documentées comme risque au §12 du document de
projet) :
- Option A (préférée) : colonne booléenne `is_ultimate_source` sur la
  dernière ligne de `mouqaddam_manual_chain_links` d'une chaîne, cochée
  explicitement par l'utilisateur qui saisit le complément manuel
  ("Cette personne est-elle Cheikh Ahmed Tijani, à l'origine de la
  tarikha ?").
- Option B (repli) : une constante `FOUNDER_FIGURE_ID` côté app pointant
  vers la ligne `figures` de Cheikh Ahmed Tijani (déjà en base, §8), et
  comparaison sur un futur champ de liaison plutôt que sur le texte du nom.

Si la chaîne s'arrête sans confirmation du fondateur : terminer sobrement
sur le dernier maillon connu, éventuellement avec un CTA discret si c'est
la silsila du viewer lui-même : "Compléter ma silsila jusqu'à la source".

## 7. Carte de partage

Bouton "Partager ma silsila" → génère une image dédiée (pas une capture
d'écran brute), format story 9:16 (1080×1920 en export réel) :

- Filigrane rosace, très discret (même contrainte que partout ailleurs :
  jamais en pattern répété).
- Titre "Ma silsila d'ijaza" (Jost) + "التجانية" (Amiri) en en-tête.
- Chaîne simplifiée verticale : **un maillon n'affiche son nom que si
  `isVisibleForSharing == true`** ; sinon afficher "🔒 maillon privé" —
  jamais le nom d'un mouqaddam qui n'a pas choisi de rendre son statut
  visible, même si l'utilisateur qui partage, lui, voit ce nom sur son
  propre écran (voir prototype HTML fourni, nœud "Serigne Fallou D." pour
  un exemple concret de ce cas).
- Pied de carte : nom de l'app + accroche courte, pensé comme mécanique
  virale (quelqu'un qui reçoit l'image doit avoir envie de savoir ce
  qu'est At-Tijaniya).

**Implémentation technique** : `RenderRepaintBoundary.toImage()` sur un widget
hors-écran dimensionné à l'export, ou package `screenshot` ; partage via
`share_plus`. Générer l'image à la demande (pas de pré-génération/cache
côté serveur, le filtre de confidentialité doit toujours refléter l'état
courant de `privacy_settings`).

## 8. Cas limites

- **Chaîne à un seul maillon** (le viewer est lui-même le fondateur, ou un
  fondateur bootstrap sans parrain) : pas d'animation d'ascension, juste
  le nœud self affiché directement — inutile de jouer une animation vide.
- **Chaîne longue (>8 maillons)** : prévoir un scroll une fois l'animation
  terminée ; ne pas essayer de tout faire tenir sur un seul écran sans
  défilement.
- **Maillon dont le `displayName` est très long** : tronquer avec ellipsis
  plutôt que casser la mise en page de la carte.
- **Échec réseau pendant le chargement de la chaîne** : état de chargement
  simple (le graphe est déjà en base, l'appel est rapide), puis message
  d'erreur classique avec retry — pas de fallback silencieux qui
  afficherait une chaîne incomplète sans le signaler.

## 9. Ce qui n'est pas dans cette spec

- La construction de l'écran "Ma silsila d'ijaza" lui-même (déjà prévue,
  cf. `03-architecture-ecrans.md`) — cette spec ajoute l'animation et le
  partage à cet écran existant.
- Le mécanisme de parrainage et la reconstruction de chaîne (déjà
  implémentés en base, `database/schema.sql` §3).
- Toute mise à jour de schéma pour `is_ultimate_source` (§6, option A) :
  à valider et migrer séparément si cette option est retenue.
