// At-Tijaniya — contenu validé du module Wirds.
//
// Source : document "At-Tijaniya — Module Wirds" (validé par un moqaddam
// référent du projet, confirmé le [à horodater par le porteur de projet]),
// complété par la "forme complète et parfaite" de chaque wird décrite dans
// docs/Lazim-Etapes-Detaillees.md, docs/Wazifa-Etapes-Detaillees.md et
// docs/Hadratou-l-Jouma-Etapes-Detaillees.md (validés par le porteur de
// projet le 2026-08-12 — intention d'ouverture, Fatiha et versets de
// clôture, jusque-là seulement illustratifs, sont désormais de vrais
// piliers comptés dans le Tasbih). Cf. docs/01-perimetre-fonctionnel.md
// § 5.1 et § 8, et CLAUDE.md.
//
// RÈGLE IMPÉRATIVE : ce fichier est la SEULE source de texte de wird dans
// l'app. Ne jamais ajouter/modifier une formule ici sans qu'elle provienne
// d'une nouvelle version explicitement marquée "validée" du document source.
//
// Nombre de répétitions de Hadratou-l-Jouma (pilier Tahlil) : fixé à 1600
// conformément à docs/01-perimetre-fonctionnel.md § 5.1 (le document source
// mentionnait 1000/1200/1600 "à confirmer selon l'usage du foyer", et la
// mise à jour du document via tidjaniya.com indique 1200 — 1600 reste la
// valeur explicitement retenue par le porteur de projet, décision reconfirmée
// à deux reprises malgré cette nouvelle source).
//
// Pilier "Nom Allah" de Hadratou-l-Jouma : cible fixe de 600 répétitions.
// Aucun document source ne donne de chiffre pour cette phase (elle n'y est
// décrite que par durée, "jusqu'à l'approche du Maghreb") — 600 est une
// décision produit assumée par le porteur de projet, au lieu d'une mécanique
// de compteur par durée : l'app n'a et n'aura pas de calcul d'horaire de
// prière en V1 (même choix que pour les rappels, voir wird_reminder_slots.dart).
//
// Translittération : les textes nouvellement ajoutés (intention, Fatiha,
// versets de clôture, sourcés sur tidjaniya.com) ont été normalisés sans
// accents/apostrophes de style académique, pour rester cohérents avec la
// translittération déjà utilisée dans ce fichier (ex. "Astaghfirullah",
// "La ilaha illAllah").

import '../domain/wird_models.dart';

const _salatoulFatihiArabic =
    'اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ الْفَاتِحِ لِمَا أُغْلِقَ، وَالْخَاتِمِ لِمَا سَبَقَ، '
    'نَاصِرِ الْحَقِّ بِالْحَقِّ، وَالْهَادِي إِلَى صِرَاطِكَ الْمُسْتَقِيمِ، وَعَلَى آلِهِ حَقَّ قَدْرِهِ '
    'وَمِقْدَارِهِ الْعَظِيمِ';

const _salatoulFatihiTranslit =
    "Allahoumma salli 'ala sayyidina Mouhammadin-il-Fatihi lima oughliqa, "
    "wal-Khatimi lima sabaqa, Nasiril-Haqqi bil-Haqqi, wal-Hadi ila "
    "Siratika-l-Moustaqim, wa 'ala alihi haqqa qadrihi wa miqdarihi-l-'Adhim";

const _salatoulFatihiTranslation =
    "Ô Allah, prie sur notre maître Muhammad l'Ouvreur de ce qui était "
    "fermé, le Sceau de ce qui a précédé, celui qui secourt la vérité par "
    "la vérité, celui qui guide vers Ta voie droite, et sur sa famille, à "
    "la mesure de sa valeur et de son immense grandeur.";

// Istighfar long (utilisé par la Wazifa et par la Hadratou-l-Jouma, qui
// partagent le même texte selon docs/Hadratou-l-Jouma-Etapes-Detaillees.md).
const _istighfarLongArabic =
    'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ';
const _istighfarLongTranslit =
    "Astaghfirullah al-'Adhim alladhi la ilaha illa Houwa-l-Hayyou-l-Qayyoum";
const _istighfarLongTranslation =
    "Je demande pardon à Allah, l'Immense, il n'y a de divinité que "
    "Lui, le Vivant, le Subsistant par Lui-même.";

// Versets de clôture réutilisés après plusieurs piliers, selon les 3
// documents "Étapes Détaillées" (confirmés par tidjaniya.com).
const _saffatClosingArabic =
    'سُبْحَانَ رَبِّكَ رَبِّ الْعِزَّةِ عَمَّا يَصِفُونَ وَسَلَامٌ عَلَى الْمُرْسَلِينَ وَالْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ';
const _saffatClosingTranslit =
    "Soubhana rabbika rabbi-l-'izzati 'amma yasifouna wa salamoun "
    "'ala-l-moursalina wa-l-hamdou li-Llahi rabbi-l-'alamin.";

const _ahzabClosingArabic =
    'إِنَّ اللَّهَ وَمَلَائِكَتَهُ يُصَلُّونَ عَلَى النَّبِيِّ يَا أَيُّهَا الَّذِينَ آمَنُوا صَلُّوا عَلَيْهِ وَسَلِّمُوا تَسْلِيمًا';
const _ahzabClosingTranslit =
    "Innallaha wa mala-ikatahou yousalouna 'ala-n-Nabiyyi ya ayyouha-l-"
    "ladhina amanou sallou 'alayhi wa sallimou tasliman.";

// Intention d'ouverture (niyya) — identique pour les 3 wirds. Texte arabe
// complet sourcé sur tidjaniya.com (« Aoraad Tariqa Tijaniyya »).
const _intentionPillar = WirdPillar(
  arabic:
      'اللَّهُمَّ إِنِّي نَوَيْتُ تِلَاوَةَ هَذَا الْوِرْدِ تَعْظِيمًا وَإِجْلَالًا لَكَ '
      'وَابْتِغَاءَ مَرْضَاتِكَ وَقَصْدًا لِوَجْهِكَ الْكَرِيمِ، مُخْلِصًا لَكَ مِنْ أَجْلِكَ '
      'وَأَقُولُ بِإِمْدَادِكَ وَعَوْنِكَ وَحَوْلِكَ وَقُوَّتِكَ، وَمَا وَهَبْتَنِي مِنْ '
      'إِنْعَامِكَ وَتَوْفِيقِكَ مُسْتَعِينًا بِكَ',
  transliteration:
      "Allahoumma inni nawaytou tilawata hadha-l-wirdi ta'dhiman wa "
      "ijlalan laka wa btighaa mardatika wa qasdan li wajhika-l-karim, "
      "moukhlisan laka min ajlika wa aqoulou bi imdadika wa awnika wa "
      "hawlika wa qouwwatika, wa ma wahhabtani min in'amika wa tawfiqika "
      "mousta'inan bika.",
  translation:
      "Ô Allah, j'ai mis l'intention au travers de ce wird de proclamer "
      "Ton incommensurabilité et Ta magnificence, souhaitant par cela "
      "obtenir Ta satisfaction et ne recherchant que Ta noble Face ; en "
      "toute sincérité envers Toi et par Ta cause, reconnaissant Ton "
      "afflux, Ton aide, Ta capacité et Ta puissance, ainsi que ce dont "
      "Tu m'as gratifié comme bienfaits et comme réussite, en implorant "
      "Ton secours.",
  repetitions: 1,
  note: 'Source : tidjaniya.com (« Aoraad Tariqa Tijaniyya »).',
);

// Fatiha — texte coranique standard (universel, hors périmètre de la règle
// de validation propre au contenu de la Tariqa), identique pour les 3 wirds.
const _fatihaParagraphs = [
  WirdParagraph(
    arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
    transliteration: 'Bismi-Llahi r-Rahmani r-Rahim',
    translation:
        "Au nom d'Allah, le Tout Miséricordieux, le Très Miséricordieux.",
  ),
  WirdParagraph(
    arabic: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
    transliteration: "Al-hamdou li-Llahi rabbi-l-'alamin",
    translation: 'Louange à Allah, Seigneur des mondes.',
  ),
  WirdParagraph(
    arabic: 'الرَّحْمَٰنِ الرَّحِيمِ',
    transliteration: 'Ar-Rahmani r-Rahim',
    translation: 'Le Tout Miséricordieux, le Très Miséricordieux.',
  ),
  WirdParagraph(
    arabic: 'مَالِكِ يَوْمِ الدِّينِ',
    transliteration: 'Maliki yawmi-d-din',
    translation: 'Maître du Jour de la rétribution.',
  ),
  WirdParagraph(
    arabic: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
    transliteration: "Iyyaka na'boudou wa iyyaka nasta'in",
    translation:
        "C'est Toi seul que nous adorons, et c'est Toi seul dont nous "
        "implorons secours.",
  ),
  WirdParagraph(
    arabic: 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
    transliteration: 'Ihdina-s-sirata-l-moustaqim',
    translation: 'Guide-nous dans le droit chemin.',
  ),
  WirdParagraph(
    arabic:
        'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
    transliteration:
        "Sirata-l-ladhina an'amta 'alayhim ghayri-l-maghdoubi 'alayhim "
        "wa la-d-dallin",
    translation:
        'Le chemin de ceux que Tu as comblés de faveurs, non pas de ceux '
        'qui ont encouru Ta colère, ni des égarés.',
  ),
];

const _fatihaPillar = WirdPillar(
  arabic: 'سُورَةُ الْفَاتِحَةِ',
  transliteration: 'Al-Fatiha',
  translation: "L'Ouverture",
  repetitions: 1,
  note:
      "Précédée du ta'awwudh (A'oudhou bi-Llahi mina ch-Chaytani r-Rajim) "
      "et de la basmala, clôturée par « Amine ».",
  fullText: _fatihaParagraphs,
);

const lazim = Wird(
  id: 'lazim',
  nameArabic: 'اللازم',
  nameFrench: 'Lazim',
  frequency: WirdFrequency.daily,
  conditionsNote:
      'Oraison quotidienne obligatoire, matin et soir, sans exception. '
      'Les formules ci-dessous doivent être récitées dans cet ordre.',
  pillars: [
    _intentionPillar,
    _fatihaPillar,
    WirdPillar(
      arabic: 'أَسْتَغْفِرُ اللَّهَ',
      transliteration: 'Astaghfirullah',
      translation: 'Je demande pardon à Allah.',
      repetitions: 100,
      closingFormulas: [
        WirdClosingFormula(
          intro: 'Clôture après la 100ᵉ récitation (Sourate As-Saffat, 37:180-182) :',
          arabic: _saffatClosingArabic,
          transliteration: _saffatClosingTranslit,
        ),
      ],
    ),
    WirdPillar(
      arabic: _salatoulFatihiArabic,
      transliteration: _salatoulFatihiTranslit,
      translation: _salatoulFatihiTranslation,
      repetitions: 100,
      note:
          'Salatoul Fatihi — propre à la Tariqa Tijaniyya, ne doit pas être '
          'remplacée par une autre salat pendant le Lazim.',
      closingFormulas: [
        WirdClosingFormula(
          intro: 'Clôture après la 100ᵉ récitation (Sourate As-Saffat, 37:180-182) :',
          arabic: _saffatClosingArabic,
          transliteration: _saffatClosingTranslit,
        ),
      ],
    ),
    WirdPillar(
      arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illAllah',
      translation: "Il n'y a de divinité qu'Allah.",
      repetitions: 100,
      closingFormulas: [
        WirdClosingFormula(
          intro: 'Après la 100ᵉ récitation, ajouter une fois :',
          arabic: 'مُحَمَّدٌ رَسُولُ اللَّهِ عَلَيْهِ سَلَامُ اللَّهِ',
          transliteration: "Muhammadun Rasoulullah, 'alayhi Salamoullah.",
        ),
        WirdClosingFormula(
          intro: 'Puis (Sourate Al-Ahzab, 33:56) :',
          arabic: _ahzabClosingArabic,
          transliteration: _ahzabClosingTranslit,
        ),
        WirdClosingFormula(
          intro: 'Puis, en clôture finale (Sourate As-Saffat, 37:180-182) :',
          arabic: _saffatClosingArabic,
          transliteration: _saffatClosingTranslit,
        ),
      ],
    ),
  ],
);

const _jawharatoulKamalParagraphs = [
  WirdParagraph(
    arabic:
        'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى عَيْنِ الرَّحْمَةِ الرَّبَّانِيَّةِ وَالْيَاقُوتَةِ الْمُتَحَقِّقَةِ الْحَائِطَةِ '
        'بِمَرْكَزِ الْفُهُومِ وَالْمَعَانِي ❁ وَنُورِ الْأَكْوَانِ الْمُتَكَوِّنَةِ الْآدَمِي صَاحِبِ الْحَقِّ الرَّبَّانِي ❁ '
        'الْبَرْقِ الْأَسْطَعِ بِمُزُونِ الْأَرْبَاحِ الْمَالِئَةِ لِكُلِّ مُتَعَرِّضٍ مِنَ الْبُحُورِ وَالْأَوَانِي ❁ '
        'وَنُورِكَ اللَّامِعِ الَّذِي مَلَأْتَ بِهِ كَوْنَكَ الْحَائِطِ بِأَمْكِنَةِ الْمَكَانِي',
    transliteration:
        "Allahoumma salli wa sallim 'ala 'ayni-r-rahmati-r-rabbaniyyati "
        "wa-l-yaqoutati-l-moutahaqqiqati-l-ha'itati bi markazi-l-fouhoumi "
        "wa-l-ma'ani, wa nouri-l-akwani-l-moutakawwinati-l-adami "
        "sahibi-l-haqqi-r-rabbani, al-barqi-l-astha'i bi "
        "mouzouni-l-arbahi-l-mali'ati li koulli mouta'arridin mina-l-bouhouri "
        "wa-l-awani, wa nourika-l-lami'i-lladhi mala'ta bihi kawnaka-l-ha'iti "
        "bi amkinati-l-makani.",
    translation:
        "Ô Allah, prie et salue la source de la miséricorde divine, le "
        "rubis authentique qui embrasse le centre des compréhensions et des "
        "sens, la lumière des univers créés, l'Adamique détenteur de la "
        "vérité divine, l'éclair le plus brillant dans les nuées "
        "bienfaisantes qui emplissent toute mer et tout réceptacle prêts à "
        "le recevoir, et Ta lumière rayonnante dont Tu as rempli Ton "
        "univers, embrassant tous les lieux de l'espace.",
  ),
  WirdParagraph(
    arabic:
        'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى عَيْنِ الْحَقِّ الَّتِي تَتَجَلَّى مِنْهَا عُرُوشُ الْحَقَائِقِ عَيْنِ الْمَعَارِفِ '
        'الْأَقْوَمِ صِرَاطِكَ التَّامِّ الْأَسْقَمِ',
    transliteration:
        "Allahoumma salli wa sallim 'ala 'ayni-l-haqqi-llati tatajalla minha "
        "'ouroushou-l-haqa'iqi 'ayni-l-ma'arifi-l-aqwami "
        "siratika-t-tammi-l-asqam.",
    translation:
        "Ô Allah, prie et salue la source de la vérité d'où se "
        "manifestent les trônes des réalités, la source des connaissances "
        "les plus droites, Ta voie complète et la plus droite.",
  ),
  WirdParagraph(
    arabic:
        'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى طَلْعَةِ الْحَقِّ بِالْحَقِّ الْكَنْزِ الْأَعْظَمِ إِفَاضَتِكَ مِنْكَ إِلَيْكَ '
        'إِحَاطَةِ النُّورِ الْمُطَلْسَمِ ❁ صَلَّى اللَّهُ عَلَيْهِ وَعَلَى آلِهِ صَلَاةً تُعَرِّفُنَا بِهَا إِيَّاهُ',
    transliteration:
        "Allahoumma salli wa sallim 'ala tal'ati-l-haqqi "
        "bi-l-haqqi-l-kanzi-l-a'dhami ifadatika minka ilayka "
        "ihatati-n-nouri-l-moutalsami, salla-llahou 'alayhi wa 'ala alihi "
        "salatan tu'arrifouna biha iyyah.",
    translation:
        "Ô Allah, prie et salue la manifestation de la Vérité par la "
        "Vérité, le plus grand trésor, Ton épanchement de Toi vers Toi, "
        "l'enveloppement de la lumière mystérieuse. Qu'Allah prie sur lui "
        "et sur sa famille, d'une prière par laquelle Tu nous fasses "
        "vraiment le connaître.",
  ),
];

const wazifa = Wird(
  id: 'wazifa',
  nameArabic: 'الوظيفة',
  nameFrench: 'Wazifa',
  frequency: WirdFrequency.daily,
  conditionsNote:
      "À réciter au moins une fois par jour (deux fois de préférence), en "
      "assemblée si possible. Durant la Wazifa, aucune autre prière sur le "
      "Prophète que Salatoul Fatihi et Jawharatoul Kamal ne doit être "
      "intercalée, sous peine d'invalider l'oraison.",
  pillars: [
    _intentionPillar,
    _fatihaPillar,
    WirdPillar(
      arabic: _istighfarLongArabic,
      transliteration: _istighfarLongTranslit,
      translation: _istighfarLongTranslation,
      repetitions: 30,
    ),
    WirdPillar(
      arabic: _salatoulFatihiArabic,
      transliteration: _salatoulFatihiTranslit,
      translation: _salatoulFatihiTranslation,
      repetitions: 50,
      note:
          'Salatoul Fatihi — propre à la Tariqa Tijaniyya, ne doit pas être '
          'remplacée par une autre salat pendant le Lazim ou la Wazifa.',
      closingFormulas: [
        WirdClosingFormula(
          intro: 'Clôture après la 50ᵉ récitation (Sourate As-Saffat, 37:180-182) :',
          arabic: _saffatClosingArabic,
          transliteration: _saffatClosingTranslit,
        ),
      ],
    ),
    WirdPillar(
      arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illAllah',
      translation: "Il n'y a de divinité qu'Allah.",
      repetitions: 100,
      closingFormulas: [
        WirdClosingFormula(
          intro: 'Après la 100ᵉ récitation, ajouter :',
          arabic: 'مُحَمَّدٌ رَسُولُ اللَّهِ عَلَيْهِ سَلَامُ اللَّهِ',
          // Pas de translittération fournie pour cette formule précise
          // dans le document source (contrairement à la même formule dans
          // le Lazim) — voir la note sur WirdClosingFormula.transliteration.
        ),
      ],
    ),
    WirdPillar(
      arabic: 'جَوْهَرَةُ الْكَمَالِ',
      transliteration: 'Jawharatoul Kamal',
      translation: '« La Perle de la Perfection » — prière spéciale sur le Prophète ﷺ.',
      repetitions: 12,
      note: "Si les conditions ne sont pas réunies, remplacer par 20 récitations supplémentaires de Salatoul Fatihi.",
      closingFormulas: [
        WirdClosingFormula(
          intro: 'Clôture après la 12ᵉ récitation (Sourate Al-Ahzab, 33:56) :',
          arabic: _ahzabClosingArabic,
          transliteration: _ahzabClosingTranslit,
        ),
      ],
      conditions: [
        "Être en état d'ablution à l'eau (le tayammoum ne suffit pas).",
        "Se trouver dans un lieu propre, suffisamment large pour six personnes.",
        "La réciter assis, jamais monté (véhicule) ou en bateau.",
        "Porter des vêtements propres.",
      ],
      fullText: _jawharatoulKamalParagraphs,
    ),
  ],
);

const hadratouJouma = Wird(
  id: 'hadratou_jouma',
  nameArabic: 'حضرة الجمعة',
  nameFrench: 'Hadratou-l-Jouma',
  frequency: WirdFrequency.weekly,
  repetitionsNote:
      '1600 répétitions du tahlil (valeur retenue pour le projet), puis 600 '
      'répétitions du Nom Allah.',
  conditionsNote:
      "Dhikr collectif hebdomadaire, uniquement le vendredi entre l'Asr et "
      "le Maghreb. Aucun rattrapage possible en cas de créneau manqué.",
  pillars: [
    _intentionPillar,
    _fatihaPillar,
    WirdPillar(
      arabic: _istighfarLongArabic,
      transliteration: _istighfarLongTranslit,
      translation: _istighfarLongTranslation,
      repetitions: 3,
    ),
    WirdPillar(
      arabic: _salatoulFatihiArabic,
      transliteration: _salatoulFatihiTranslit,
      translation: _salatoulFatihiTranslation,
      repetitions: 3,
      closingFormulas: [
        WirdClosingFormula(
          intro: 'Clôture après la 3ᵉ récitation (Sourate Al-Ahzab, 33:56) :',
          arabic: _ahzabClosingArabic,
          transliteration: _ahzabClosingTranslit,
        ),
      ],
    ),
    WirdPillar(
      arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illAllah',
      translation: "Il n'y a de divinité qu'Allah.",
      repetitions: 1600,
      closingFormulas: [
        WirdClosingFormula(
          intro: 'Après la dernière récitation, ajouter une fois :',
          arabic: 'سَيِّدُنَا مُحَمَّدٌ رَسُولُ اللَّهِ عَلَيْهِ سَلَامُ اللَّهِ',
          transliteration: "Seyidouna Muhammadoun Rasoulullah, 'alayhi Salamoullah.",
        ),
      ],
    ),
    WirdPillar(
      arabic: 'اللَّهُ',
      transliteration: 'Allah',
      translation: '« Allah » — récitation répétée du Nom suprême.',
      repetitions: 600,
      note:
          "Récitation répétée du Nom suprême, jusqu'à l'approche du "
          "Maghreb — cible de 600 répétitions retenue par le porteur de "
          "projet (l'app ne calcule pas les horaires de prière en V1). La "
          "forme complète prévoit ensuite une clôture non comptée comme "
          "pilier séparé : reprise de la Fatiha (ta'awwudh, basmala), puis "
          "3 fois Salatoul Fatihi.",
      closingFormulas: [
        WirdClosingFormula(
          intro: 'Conclue par (Sourate Al-Ahzab, 33:56) :',
          arabic: _ahzabClosingArabic,
          transliteration: _ahzabClosingTranslit,
        ),
      ],
    ),
  ],
);

const validatedWirds = [lazim, wazifa, hadratouJouma];
