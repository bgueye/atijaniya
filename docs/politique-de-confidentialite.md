# Politique de confidentialité — At-Tijaniya

Dernière mise à jour : 24 août 2026.

## 1. Qui sommes-nous

At-Tijaniya est une application indépendante destinée aux disciples de la Tijaniyya,
portée par Boubacar Gueye, à titre individuel — pas une société, pas une association
constituée à ce jour. Contact : voir §10.

## 2. Données que nous collectons

### Compte et profil
- E-mail et mot de passe (le mot de passe est haché par notre prestataire
  d'authentification, jamais stocké ni lisible en clair par nous).
- Nom affiché, photo de profil (optionnelle), langue préférée (français/arabe), bio,
  zawiya de rattachement.

### Pratique religieuse
- La progression des wirds (compteur, historique, rappels programmés) est stockée
  **localement sur votre appareil**, pas sur nos serveurs.
- Si vous validez une récitation audio en tant qu'administrateur, cette action est
  journalisée.

### Lignée spirituelle et statut mouqaddam — données sensibles
Ces informations bénéficient d'une protection renforcée, décrite dans nos règles de
développement internes (`CLAUDE.md` du projet) :
- **Lignée spirituelle** : foyer, nom du moqaddam ayant transmis le Wird, année, zawiya.
  Privée par défaut. Ne sert à la mise en relation avec d'autres disciples que si vous
  l'activez explicitement (opt-in). Jamais affichée dans un annuaire public, jamais
  incluse dans un export ou une API publique.
- **Statut « Mouqaddam vérifié »** et silsila d'ijaza (chaîne de parrainage) : privés par
  défaut, avec un réglage opt-in distinct pour apparaître comme parrain disponible.
- Toute consultation de ces champs sensibles par un autre mouqaddam (dans le cadre d'un
  parrainage) est journalisée à des fins d'audit.

### Contenu communautaire
Publications du fil d'actualité, commentaires, likes, messages privés, groupes et leurs
membres — visibles selon les réglages de confidentialité du groupe/de la conversation
concernée.

### Dons
Montant, devise et statut de la transaction. **Nous ne recevons ni ne stockons vos
coordonnées bancaires ou de paiement mobile** : le paiement lui-même est traité par notre
prestataire PayDunya. Un don peut être fait de façon anonyme, sans compte.

### Notifications
Si vous activez les notifications, le jeton technique de votre appareil est conservé pour
vous les envoyer (aucune donnée personnelle supplémentaire n'y est associée).

### Ce que nous ne collectons pas
Aucun outil d'analyse d'usage ou de publicité tiers (pas de SDK publicitaire, pas de
traceur marketing). Aucune géolocalisation.

## 3. Pourquoi nous utilisons ces données

- Fournir les fonctionnalités de l'application (compte, pratique des wirds, communauté,
  dons).
- Vous permettre, si vous le souhaitez, de retrouver des condisciples de votre moqaddam.
- Assurer la sécurité du service et prévenir les abus (modération a posteriori des
  contenus signalés).
- Vous contacter au sujet de votre compte si nécessaire.

## 4. Avec qui nous les partageons

- **Supabase** (hébergement de la base de données, de l'authentification et du stockage),
  hébergé dans l'Union européenne (région Paris, France).
- **PayDunya** (traitement des paiements pour les dons), uniquement pour les données
  nécessaires à la transaction.
- Nous ne vendons ni ne louons vos données à des tiers, et ne les partageons à des fins
  publicitaires.

## 5. Sécurité

L'accès aux données est restreint au niveau de la base de données elle-même (Row-Level
Security PostgreSQL) : un disciple ne peut techniquement accéder qu'aux données que les
règles de confidentialité de l'app autorisent, pas seulement au niveau de
l'interface. Les échanges entre l'application et nos serveurs sont chiffrés (HTTPS).

## 6. Conservation et suppression

Vos données sont conservées tant que votre compte existe. Vous pouvez supprimer votre
compte à tout moment depuis Profil → Supprimer mon compte. Cette suppression est
définitive et immédiate :
- Votre contenu personnel (commentaires, messages privés, publications de groupe) est
  supprimé.
- Le contenu à portée collective que vous avez créé (évènement, rediffusion, publication
  du fil communautaire) est conservé mais anonymisé — votre nom n'y reste plus associé.
- Le reste (profil, lignée spirituelle, statut mouqaddam, historique de pratique,
  notifications...) est supprimé.

## 7. Vos droits

Vous pouvez à tout moment, directement dans l'application : consulter et modifier votre
profil, changer la visibilité de votre lignée spirituelle et de votre statut mouqaddam
(Paramètres → Confidentialité), et supprimer votre compte. Pour toute autre demande
(export de vos données, question sur cette politique), contactez-nous (§10).

## 8. Mineurs

At-Tijaniya n'est pas spécifiquement destinée aux enfants et ne collecte pas
volontairement de données concernant des mineurs sans l'accord d'un parent ou tuteur.

## 9. Modifications de cette politique

Nous pouvons mettre à jour cette politique, par exemple à l'ajout d'une nouvelle
fonctionnalité. La date de dernière mise à jour en haut de page reflète toujours la
version en vigueur.

## 10. Contact

Pour toute question sur vos données ou cette politique : **bgueye@gmail.com**.
