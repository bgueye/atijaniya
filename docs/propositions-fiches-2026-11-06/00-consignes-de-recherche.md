# Consignes communes — recherche de fiches de figures At-Tijaniya

Contexte : At-Tijaniya est une app communautaire de la Tijaniyya (base Supabase en production, lue par des disciples).
Tu NE TOUCHES PAS à la base ni au dépôt git. Tu écris UNIQUEMENT ton fichier Markdown de sortie (chemin donné dans ta mission).

## Base actuelle (vérifiée le 2026-11-06)
71 figures, toutes `valide`. Champs : name_fr, name_ar, category (founder|family_lineage), foyer
(tivaouane|kaolack|medina_baye|omarienne|ain_madhi|fes|autre), bio_text, portrait_url. Silsila historique : un seul maître par figure (historical_silsila_links).
Figures existantes utiles pour rattacher : Cheikh Ahmed Tijani ; Muhammad al-Hafiz al-Alawi ash-Shinqiti ; El Hadj Oumar Tall ; Alpha Mayoro Wélé ; El Hadj Malick Sy ; Serigne Babacar Sy ; Mame Abdoul Aziz Sy Dabakh ; Serigne Mansour Sy Balkhawmi ; Thierno Seydou Nourou Tall ; Thierno Yéro Baal Anne ; Thierno Aliou Thierno Yéro Baal Anne ; El Hadj Abdoulaye Niasse ; Mame Khalifa Niasse ; Baye Niasse ; Serigne Aliou Cissé ; Sidi Ahmed Ammar Tidjani (Aïn Madhi) ; Cheikh Amary Ndack Seck (Thiénaba) ; Thierno Ciré Diop.
Mentions déjà en base (sans fiche) : la bio de Thierno Yéro Baal Anne cite « Thierno Hamet Baba Talla (Thilogne) » parmi ses disciples ; celle de Thierno Aliou Anne dit qu'il étudia à Thilogne auprès de Thierno Hamet Baba Talla, « lui-même disciple de son père ». La bio d'El Hadj Malick Sy cite comme mouqaddams/enseignants : Serigne Alioune Guèye (Tivaouane), Amadou Lamine Diène (Dakar), Thierno Alioune Kandji (Diourbel), Abdou Cissé (Pire), Rawane Mbaye, Hady Touré. La bio de Muhammad al-Hafiz dit qu'il désigna pour lui succéder son fils Ahmad et son disciple préféré, Muhammad Baddi. Femmes citées : Sokhna Fatimata (Fawade) Wélé (mère d'EHMS), Sokhna Safiétou Niang et Sokhna Rokhaya Ndiaye (épouses d'EHMS), Sokhna Yacine Dieng, Sokhna Astou Kane, Sokhna Aïcha Diankha « Astou » (mère de Baye Niasse), Sokhna Aminata Thiam, Seyda Fatima Zahra Niasse (fille aînée de Baye, épouse d'Aliou Cissé), Soxna Adama Aïsé (mère d'El Hadj Oumar), Lalla Yamina / Aurélie Picard (Aïn Madhi).

## Méthode
- Recherches web approfondies (WebSearch, mode "extended" pour les points pointus ; WebFetch pour lire les pages). Lis les pages, ne te contente pas des extraits.
- Sources par ordre de préférence : textes de la tariqa ; tidjaniya.com (et /ar), tijani.org (Northwestern), zawiya.sn ; études universitaires (Cairn, Persée, Seesemann, Wright, Hill, Robinson, Stewart, Ould Cheikh, Brigaglia, Hutson) ; presse sénégalaise/mauritanienne (APS, Le Soleil, Sud Quotidien, SenePlus, EnQuête, Seneweb, Cridem, Alakhbar). Wikipédia seulement en appoint.
- Pour chaque fait important, note la source (domaine + titre court). Recoupe : un fait d'une seule source peu fiable est marqué comme tel.
- N'INVENTE RIEN. Pas de date, filiation, citation ou nom arabe sans source. Si le nom arabe n'est pas trouvé, écris « nom arabe à établir ». Ne traduis pas une citation en arabe.
- Fonction actuelle (khalife en place) : vérifie par recherche récente (2025-2026).
- Uniquement la Tijaniyya. Neutralité entre foyers.

## Règles de rédaction de la bio proposée (texte destiné à l'app)
- Sections en MAJUSCULES séparées par une ligne vide (ex. ORIGINES ET FORMATION / SILSILA / ENSEIGNEMENT / ŒUVRES / DESCENDANCE / ZIARA ET DATES COMMÉMORATIVES), terminée par SOURCES CONSULTÉES (domaines/éditeurs, pas d'URL).
- Jamais le mot « mort » ni ses formes (meurt, mourut…) : « est rappelé à Dieu », « quitte ce bas monde », « sa disparition ». « Décès » toléré. Jamais « † ». Abréviation « disp. ».
- Aucune note de travail dans la bio (pas de « à vérifier », « Note : », « TODO »). Les doutes vont dans la section « Notes pour le porteur de projet ».
- Ton sobre, factuel, présent de narration, 1 500 à 3 500 caractères selon la matière disponible. Si la matière est trop mince pour une fiche honnête, dis-le et propose plutôt une mention dans une fiche existante.

## Format de sortie pour CHAQUE figure
### <Nom français proposé>
- name_fr proposé / name_ar proposé (ou « à établir ») / foyer proposé / category : family_lineage
- Dates : naissance / disparition (grégorien + hégire si sourcé)
- Maître(s) dans la voie (pour historical_silsila_links : un seul parent possible ; si plusieurs, dire lequel retenir et pourquoi)
- Zawiyas/lieux liés (existants ou à créer)
- Degré de confiance global : élevé / moyen / faible, et pourquoi
- Bio proposée (bloc de texte, format ci-dessus)
- Citations éventuelles (texte_fr + source précise ; text_ar seulement si trouvé tel quel)
- Notes pour le porteur de projet : divergences entre sources, informations manquantes, points à faire valider en priorité
- Liste des URL consultées (pour traçabilité ; elles n'iront pas dans l'app)

Termine ton fichier par une section « Fiches existantes à compléter » si tes recherches apportent des corrections ou ajouts sourcés à des fiches existantes (nom de la fiche, ajout proposé, source).
Ta réponse finale à l'orchestrateur : 10 lignes max, résumé de ce que tu as trouvé et chemin du fichier.
