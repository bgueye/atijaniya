// At-Tijaniya — contenu validé du module Wirds.
//
// Source : document "At-Tijaniya — Module Wirds" (validé par un moqaddam
// référent du projet, confirmé le [à horodater par le porteur de projet]).
// Cf. docs/01-perimetre-fonctionnel.md § 5.1 et § 8, et CLAUDE.md.
//
// RÈGLE IMPÉRATIVE : ce fichier est la SEULE source de texte de wird dans
// l'app. Ne jamais ajouter/modifier une formule ici sans qu'elle provienne
// d'une nouvelle version explicitement marquée "validée" du document source.
//
// Nombre de répétitions de Hadratou-l-Jouma : fixé à 1600 conformément à
// docs/01-perimetre-fonctionnel.md § 5.1 (le document source mentionnait
// 1000/1200/1600 "à confirmer selon l'usage du foyer" — 1600 est la valeur
// retenue par le porteur de projet).

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

const lazim = Wird(
  id: 'lazim',
  nameArabic: 'اللازم',
  nameFrench: 'Lazim',
  frequency: WirdFrequency.daily,
  conditionsNote:
      'Oraison quotidienne obligatoire, matin et soir, sans exception. '
      'Les trois formules ci-dessous doivent être récitées dans cet ordre.',
  pillars: [
    WirdPillar(
      arabic: 'أَسْتَغْفِرُ اللَّهَ',
      transliteration: 'Astaghfirullah',
      translation: 'Je demande pardon à Allah.',
      repetitions: 100,
    ),
    WirdPillar(
      arabic: _salatoulFatihiArabic,
      transliteration: _salatoulFatihiTranslit,
      translation: _salatoulFatihiTranslation,
      repetitions: 100,
      note: 'Salatoul Fatihi — propre à la Tariqa Tijaniyya, ne doit pas être '
          'remplacée par une autre salat pendant le Lazim.',
    ),
    WirdPillar(
      arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illAllah',
      translation: "Il n'y a de divinité qu'Allah.",
      repetitions: 100,
      note: "Après la 100ᵉ récitation, ajouter une fois : "
          "مُحَمَّدٌ رَسُولُ اللَّهِ عَلَيْهِ سَلَامُ اللَّهِ "
          "(Muhammadun Rasoulullah, 'alayhi Salamoullah).",
    ),
  ],
  sequence: [
    WirdSequenceStep(label: "Formulation de l'intention (niyya)"),
    WirdSequenceStep(label: "A'oûdhou billâhi mina-chaytâni-r-rajîm", repetitions: 1),
    WirdSequenceStep(label: 'Sourate Al-Fatiha, suivie de « Amine »', repetitions: 1),
    WirdSequenceStep(label: 'Astaghfirullah', repetitions: 100),
    WirdSequenceStep(label: 'Verset de clôture (Sourate As-Saffat, 37:180-182)'),
    WirdSequenceStep(label: 'Salatoul Fatihi', repetitions: 100),
    WirdSequenceStep(label: 'Verset de clôture (Sourate As-Saffat, 37:180-182)'),
    WirdSequenceStep(
      label: "La ilaha illAllah, suivi de « Muhammadun Rasoulullah, 'alayhi Salamoullah »",
      repetitions: 100,
    ),
    WirdSequenceStep(label: 'Verset Innallaha wa mala-ikatahou... (Sourate Al-Ahzab, 33:56)'),
    WirdSequenceStep(label: "Sallallahou ta'ala 'alayhi wa 'ala alihi wa sahbihi wa sallama tasliman"),
    WirdSequenceStep(label: 'Verset de clôture (Sourate As-Saffat, 37:180-182)'),
    WirdSequenceStep(label: "Du'a personnelle"),
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
    WirdPillar(
      arabic: "أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ",
      transliteration: "Astaghfirullah al-'Adhim alladhi la ilaha illa Houwa-l-Hayyou-l-Qayyoum",
      translation:
          "Je demande pardon à Allah, l'Immense, il n'y a de divinité que "
          "Lui, le Vivant, le Subsistant par Lui-même.",
      repetitions: 30,
    ),
    WirdPillar(
      arabic: _salatoulFatihiArabic,
      transliteration: _salatoulFatihiTranslit,
      translation: _salatoulFatihiTranslation,
      repetitions: 50,
    ),
    WirdPillar(
      arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illAllah',
      translation: "Il n'y a de divinité qu'Allah.",
      repetitions: 100,
      note: "Après la 100ᵉ récitation, ajouter : مُحَمَّدٌ رَسُولُ اللَّهِ عَلَيْهِ سَلَامُ اللَّهِ.",
    ),
    WirdPillar(
      arabic: 'جَوْهَرَةُ الْكَمَالِ',
      transliteration: 'Jawharatoul Kamal',
      translation: '« La Perle de la Perfection » — prière spéciale sur le Prophète ﷺ.',
      repetitions: 12,
      note: "Si les conditions ne sont pas réunies, remplacer par 20 "
          "récitations supplémentaires de Salatoul Fatihi.",
      conditions: [
        "Être en état d'ablution à l'eau (le tayammoum ne suffit pas).",
        "Se trouver dans un lieu propre, suffisamment large pour six personnes.",
        "La réciter assis, jamais monté (véhicule) ou en bateau.",
        "Porter des vêtements propres.",
      ],
      fullText: _jawharatoulKamalParagraphs,
    ),
  ],
  sequence: [
    WirdSequenceStep(label: "Formulation de l'intention (niyya)"),
    WirdSequenceStep(label: "Astaghfirullah al-'Adhim...", repetitions: 30),
    WirdSequenceStep(label: 'Salatoul Fatihi', repetitions: 50),
    WirdSequenceStep(label: "La ilaha illAllah, suivi de « Muhammadun Rasoulullah »", repetitions: 100),
    WirdSequenceStep(label: 'Jawharatoul Kamal (ou 20 Salatoul Fatihi à défaut)', repetitions: 12),
  ],
);

const hadratouJouma = Wird(
  id: 'hadratou_jouma',
  nameArabic: 'حضرة الجمعة',
  nameFrench: 'Hadratou-l-Jouma',
  frequency: WirdFrequency.weekly,
  repetitionsNote: '1600 répétitions (valeur retenue pour le projet).',
  conditionsNote:
      "Dhikr collectif hebdomadaire, uniquement le vendredi entre l'Asr et "
      "le Maghreb. Aucun rattrapage possible en cas de créneau manqué.",
  pillars: [
    WirdPillar(
      arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illAllah',
      translation: "Il n'y a de divinité qu'Allah.",
      repetitions: 1600,
      note: "Après la dernière récitation, ajouter une fois : "
          "سَيِّدُنَا مُحَمَّدٌ رَسُولُ اللَّهِ عَلَيْهِ سَلَامُ اللَّهِ "
          "(Seyidouna Muhammadoun Rasoulullah, 'alayhi Salamoullah).",
    ),
  ],
  sequence: [
    WirdSequenceStep(label: "Formulation de l'intention (niyya)"),
    WirdSequenceStep(label: "A'oûdhou billâhi mina-chaytâni-r-rajîm", repetitions: 1),
    WirdSequenceStep(label: 'Sourate Al-Fatiha, suivie de « Amine »', repetitions: 1),
    WirdSequenceStep(label: "Astaghfirullah al-'Adhim...", repetitions: 3),
    WirdSequenceStep(label: 'Salatoul Fatihi', repetitions: 1),
    WirdSequenceStep(label: 'Verset Innallaha wa mala-ikatahou... (Sourate Al-Ahzab, 33:56)'),
    WirdSequenceStep(label: "Sallallahou ta'ala 'alayhi wa 'ala alihi wa sahbihi wa sallama tasliman"),
    WirdSequenceStep(label: 'Verset de clôture (Sourate As-Saffat, 37:180-182)'),
    WirdSequenceStep(
      label: "La ilaha illAllah, suivi de « Seyidouna Muhammadoun Rasoulullah »",
      repetitions: 1600,
    ),
    WirdSequenceStep(label: 'Reprise : Ta’awwudh, Fatiha, Salatoul Fatihi, versets de clôture'),
    WirdSequenceStep(label: "Du'a final"),
  ],
);

const validatedWirds = [lazim, wazifa, hadratouJouma];
