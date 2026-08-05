# At-Tijaniya — Aperçu du projet

> Version 2.0 — Août 2026. Cahier des charges fonctionnel complet : voir aussi
> `01-perimetre-fonctionnel.md`, `02-identite-visuelle-design-system.md`,
> `03-architecture-ecrans.md`, `04-roadmap-developpement.md`.

## Résumé exécutif

At-Tijaniya (التجانية) est une application mobile destinée aux disciples de la voie
soufie Tijaniyya, fondée par Cheikh Ahmed Tijane. Elle centralise, sur un seul outil
accessible au quotidien, l'ensemble des pratiques spirituelles, du contenu doctrinal
et de la vie communautaire propres à la tarikha : les wirds (Lazim, Wazifa,
Hadratou-l-Jouma), les khadara (rassemblements et diffusions), les biographies des
grandes figures fondatrices et des familles religieuses tijanies, ainsi qu'un espace
communautaire permettant aux disciples de se retrouver entre eux — notamment autour
du moqaddam qui leur a transmis le Wird.

Le contenu du module Wirds a été validé par un moqaddam référent du projet. Application
développée en Flutter, lancement simultané Android/iOS, français + arabe dès la V1,
gratuite et financée par les dons.

## Contexte

La Tijaniyya est l'une des voies soufies les plus répandues en Afrique de l'Ouest
(Sénégal, Mauritanie, Mali, Nigeria...). Ses disciples pratiquent quotidiennement des
invocations codifiées (wirds) et se rassemblent dans des cercles de récitation (khadara)
autour des zawiyas et daaras. Ces pratiques restent dispersées entre supports papier,
enregistrements informels et transmission orale — sans outil numérique unifié.

Un élément central de l'identité du disciple tijani est sa chaîne de transmission
(silsila) : le moqaddam qui lui a personnellement transmis le Wird, à une date donnée.
Cette filiation, aujourd'hui connue de manière informelle, est un repère naturel autour
duquel les disciples peuvent se reconnaître dans l'application.

## Vision

Faire d'At-Tijaniya le compagnon numérique de référence du disciple tijani, où qu'il se
trouve dans le monde : réciter ses wirds correctement, se connecter aux khadara, apprendre
l'histoire et les enseignements de la tarikha, rester en lien avec la communauté — y compris
les disciples de la même lignée de transmission.

## Valeurs directrices

- **Fidélité et rigueur** : aucun contenu religieux publié sans compilation sérieuse et
  validation par des moqaddamines ou érudits reconnus.
- **Sobriété** : identité visuelle et UX qui inspirent le recueillement.
- **Accessibilité** : application gratuite dès le départ.
- **Ouverture communautaire** : relier les disciples entre eux, au-delà des frontières.
- **Respect de la vie privée** : les informations spirituelles/personnelles (silsila,
  moqaddam, zawiya) ne sont jamais exposées sans consentement explicite du disciple.

## Objectifs

**Fonctionnels**
- Réciter les trois wirds avec accompagnement texte + audio fidèle.
- Tasbih digital multi-modes.
- Calendrier des khadara géolocalisé, diffusion en direct ou différée.
- Base de connaissances fiable sur les figures et familles religieuses.
- Espace communautaire (fil d'actualité, groupes, messagerie).
- Retrouver d'autres disciples du même moqaddam, dans le respect de la vie privée.

**Stratégiques**
- V1 gratuite pour maximiser l'adoption.
- Modèle économique pérenne (dons puis premium) sans dénaturer la vocation spirituelle.
- Légitimité religieuse/communautaire via la validation du contenu.

## Personas

1. **Le disciple pratiquant assidu** — récite quotidiennement, veut un outil fiable pour
   ne rien oublier et garder son historique.
2. **Le nouveau disciple / curieux** — cherche à apprendre biographies, sens des wirds,
   repères historiques.
3. **Le disciple de la diaspora** — loin des zawiyas historiques, dépend des directs et
   du calendrier géolocalisé pour rester connecté.
4. **Le responsable ou animateur de zawiya** — anime des cercles localement, diffuse en
   direct, publie les ziyaras.
5. **Le disciple attaché à sa lignée spirituelle** — connaît son moqaddam et l'année de
   transmission, veut retrouver d'autres disciples de la même lignée sans exposition
   publique de cette information.
6. **Le mouqaddam** — transmet lui-même le Wird, veut faire reconnaître son statut de
   manière vérifiée (pas une simple déclaration) et renseigner sa silsila d'ijaza, sans
   que cette information devienne publique par défaut.
