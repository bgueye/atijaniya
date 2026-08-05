# At-Tijaniya — démarrage du frontend Flutter

Ce dossier `at_tijaniya/` est un **squelette de départ**, pas un projet Flutter
généré par `flutter create`. Il a été préparé côté documentation/architecture
(dans cet environnement de chat, qui n'a pas le SDK Flutter ni l'accès
réseau), pour que la suite se fasse directement avec **Claude Code en local**,
là où `flutter`, les émulateurs et Supabase MCP sont disponibles.

## Ce qui est déjà fait ici
- Architecture feature-first (`lib/features/...`) alignée sur
  `docs/03-architecture-ecrans.md`.
- Thème Flutter (`lib/core/theme/app_theme.dart`) généré à partir des tokens
  validés (`design/design_tokens.yaml`, `app_colors.dart` repris tel quel).
- i18n FR/AR avec RTL automatique (`lib/l10n/app_fr.arb`, `app_ar.arb`,
  `l10n.yaml`) — Flutter gère la directionnalité seul dès que la `Locale`
  est `ar`.
- Parcours P0 câblé bout en bout : Splash → Choix de langue → Auth (ou
  invité) → Shell à 5 onglets (Accueil, Wird, Khadara, Figures, Communauté)
  → Profil.
- Client Supabase pointant vers le projet live `at-tijaniya`
  (`elrxlhhmkjfcbmiloilp`, eu-west-3), clé anon lue via `--dart-define`.
- Écrans Khadara / Figures / Communauté en placeholders explicites (P1/P2 —
  pas de contenu inventé, conformément à la règle "contenu religieux" de
  `CLAUDE.md`).

## Étapes pour reprendre la main avec Claude Code, en local

1. **Générer les projets natifs manquants** (android/, ios/, etc.) sans
   écraser `lib/` :
   ```bash
   flutter create --org com.attijaniya --project-name at_tijaniya \
     --platforms android,ios .
   ```
   (à lancer depuis le dossier `at_tijaniya/`, une fois ce squelette copié
   dans votre repo de travail à côté de `docs/`, `design/`, `database/`.)

2. **Récupérer les dépendances** :
   ```bash
   flutter pub get
   ```

3. **Générer les fichiers de localisation** (`AppLocalizations`) :
   ```bash
   flutter gen-l10n
   ```
   (normalement automatique au `pub get` grâce à `generate: true` dans
   `pubspec.yaml`, mais utile à relancer après modification des `.arb`.)

4. **Renseigner les clés Supabase** au lancement — Claude Code, avec le
   connecteur Supabase déjà utilisé pour le backend, peut aller chercher
   l'URL et la clé anon directement sur le projet `at-tijaniya` :
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://elrxlhhmkjfcbmiloilp.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<clé anon du projet>
   ```

5. **Remplacer `Image.asset(...svg...)` du splash screen** par
   [`flutter_svg`](https://pub.dev/packages/flutter_svg) (`Image.asset` ne
   sait pas nativement afficher un `.svg`) — ajouté volontairement comme
   TODO plutôt que déjà fait, pour rester réductible tant que le projet
   n'a pas été compilé une première fois.

## Prochain incrément logique (P0, suite)
D'après `docs/04-roadmap-developpement.md`, il reste pour boucler le P0 :
- Écran "Guide d'un Wird" (arabe + translittération + traduction + lecture
  séquencée) — **attend le corpus validé du document "Module Wirds"**, à
  fournir avant de coder le moindre texte.
- Lecteur audio synchronisé.
- Tasbih digital multi-modes.
- Paramètres de rappels (notifications calées sur horaires de prière).
- Paramètres généraux et confidentialité (base).

Le plus efficace : ouvrir ce dossier avec Claude Code en local et continuer
écran par écran dans cet ordre, en gardant `CLAUDE.md` comme référence de
règles impératives (RLS, champs sensibles, contenu religieux validé).
