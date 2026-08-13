# Mise à jour — Écran de connexion / création de compte

## Contexte

L'app **At-Tijaniya** (Flutter, backend **Supabase**) a un écran de connexion basique à remplacer par un écran unique avec bascule entre "Connexion" et "Créer un compte", conforme à la charte graphique officielle du projet (voir `At-Tijaniya-Charte-Graphique-Maquettes-v2.html` si présent dans le repo — sinon utiliser les tokens ci-dessous).

**Avant de coder**, localiser dans le repo :
- le fichier d'écran de connexion actuel (probablement un dossier `auth`, `login`, ou `features/auth`)
- le fichier de thème (`theme.dart`, `app_colors.dart`, ou équivalent) — vérifier s'il contient déjà les couleurs zaytoune/émeraude/or/bronze ci-dessous ; sinon les ajouter au thème plutôt que de les hardcoder dans l'écran
- le service d'authentification existant (`auth_service.dart` ou équivalent) et la gestion d'état utilisée (Provider / Riverpod / Bloc / GetX)
- le système de navigation (`go_router`, `Navigator` classique, etc.)
- le `pubspec.yaml` pour confirmer la présence de `supabase_flutter`

## Design tokens (charte graphique)

| Rôle | Nom | Hex |
|---|---|---|
| Fond immersif / écrans de pratique | Vert zaytoune | `#0F3D2E` |
| Actions principales, états actifs | Émeraude | `#1C6E4A` |
| Accent doux (fond de badge/toggle) | Or doux | `#F1E6C9` |
| Accents, filets | Doré mat | `#C9A24B` |
| Fond principal de l'écran | Ivoire parchemin | `#F7F2E7` |
| Texte principal | Encre | `#2B2620` |
| Texte secondaire, bordures | Bronze | `#8C7A5B` |
| Blanc de composants | — | `#FFFDF8` |
| Bordure fine par défaut | — | `#ECE4D0` |

**Typographies** (Google Fonts) :
- **Cormorant Garamond** (poids 500/600) — titres uniquement (`Bienvenue`, `Créer un compte`)
- **Jost** (poids 400/500/600) — tout le texte d'interface (labels, champs, boutons, liens)
- L'arabe (Amiri) n'est **pas** utilisé sur cet écran — réservé aux textes sacrés selon la charte.

**Rayons** : 8px pour boutons et champs de saisie ; 18–22px (pilule) pour le toggle du haut.

## Structure de l'écran

Un seul écran avec un **toggle segmenté** en haut (`Connexion` / `Créer un compte`) qui bascule entre deux panneaux. Pas de navigation entre deux routes séparées — un seul widget avec un état local (`selectedTab` ou équivalent).

### Toggle segmenté
- Piste : fond `#F1E6C9`, radius pilule, padding interne ~4px
- Onglet inactif : texte bronze `#8C7A5B`, fond transparent
- Onglet actif : fond émeraude `#1C6E4A`, texte blanc, `font-weight: 600`

### Panneau "Connexion"
1. Titre `Bienvenue` (Cormorant Garamond, 23px, zaytoune)
2. Sous-titre `Connectez-vous pour retrouver votre communauté.` (Jost, 11px, bronze)
3. Champ **Email** (label bronze uppercase, champ bordé `#ECE4D0`, radius 8px)
4. Champ **Mot de passe** avec icône œil (afficher/masquer le texte saisi)
5. Lien **"Mot de passe oublié ?"** aligné à droite, couleur émeraude, souligné → déclenche le flux de réinitialisation Supabase
6. Bouton primaire **Se connecter** (fond émeraude, texte blanc, pleine largeur)
7. Séparateur `ou continuer avec`
8. 3 boutons de connexion sociale, empilés, bordés (`#ECE4D0`), fond blanc, texte encre : **Google**, **Apple**, **Facebook**
9. Lien texte centré **"Continuer sans compte (pratique du Wird uniquement)"** — accès invité, wirds uniquement

### Panneau "Créer un compte"
1. Titre `Créer un compte`
2. Sous-titre `Rejoignez la communauté et commencez à réciter vos wirds.`
3. Champ **Nom complet**
4. Champ **Email**
5. Champ **Mot de passe** avec icône œil + texte d'aide `8 caractères minimum`
6. Bouton primaire **Créer mon compte**
7. Séparateur `ou continuer avec`
8. Mêmes 3 boutons sociaux (Google / Apple / Facebook)
9. Texte légal centré en bas : *"En créant un compte, vous acceptez nos Conditions d'utilisation et notre Politique de confidentialité."* (liens vers les pages correspondantes si elles existent déjà dans l'app)

## Intégration Supabase

Utiliser `supabase_flutter`. Méthodes attendues :

```dart
// Connexion
await supabase.auth.signInWithPassword(email: email, password: password);

// Création de compte (stocker le nom dans les métadonnées utilisateur)
await supabase.auth.signUp(
  email: email,
  password: password,
  data: {'full_name': nomComplet},
);

// Réinitialisation du mot de passe
await supabase.auth.resetPasswordForEmail(email);

// Connexion sociale
await supabase.auth.signInWithOAuth(OAuthProvider.google);
await supabase.auth.signInWithOAuth(OAuthProvider.apple);
await supabase.auth.signInWithOAuth(OAuthProvider.facebook);
```

Points à vérifier côté Supabase (hors scope du code Flutter, à signaler si manquant) :
- Providers Google / Apple / Facebook activés dans Authentication → Providers du projet Supabase
- Redirect URL / deep link configuré pour le retour OAuth vers l'app mobile
- Template d'email de réinitialisation de mot de passe personnalisé (optionnel)

## Comportements attendus

- Validation avant soumission : email au format valide, mot de passe non vide (et ≥ 8 caractères à la création)
- Erreurs affichées de façon inline sous le champ concerné, pas de dialog bloquant
- État de chargement sur les boutons pendant l'appel réseau (désactivé + spinner, pas de double soumission)
- Bascule Connexion/Inscription : réinitialiser les erreurs de validation du panneau quitté
- Icône œil : bascule uniquement l'affichage local du texte saisi, aucun impact sur la valeur envoyée au backend
- "Continuer sans compte" : redirige vers le mode local du module Wirds sans créer de session Supabase

## Référence visuelle

Deux captures ont été validées avec l'équipe produit :
1. Écran combiné avec toggle segmenté "Connexion / Créer un compte" en haut, pastille active en émeraude
2. Détail du champ mot de passe avec icône œil et lien "Mot de passe oublié ?"

Si le repo contient déjà `At-Tijaniya-Charte-Graphique-Maquettes-v2.html`, s'y référer pour les composants réutilisables (`.btn-primary`, `.btn-secondary`, `.ffield`, `.finput`) et respecter la même nomenclature dans les widgets Flutter équivalents.

## Checklist de recette

- [ ] Toggle segmenté fonctionnel, état actif visuellement correct
- [ ] Les deux panneaux respectent les couleurs et polices de la charte
- [ ] Champ mot de passe : icône œil fonctionnelle sur les deux panneaux
- [ ] "Mot de passe oublié ?" déclenche bien `resetPasswordForEmail` et affiche une confirmation
- [ ] Les 3 boutons sociaux déclenchent le bon provider Supabase
- [ ] Validation des champs avec messages d'erreur inline
- [ ] "Continuer sans compte" reste accessible et fonctionnel
- [ ] Pas de régression sur la navigation existante après connexion réussie
