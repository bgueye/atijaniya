# Périmètre fonctionnel (V1)

## 5.1 Module Wirds — **STATUT : CONTENU VALIDÉ**

Module central : pratique quotidienne des trois wirds.

| Wird | Description | Fréquence |
|---|---|---|
| Lazim | Wird obligatoire quotidien | Quotidienne (matin/soir) |
| Wazifa | Récitation collective ou individuelle | Quotidienne |
| Hadratou-l-Jouma | Cercle de récitation du vendredi | Hebdomadaire |

> Le texte, la translittération et le nombre de répétitions ont été **validés par un
> moqaddam référent du projet**. Hadratou-l-Jouma est fixé à **1600 répétitions**. Ce
> corpus validé est la source de contenu unique pour le développement. Si l'app veut
> représenter plusieurs foyers (Tivaouane, Kaolack, Médina Baye), faire confirmer les
> variantes propres à chaque foyer reste recommandé mais n'est pas bloquant pour la V1.
>
> Contenu source détaillé : voir le document séparé `At-Tijaniya — Module Wirds`.

Fonctionnalités :
- Guide par wird : arabe, translittération, traduction française.
- Audio (récitation modèle), activable/désactivable. *Enregistrement à produire.*
- Tasbih digital multi-modes : tape manuel, reconnaissance vocale, reprise de session.
- Rappels/notifications calés sur les horaires de prière et les fenêtres de validité
  (période privilégiée / période de nécessité — cf. document Module Wirds).
- Historique : régularité, jours consécutifs, statistiques simples.

## 5.2 Module Khadara (évènements et diffusions)

- Calendrier des évènements/ziyaras, géolocalisé.
- Diffusion mixte : agrégation de flux existants (YouTube, Facebook Live) + direct natif
  ouvert à tout utilisateur en V1 (gestion de rôles en V2).
- Rediffusion différée après un direct.
- Annuaire des zawiyas/daaras avec fiches descriptives.
- Contenu informatif sur le déroulement des khadara pour les nouveaux disciples.

## 5.3 Module Figures et enseignements

- Biographies des figures fondatrices (à commencer par Cheikh Ahmed Tijane).
- Silsila (généalogie spirituelle historique de la tarikha) illustrée et navigable —
  distincte du lien personnel disciple/moqaddam du module communautaire.
- Recueil de citations et enseignements.
- Dates commémoratives reliées au calendrier Khadara.
- Biographies des familles religieuses tijanies du Sénégal (Tivaouane, Kaolack, Médina
  Baye, etc. — à documenter et valider).

## 5.4 Module communautaire

- Fil d'actualité (publications communauté + zawiyas suivies).
- Commentaires et likes.
- Groupes de discussion par zawiya/région.
- Messagerie privée.

### 5.4.1 Ma lignée spirituelle — retrouver les disciples de son moqaddam

Chaque disciple peut renseigner, dans son profil, le moqaddam qui lui a transmis le
Wird et l'année de transmission, pour se retrouver entre disciples de la même lignée.

**Saisie (décision validée) :**
- Foyer : liste fermée à choix unique — Tivaouane / Kaolack / Médina Baye / Autre
  (précision en texte libre si "Autre").
- Nom du moqaddam : texte libre (pas de référentiel centralisé en V1 ; suggestions à
  la saisie basées sur les noms déjà renseignés par d'autres disciples du même foyer,
  recommandées pour limiter les variantes orthographiques).
- Année de transmission : sélecteur d'année (ou période approximative).
- Zawiya/lieu de transmission (optionnel) : texte libre.

**Visibilité et mise en relation — recommandation à valider avant développement :**
- Par défaut, l'information est **privée** (n'apparaît ni sur le profil public ni dans
  le fil d'actualité).
- Le disciple peut activer, dans ses paramètres de confidentialité, l'option **"Me
  rendre visible aux disciples de mon moqaddam"** — désactivée par défaut (opt-in strict).
- Si activée, le disciple n'apparaît que dans les résultats de recherche d'autres
  disciples ayant activé la même option et renseigné le même foyer + même moqaddam
  (correspondance exacte/quasi-exacte). **Jamais d'annuaire public général.**
- Résultats de correspondance : aperçu minimal (prénom/pseudonyme, avatar, année) ; la
  mise en relation complète nécessite une acceptation explicite du disciple contacté.
- Désactivation possible à tout moment ; les données redeviennent alors strictement
  privées.

> ⚠️ **Ce comportement est une recommandation par défaut, pas une décision figée.** À
> valider explicitement par le porteur de projet avant l'implémentation. Alternatives
> possibles : badge de lignée public sur le profil, ou validation manuelle par un
> modérateur avant toute mise en relation.

### 5.4.2 Statut "Mouqaddam vérifié" et silsila d'ijaza

Un utilisateur qui est lui-même mouqaddam (il transmet le Wird) peut faire reconnaître
ce statut et renseigner sa propre silsila d'ijaza — la chaîne de transmission qui remonte
jusqu'à Cheikh Ahmed Tijane. **Statut additif** : un mouqaddam reste un disciple comme les
autres pour sa pratique personnelle, avec cette fonctionnalité en plus sur son profil.

**Établissement du statut — déclaration + parrainage (jamais auto-proclamé) :**
- Écran "Devenir Mouqaddam" : le candidat indique le nom de son parrain (le mouqaddam qui
  lui a donné l'ijaza) et la date de transmission.
- Le parrain désigné, s'il est déjà mouqaddam vérifié, reçoit la demande sur son écran
  "Demandes de parrainage" et l'accepte ou la refuse. L'acceptation confirme le statut.
- **Amorçage (bootstrap)** : au départ, aucun mouqaddam vérifié n'existe pour parrainer les
  premiers. Le porteur de projet dispose d'une capacité d'administration pour valider
  manuellement un noyau initial de mouqaddamines fondateurs — en incluant si possible le
  moqaddam référent qui a déjà validé le module Wirds (§ 8). Le parrainage entre pairs
  prend ensuite le relais.
- Le porteur de projet peut à tout moment **révoquer** un statut de mouqaddam vérifié en
  cas de signalement ou de litige (filet de sécurité).

**Silsila d'ijaza — reconstruction automatique de la chaîne :**
- Chaque mouqaddam ne saisit que son propre maillon (son parrain + date) — pas de
  ressaisie manuelle de toute la chaîne historique.
- Comme ce parrain est lui-même un mouqaddam de l'app avec son propre maillon enregistré,
  l'app remonte automatiquement le graphe de parrainage pour reconstruire la chaîne
  complète, affichée sur l'écran "Ma silsila d'ijaza".
- Quand la chaîne sort du périmètre de l'app (ancêtre n'ayant jamais utilisé l'app), le
  dernier maillon connu complète manuellement le reste en texte libre (nom + date
  approximative), jusqu'à Cheikh Ahmed Tijane.

**Visibilité :**
- Même modèle que la lignée du disciple (§ 5.4.1) : **privé par défaut**, opt-in pour
  rendre visible le statut et la silsila.
- Réglage opt-in **distinct** : "Être disponible comme parrain potentiel" — rend le nom
  découvrable dans la recherche de parrainage sans exposer la silsila complète avant
  qu'une demande soit acceptée. Nécessaire car sinon un candidat ne peut trouver aucun
  parrain à solliciter si tout reste privé par défaut.

> **Précision de périmètre** : ce mécanisme reste une vérification communautaire légère
> (statut + silsila affichable), jamais une permission technique (modération, validation
> de contenu religieux, administration de zawiya). La gestion fine des rôles reste hors
> périmètre V1 (§ 6).

## 5.5 Fonctionnalités transverses

- Interface bilingue FR/AR (RTL).
- Compte utilisateur et profil (zawiya de rattachement, lignée spirituelle).
- Système de dons intégré.
- Paramètres de notifications et de confidentialité (incl. visibilité de la lignée).

## 6. Hors périmètre de la V1

- Gestion fine des rôles/permissions (moqaddam, admin de zawiya, modérateur).
- Abonnement premium, publicité.
- Langues additionnelles (wolof, anglais...).
- Streaming propriétaire avancé.
- Référentiel structuré et validé des moqaddamines par foyer.
- Modération assistée/automatisée des mises en relation par lignée (modération a
  posteriori suffit en V1).

> Précision : le statut "Mouqaddam vérifié" et le parrainage (§ 5.4.2) n'échappent pas à
> ce point — ils octroient un badge et une silsila affichable, jamais de permission
> technique.

## 7. Modèle économique

| Phase | Modèle | Détails |
|---|---|---|
| V1 (lancement) | Gratuit + dons | Aucune fonctionnalité payante |
| V2 (envisagée) | Freemium | Contenu exclusif, suppression pub |
| V2+ (à étudier) | Publicité | À arbitrer selon l'acceptabilité communautaire |

## 8. Contenu religieux : sources et validation

| Contenu | Statut | Détail |
|---|---|---|
| Module Wirds | **Validé** | Moqaddam référent, Hadratou-l-Jouma = 1600 répétitions |
| Biographies figures fondatrices | À valider | Compilation à mener |
| Biographies familles religieuses | À valider | Sensible — nécessite compilation par foyer |
| Audio récitations modèles | À produire | Sur la base du texte déjà validé |
| Page pédagogique "Comprendre la Zawiya" (`guide_pages`, slug `comprendre-zawiya`) | **Validé** (2026-08-29) | Validé par le porteur de projet (Bocar) ; compilation à partir de sources externes (Wikipédia, Techno-Science, Enass, The Culture Mapper, zawiya.defarsci.fr, revues.imist.ma) |
| Page pédagogique "Comprendre la Khadara" (`guide_pages`, slug `comprendre-khadara`, sur la Hadaratou-l-Jouma) | À valider | Brouillon en base, non branché à un écran — décrit le rituel de la Hadra, distinct de "Comprendre la Zawiya" (annuaire de l'onglet Khadara) |

> **Règle impérative : aucun contenu religieux ne doit être publié sans validation
> préalable par un moqaddam ou érudit reconnu.**
