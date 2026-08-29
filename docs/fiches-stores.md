# Fiches Google Play / App Store — brouillon (Sprint 6)

À relire et ajuster avant soumission. Compteurs de caractères indiqués pour respecter les
limites de chaque store ; recompter après toute modification.

## Informations communes

- **Nom de l'app** : At-Tijaniya
- **Catégorie suggérée** : Style de vie (Lifestyle) — alternative : Livres et références,
  selon ce qui est disponible dans chaque console.
- **Public** : tout public. Aucun contenu violent, aucun contenu généré par les
  utilisateurs non modéré (modération a posteriori en place, voir
  `docs/09-journal-implementation-frontend.md` § Sprint 2).
- **Gratuite**, financée par les dons — aucun achat intégré, aucune publicité.
- **URL de la politique de confidentialité** : https://claude.ai/code/artifact/f0eed457-0f53-4cb8-9e94-52604f6fe7ac
  (Artifact publié le 2026-08-29, contenu identique à `docs/politique-de-confidentialite.md`
  — **privé par défaut, à partager en public depuis le menu de partage de la page avant
  toute soumission aux stores**, sans quoi le lien n'est accessible qu'au porteur de projet).

---

## Français

### Nom (30 caractères max)
```
At-Tijaniya
```
(11 caractères)

### Sous-titre App Store (30 caractères max)
```
Wirds, Khadara & communauté
```
(28 caractères)

### Description courte Google Play (80 caractères max)
```
Wirds, figures et communauté de la Tariqa Tijaniyya — gratuite, FR/AR.
```
(72 caractères)

### Description complète (Google Play : 4000 caractères max, App Store : 4000)
```
At-Tijaniya accompagne les disciples de la Tariqa Tijaniyya dans leur pratique
quotidienne et leur vie communautaire — en français et en arabe, gratuitement.

WIRDS
Lazim, Wazifa et Hadratou-l-Jouma : texte arabe, translittération, traduction et lecture
audio synchronisée. Un tasbih digital (tape manuelle ou reconnaissance vocale) suit votre
progression pilier par pilier, avec historique et rappels programmés.

KHADARA
Calendrier des évènements et zawiyas, diffusions en direct et rediffusions.

FIGURES
Biographies des fondateurs et grandes familles religieuses de la Tariqa, silsila
historique, citations.

COMMUNAUTÉ
Retrouvez les disciples de votre moqaddam, échangez au sein de groupes rattachés à votre
zawiya, suivez le fil d'actualité communautaire.

LIGNÉE SPIRITUELLE, EN TOUTE CONFIDENTIALITÉ
Votre lignée spirituelle et votre statut de mouqaddam restent privés par défaut. Vous
choisissez si et comment ils sont utilisés pour vous mettre en relation avec d'autres
disciples — jamais d'annuaire public.

BILINGUE DÈS LE PREMIER LANCEMENT
Interface et contenu religieux disponibles en français et en arabe (avec prise en charge
RTL complète).

At-Tijaniya reste gratuite grâce aux dons de la communauté.
```

### Mots-clés App Store (100 caractères max, séparés par virgules, sans espaces)
```
tijaniyya,tijani,wird,wazifa,lazim,hadratou,khadara,zawiya,mouqaddam,islam,soufi,dhikr
```
(à recompter — proche de la limite)

### Notes de version (exemple pour la première publication)
```
Première publication d'At-Tijaniya. Wirds (Lazim, Wazifa, Hadratou-l-Jouma), Khadara,
Figures, Communauté et lignée spirituelle — en français et en arabe.
```

---

## العربية (Arabe)

### الاسم
```
التجانية
```

### العنوان الفرعي (App Store)
```
الأوراد والحضرة والجماعة
```

### الوصف المختصر (Google Play)
```
الأوراد وأعلام الطريقة التجانية ومجتمعها — مجانًا، بالفرنسية والعربية.
```

### الوصف الكامل
```
يرافق تطبيق التجانية أتباع الطريقة التجانية في وردهم اليومي وحياتهم الجماعية — بالفرنسية
والعربية، ومجانًا بالكامل.

الأوراد
اللازم والوظيفة وحضرة الجمعة: النص العربي والترجمة الصوتية والترجمة المكتوبة، مع تلاوة
صوتية متزامنة. سبحة رقمية (بالنقر أو بالتعرف الصوتي) تتابع تقدمكم ركنًا بعد ركن، مع سجل
وتذكيرات مبرمجة.

الحضرة
تقويم المناسبات والزوايا، بث مباشر وإعادة بث.

الأعلام
سير مؤسسي الطريقة والعائلات الدينية الكبرى، السلسلة التاريخية، والأقوال المأثورة.

الجماعة
تواصلوا مع إخوانكم في مقدّمكم، تبادلوا داخل مجموعات مرتبطة بزاويتكم، وتابعوا أخبار
الجماعة.

سلسلتكم الروحية، بسرية تامة
تبقى سلسلتكم الروحية وصفتكم كمقدّم خاصة افتراضيًا. أنتم من يقرر كيفية استخدامها للتواصل مع
إخوان آخرين — لا دليل عام أبدًا.

ثنائي اللغة منذ الإطلاق
الواجهة والمحتوى الديني متوفران بالفرنسية والعربية، مع دعم كامل للكتابة من اليمين إلى
اليسار.

يبقى تطبيق التجانية مجانيًا بفضل تبرعات الجماعة.
```

---

## Ce qui manque encore pour soumettre

- Confirmer l'adresse de contact de la politique de confidentialité et son URL finale
  (actuellement un artifact Claude — envisager un hébergement pérenne type GitHub Pages,
  voir la conversation).
- Comptes développeur Google Play (25 $ à vie) et Apple Developer Program (99 $/an) — pas
  encore mentionnés dans ce projet, à ouvrir par le porteur de projet.
- Captures d'écran (voir dossier généré séparément pour Android/Google Play — les
  captures App Store nécessitent un simulateur iOS, indisponible dans cet environnement
  Windows).
- Icône d'app haute résolution (1024×1024 pour les deux stores) — `assets/branding/`
  contient la rosace mais pas encore d'icône finalisée aux formats requis.
