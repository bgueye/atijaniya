# Écran "À propos" — texte exact

> Destiné à l'écran "À propos" (Paramètres généraux, cf.
> `03-architecture-ecrans.md`). Ce texte fait foi mot pour mot — ne pas le
> paraphraser lors de l'implémentation. Statut éditorial : validé par le
> porteur de projet le 2026-08-29 et implémenté (FR + AR) dans
> `lib/features/settings/presentation/about_screen.dart`.

---

## À propos d'At-Tijaniya

At-Tijaniya (التجانية) est un outil communautaire indépendant, conçu par
et pour les disciples de la Tijaniyya : pratique quotidienne des wirds,
suivi des khadara, découverte des figures et des foyers de la tarîqa, et
mise en lien entre disciples.

### Une application indépendante, pas une autorité religieuse

At-Tijaniya n'est affiliée à aucun Khalifat général, foyer ou zawiya en
particulier. Elle ne représente ni ne parle au nom d'aucune autorité de la
Tijaniyya.

Le contenu religieux présenté dans l'application (wirds, biographies,
enseignements) est compilé à partir de sources reconnues, puis relu par
des moqaddamines référents avant publication. Cette relecture est un
travail de vérification éditoriale — elle ne constitue pas une déclaration
d'autorité doctrinale, et ne se substitue à aucun enseignement reçu
directement d'un moqaddam.

### Le statut "Parrainage confirmé"

Le badge affiché sur certains profils atteste qu'un parrainage a été
confirmé entre deux utilisateurs de l'application, selon un mécanisme
propre à At-Tijaniya. **Ce n'est pas une reconnaissance ou une
habilitation religieuse officielle.** Il ne remplace, ne confirme, ni ne
contredit la légitimité qu'un moqaddam tient de sa propre chaîne de
transmission (silsila) dans la réalité.

### Neutralité entre foyers

At-Tijaniya présente à égalité les différents foyers de la tarîqa
(Tivaouane, Kaolack, Médina Baye, et d'autres) sans privilégier ni
représenter davantage l'un par rapport aux autres.

### Contact

Pour toute question ou tout signalement d'une erreur de contenu, contactez
bgueye@gmail.com.

---

## Notes d'implémentation

- Écran accessible depuis Paramètres généraux → "À propos" (déjà listé
  dans l'inventaire des écrans, section transverses).
- Ce texte doit rester visible en permanence, pas seulement au premier
  lancement — ce n'est pas un contenu d'onboarding qu'on ne voit qu'une
  fois.
- Le paragraphe "Le statut Parrainage confirmé" doit être cohérent mot
  pour mot avec l'info-bulle du badge (voir `CLAUDE.md`, section
  "Libellé UI du badge").
- Prévoir la version arabe (RTL) dès la première implémentation, comme
  pour tout écran de l'app.
