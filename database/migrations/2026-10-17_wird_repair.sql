-- « Rattraper son wird » (demande du porteur de projet du 2026-10-17) : que
-- faire après un oubli, une erreur ou une interruption du Lazim, de la Wazifa
-- ou de la Hadratou-l-Jouma. Appliquée sur le projet live sous le nom
-- wird_repair.
--
-- Contenu religieux : chaque ligne naît en `brouillon` et n'est servie aux
-- disciples qu'une fois passée à `valide`, après relecture par le moqaddam
-- référent (docs/01 § 8). L'admin lit aussi le brouillon, pour relire dans
-- l'app avant validation. Aucune écriture depuis l'app : corrections et
-- validation se font en SQL, comme pour les Conditions de la Tariqa à leurs
-- débuts.
--
-- Le texte arabe vit dans des colonnes `_ar` à côté du français (même modèle
-- que `tariqa_conditions`) : l'app choisit la colonne selon la langue courante.

-- 1. Les cas : une situation et ce qu'il faut faire.
--    `wird = 'all'` : règle commune, affichée quel que soit le wird choisi.
--    `kind` : le type de situation, qui sert de filtre dans l'écran.
create table public.wird_repair_cases (
  id uuid primary key default gen_random_uuid(),
  order_index int not null unique,
  wird text not null check (wird in ('all', 'lazim', 'wazifa', 'hadra')),
  kind text not null check (kind in ('manque', 'erreur', 'interruption', 'empechement')),
  situation_fr text not null,
  situation_ar text not null,
  action_fr text not null,
  action_ar text not null,
  source_fr text,
  source_ar text,
  content_status text not null default 'brouillon' check (content_status in ('brouillon', 'valide')),
  created_at timestamptz not null default now()
);
comment on table public.wird_repair_cases is
  'Rattraper son wird : cas de réparation (jabr) et de rattrapage (qada) du Lazim, de la Wazifa et de la Hadratou-l-Jouma. Contenu religieux, servi aux disciples seulement en content_status = valide.';

-- 2. Le texte qui encadre les cas, par wird : introduction, réponse rapide
--    (« Se rattrape » / « Ne se rattrape pas »), horaires (avec un libellé),
--    mise en garde, et liste des questions à poser à son moqaddam
--    (`ask_moqaddam`, rattachée à `all`).
create table public.wird_repair_notes (
  id uuid primary key default gen_random_uuid(),
  wird text not null check (wird in ('all', 'lazim', 'wazifa', 'hadra')),
  note_type text not null check (note_type in ('intro', 'quick_answer', 'timing', 'warning', 'ask_moqaddam')),
  order_index int not null,
  label_fr text,
  label_ar text,
  text_fr text not null,
  text_ar text not null,
  content_status text not null default 'brouillon' check (content_status in ('brouillon', 'valide')),
  created_at timestamptz not null default now(),
  unique (wird, note_type, order_index)
);
comment on table public.wird_repair_notes is
  'Rattraper son wird : introductions, réponses rapides, horaires, mises en garde et questions à poser au moqaddam. Même règle de validation que wird_repair_cases.';

alter table public.wird_repair_cases enable row level security;
alter table public.wird_repair_notes enable row level security;

-- Lecture : le contenu validé pour tous (y compris un visiteur non connecté,
-- comme le reste du module Wirds), le brouillon en plus pour l'admin.
create policy wird_repair_cases_read_valid_or_admin on public.wird_repair_cases for select
  using (content_status = 'valide' or public.is_admin((select auth.uid())));
create policy wird_repair_notes_read_valid_or_admin on public.wird_repair_notes for select
  using (content_status = 'valide' or public.is_admin((select auth.uid())));

-- Aucune écriture depuis le client, quel que soit le rôle.
revoke all on public.wird_repair_cases from anon, authenticated;
revoke all on public.wird_repair_notes from anon, authenticated;
grant select on public.wird_repair_cases to anon, authenticated;
grant select on public.wird_repair_notes to anon, authenticated;

-- 3. Contenu initial, en brouillon (docs/rattraper_wird_fr.json et _ar.json,
--    corrigés le 2026-10-17 avec le porteur de projet). Invisible pour les
--    disciples tant que le moqaddam référent ne l'a pas validé.
insert into public.wird_repair_cases
  (order_index, wird, kind, situation_fr, situation_ar, action_fr, action_ar, source_fr, source_ar)
values
  (1, 'all', 'erreur', 'Doute sur le nombre de répétitions', 'الشك في عدد الأذكار', 'On construit sur le nombre le plus bas, celui dont on est sûr. À la fin, on répare avec l''intention de réparer par 100 fois « Astaghfirou-llah ».', 'يبني على الأقل لأنه المتيقَّن، ثم يستغفر الله مئة مرة بنية الجبر في آخر الذكر.', 'Ifadat al-Ahmadiya, citée par Zawiya.sn et Kibriyatoul Ahmar', 'الإفادة الأحمدية، نقلا عن موقع الزاوية التجانية وكبريات الأحمر'),
  (2, 'all', 'erreur', 'Un pilier du wird est oublié ou placé trop tôt (par exemple la prière sur le Prophète avant l''istighfar)', 'ركن نُسي أو قُدِّم على موضعه (كالصلاة على النبي قبل الاستغفار)', 'On reprend le pilier omis, on termine le wird dans l''ordre, puis on répare par 100 « Astaghfirou-llah ». Si c''est volontaire, le wird est nul et doit être refait.', 'يرجع إلى الركن المتروك ويكمل الورد على ترتيبه، ثم يجبره بمئة استغفار. فإن كان ذلك عمدا بطل الورد ووجبت إعادته.', 'Zawiya.sn ; Tidjaniya.com (AR) ; Kibriyatoul Ahmar', 'موقع الزاوية التجانية؛ tidjaniya.com (ع)؛ كبريات الأحمر'),
  (3, 'all', 'erreur', 'Des répétitions en trop, par oubli', 'زيادة في العدد سهوا', '100 « Astaghfirou-llah » avec l''intention de réparer. S''il manque aussi quelque chose, on le complète d''abord. Si l''ajout est volontaire, le wird est nul.', 'يستغفر مئة مرة بنية الجبر. وإن كان معها نقص تحقق منه أتى بالناقص أولا. وإن كانت الزيادة عمدا بطل الورد.', 'Zawiya.sn ; Tidjaniya.com (AR)', 'موقع الزاوية التجانية؛ tidjaniya.com (ع)'),
  (4, 'all', 'erreur', 'Absence de présence du cœur (houdour)', 'غياب الحضور', 'Après l''acte, on récite 3 fois « Djaouharatou-l-Kamel » avec l''intention de réparer, avec toute la présence possible.', 'بعد الفراغ يقرأ ثلاث مرات «جوهرة الكمال» بنية الجبر، وبما أمكنه من الحضور.', 'Kibriyatoul Ahmar ; Zawiya.sn', 'كبريات الأحمر؛ موقع الزاوية التجانية'),
  (5, 'all', 'erreur', 'Doute ou oubli concernant la réparation elle-même', 'الشك أو النسيان في الجبر نفسه', 'On ne la recommence pas.', 'لا يعيده.', 'Zawiya.sn ; Kibriyatoul Ahmar', 'موقع الزاوية التجانية؛ كبريات الأحمر'),
  (6, 'all', 'erreur', 'Perles manquantes ou en trop sur le chapelet, nombre de jours connu', 'نقص حبات السبحة أو زيادتها، مع العلم بعدد الأيام', 'Le rattrapage des jours concernés est nécessaire.', 'القضاء عن الأيام المعنية لازم.', 'Zawiya.sn', 'موقع الزاوية التجانية'),
  (7, 'all', 'erreur', 'Perles manquantes ou en trop sur le chapelet, nombre de jours inconnu', 'نقص حبات السبحة أو زيادتها، مع الجهل بعدد الأيام', 'Si des perles manquaient : on rattrape seulement le Lazim de la dernière journée. Si des perles étaient en trop : 100 « Astaghfirou-llah » avec l''intention de réparer, pour toute la période. Certains prescrivent 600 « Astaghfirou-llah » et 3 « Djaouharatou-l-Kamel ».', 'إن كان نقصا قضى لازم آخر يوم فقط. وإن كانت زيادة استغفر مئة مرة بنية الجبر عن كل المدة. ويرى بعضهم ستمئة استغفار وثلاث مرات «جوهرة الكمال».', 'Hajj Hassan Ba''qili, Al-Ira''a, cité par Zawiya.sn', 'الحاج حسن بعقيلي، الإراءة، نقلا عن موقع الزاوية التجانية'),
  (8, 'all', 'interruption', 'On arrive en cours de récitation collective', 'من جاء أثناء القراءة الجماعية (المسبوق)', 'On commence avec le groupe là où il en est. Quand le groupe a fini, on complète ce qu''on a manqué, dans l''ordre et sans pause. La répétition rejointe en cours de route n''est pas comptée.', 'يبدأ مع الجماعة فيما هم فيه، فإذا فرغوا أتى بما فاته مرتبا دون فاصل. ولا تُحسب المرة التي أدركهم فيها في أثنائها.', 'Tidjaniya.com (AR)', 'tidjaniya.com (ع)'),
  (9, 'all', 'interruption', 'Parler pendant le wird', 'الكلام أثناء الورد', 'C''est interdit, sauf nécessité, et alors par signes si possible. Exceptions : répondre à un parent, une épouse à son mari, un disciple à son moqaddam ou à son cheikh. Une condition non respectée invalide l''évocation, qu''il faut recommencer.', 'ممنوع إلا لضرورة، وبالإشارة إن أمكن. ويُستثنى جواب الوالدين، وجواب الزوجة لزوجها، وجواب المريد لمقدَّمه أو شيخه. وكل شرط فُقد تبطل به الأذكار فيعيدها.', 'Tidjaniya.com (EN) ; Tijani Flood', 'tidjaniya.com (بالإنجليزية)؛ Tijani Flood'),
  (10, 'all', 'interruption', 'Perte des ablutions (ou du tayammum) en cours de route', 'انتقاض الوضوء أو التيمم أثناء الذكر', 'Le dhikr est annulé et on le reprend, car la pureté est une condition de validité.', 'يبطل الذكر ويُستأنف العمل، لأن الطهارة شرط صحة.', 'Tidjania.ma (Q.1, Q.5)', 'الأجوبة الشافية (س١، س٥)'),
  (11, 'all', 'interruption', 'Sommeil, chute du chapelet', 'النوم وسقوط السبحة', 'Un sommeil profond annule les ablutions, donc le dhikr. Si l''on se réveille avec la chute du chapelet, rien n''est annulé et on construit sur ce dont on est sûr.', 'النوم الثقيل ينقض الوضوء فيبطل الذكر. وإن استيقظ مع سقوط السبحة فلا يبطل، ويبني على اليقين.', 'Tidjania.ma (Q.15, Q.32)', 'الأجوبة الشافية (س١٥، س٣٢)'),
  (12, 'all', 'interruption', 'On se lève par inattention', 'القيام ناسيا', 'Si c''est bref, on s''assoit et on continue. Si c''est long, on recommence.', 'إن كان قصيرا جلس وأكمل، وإن طال استأنف.', 'Tidjania.ma (Q.14)', 'الأجوبة الشافية (س١٤)'),
  (13, 'all', 'interruption', 'L''imam se lève pour une prière obligatoire', 'قيام الإمام للصلاة المفروضة', 'On repère le grain où l''on s''arrête, on prie avec l''imam, puis, après le salut final, on reprend à ce grain sans parler entre-temps. Les tarawih et les prières surérogatoires n''interrompent pas le wird.', 'يضع علامة على سبحته، ويدخل مع الإمام، ثم يكمل ورده بعد السلام دون كلام بينهما. والتراويح والنوافل لا تقطع الورد.', 'Kibriyatoul Ahmar ; Tidjania.ma (Q.40)', 'كبريات الأحمر؛ الأجوبة الشافية (س٤٠)'),
  (14, 'all', 'interruption', 'On se souvient en plein wird qu''on n''a pas fait une prière', 'تذكر أثناء الورد أنه لم يصلِّ', 'On termine en général le wird, puis on prie. Pour le Soubh ou l''Asr oubliés, on interrompt obligatoirement le wird pour prier d''abord.', 'يتم الورد عموما ثم يصلي. أما صلاة الصبح أو العصر المنسية فيقطع الورد وجوبا ليصليها أولا.', 'Tidjania.ma (Q.3)', 'الأجوبة الشافية (س٣)'),
  (15, 'lazim', 'manque', 'Lazim oublié ou manqué', 'فوات اللازم أو نسيانه', 'Il se rattrape, comme une prière obligatoire manquée. Dans sa lettre aux disciples de Guemar, Seïdina Ahmed Tijani écrit que celui qui l''a dépassé à cause du travail, de la maladie ou d''une cause semblable le rattrape à n''importe quel moment de la nuit qui lui est possible. Le rattrapage s''impose parce que le Lazim est devenu obligatoire par l''engagement, comme un vœu.', 'يُقضى كما تُقضى الصلاة المفروضة الفائتة. وفي رسالة سيدنا أحمد التجاني إلى أهل قمار أن من فاته بسبب العمل أو المرض أو نحوه قضاه في أي وقت يمكنه من الليل. والقضاء لازم لأن الورد صار واجبا بالالتزام كالنذر.', 'Tidjaniya.com ; Zawiya.sn (Q.69)', 'tidjaniya.com؛ tidjaniya.com (ع)؛ موقع الزاوية التجانية (س٦٩)'),
  (16, 'lazim', 'empechement', 'Femme en période de menstrues, malade trop faible pour le faire', 'المرأة في أيام الحيض، والمريض العاجز عن الذكر', 'Pas de rattrapage. Un malade légèrement atteint n''est pas concerné. Seïdina Ahmed Tijani : le malade a le choix pour l''évocation de son wird, sauf s''il en est capable.', 'لا قضاء عليهما. ولا يدخل في ذلك من كان مرضه خفيفا. وقد ورد عن سيدنا أحمد التجاني أن المريض مخيَّر في ذكر وِرده إلا إذا كان قادرا.', 'Tidjaniya.com (FR)', 'tidjaniya.com (بالفرنسية)'),
  (17, 'lazim', 'manque', 'Matin avancé la nuit, et on découvre avant l''aube qu''on a oublié le soir de la veille', 'قدّم ورد الصباح ليلا ثم تذكر قبل الفجر أنه نسي مساء الأمس', 'On interrompt le matin, on fait le soir, puis le matin s''il reste du temps.', 'يقطع ورد الصباح، ويأتي بورد المساء، ثم بورد الصباح إن بقي وقت.', 'Tidjaniya.com ; Tidjaniya.com (AR)', 'tidjaniya.com؛ tidjaniya.com (ع)'),
  (18, 'lazim', 'manque', 'On découvre après le Soubh qu''on a oublié le soir de la veille', 'تذكر بعد صلاة الصبح أنه نسي مساء الأمس', 'On termine d''abord le matin, puis on fait le soir.', 'يتم ورد الصباح أولا، ثم يأتي بورد المساء.', 'Tidjaniya.com', 'tidjaniya.com'),
  (19, 'lazim', 'manque', 'Soir commencé après l''Asr, et on s''aperçoit qu''on n''a pas fait le matin', 'شرع في ورد المساء بعد العصر ثم تذكر أنه لم يقرأ ورد الصباح', 'On interrompt le soir, on fait le matin, puis on reprend le soir.', 'يقطع ورد المساء ويأتي بورد الصباح، ثم يعيد ورد المساء.', 'Tidjaniya.com ; Tidjaniya.com (AR)', 'tidjaniya.com؛ tidjaniya.com (ع)'),
  (20, 'lazim', 'manque', 'Soir commencé après le Maghreb, et on s''aperçoit qu''on n''a pas fait le matin', 'شرع في ورد المساء بعد المغرب ثم تذكر أنه لم يقرأ ورد الصباح', 'On termine le soir, puis on rattrape le matin.', 'يتم ورد المساء، ثم يقضي ورد الصباح.', 'Tidjaniya.com (Cheikh Nadhifi)', 'tidjaniya.com (الشيخ النظيفي)'),
  (21, 'lazim', 'interruption', 'L''aube se lève pendant un matin avancé', 'طلع الفجر أثناء ورد الصباح المقدَّم ليلا', 'On le termine, puis on le refait après le Soubh. Le premier compte alors comme surérogatoire.', 'يتمه، ثم يعيده بعد الصبح. ويكون الأول نفلا.', 'Tidjaniya.com ; Tidjaniya.com (AR)', 'tidjaniya.com؛ tidjaniya.com (ع)'),
  (22, 'lazim', 'interruption', 'Manger ou boire pendant le Lazim', 'الأكل والشرب أثناء اللازم', 'Cela invalide le Lazim, même pour une gorgée ou ce qui reste entre les dents. On le recommence.', 'يبطلانه، ولو جرعة أو ما بقي بين الأسنان. ويعيده.', 'Tidjaniya.com (EN)', 'tidjaniya.com (بالإنجليزية)'),
  (23, 'lazim', 'erreur', 'Une ou deux répétitions ratées (bâillement, toux)', 'فوات حبة أو حبتين (بتثاؤب أو سعال)', 'On les récite à voix basse, sans laisser de dette, puis on rejoint le groupe.', 'لا يتركها في ذمته، بل يأتي بها سرا ثم يلحق الجماعة.', 'Tidjania.ma (Q.36, Q.60)', 'الأجوبة الشافية (س٣٦، س٦٠)'),
  (24, 'wazifa', 'manque', 'Wazifa oubliée ou manquée', 'فوات الوظيفة أو نسيانها', 'Elle se rattrape toujours, comme le Lazim, car elle est devenue obligatoire par l''engagement.', 'تُقضى دائما كاللازم، لأنها صارت واجبة بالالتزام.', 'Zawiya.sn (Sidi Taïeb Sefiani, Q.69) ; Tidjaniya.com (AR) ; Tidjania.ma (Q.52)', 'موقع الزاوية التجانية (سيدي الطيب السفياني، س٦٩)؛ tidjaniya.com (ع)؛ الأجوبة الشافية (س٥٢)'),
  (25, 'wazifa', 'empechement', 'Malade', 'المريض', 'S''il guérit pendant le temps, il l''accomplit. S''il est incapable de réciter à cause de la maladie, elle tombe.', 'إن برئ في وقتها أتى بها. وإن عجز عن الذكر بسبب المرض سقطت عنه.', 'Tidjania.ma (Q.57)', 'الأجوبة الشافية (س٥٧)'),
  (26, 'wazifa', 'interruption', 'Le vendredi, la Wazifa risque de faire manquer la Hadratou-l-Jouma', 'يوم الجمعة، وخشي أن تُفوِّت الوظيفةُ حضرة الجمعة', 'On arrête la Wazifa, on fait la Hadratou-l-Jouma jusqu''au Maghreb, puis on termine la Wazifa seul après la prière, sans commencer les dhikr d''après-prière.', 'يقطع الوظيفة، ويأتي بحضرة الجمعة إلى المغرب، ثم يتم الوظيفة منفردا بعد الصلاة دون أن يبدأ أذكار ما بعد الصلاة.', 'Zawiya.sn (Cheikh Ahmed Tidjani Chinguitti, Q.70)', 'موقع الزاوية التجانية (الشيخ أحمد التجاني الشنقيطي، س٧٠)'),
  (27, 'wazifa', 'erreur', 'Une autre prière sur le Prophète est récitée pendant la Wazifa', 'قراءة صلاة أخرى على النبي أثناء الوظيفة', 'La Wazifa est invalidée.', 'تبطل الوظيفة.', 'Tidjaniya.com (EN), d''après Sidi ''Arabi ibn Sa''ih', 'tidjaniya.com (بالإنجليزية)، عن سيدي العربي بن السائح'),
  (28, 'wazifa', 'interruption', 'Manger ou boire beaucoup pendant la Wazifa', 'الإكثار من الأكل أو الشرب أثناء الوظيفة', 'Cela l''invalide si la quantité dépasse un peu.', 'يبطلها إذا زاد على القليل.', 'Tidjaniya.com (EN)', 'tidjaniya.com (بالإنجليزية)'),
  (29, 'wazifa', 'empechement', 'Les conditions de la Djaouharatou-l-Kamel ne sont pas remplies (ablutions à l''eau, position assise, qibla)', 'فقدان شروط جوهرة الكمال (الطهارة المائية، الجلوس، استقبال القبلة)', 'On récite 20 fois la Salatou-l-Fatih à la place des 12 Djaouharatou-l-Kamel. Le texte dit la même chose pour celui qui ne la connaît pas par cœur.', 'يقرأ عشرين صلاة على الفاتح بدل الجوهرة الاثنتي عشرة. وكذلك من لم يحفظ الجوهرة.', 'Tidjaniya.com (EN, AR)', 'tidjaniya.com (بالإنجليزية والعربية)'),
  (30, 'wazifa', 'empechement', 'Voyageur sur sa monture', 'المسافر على الدابة', 'Il descend et récite la Djaouharatou-l-Kamel à pied, sur un sol pur, et s''assoit à la septième. Sinon, il la remplace par 20 Salatou-l-Fatih.', 'ينزل ويقرأ الجوهرة راجلا على أرض طاهرة، ثم يجلس عند السابعة. فإن تعذر ذلك قرأ عشرين صلاة على الفاتح.', 'Tidjaniya.com (AR)', 'tidjaniya.com (ع)'),
  (31, 'hadra', 'manque', 'Le temps est passé', 'فات الوقت', 'Elle ne se rattrape pas, car ce temps béni lui est réservé.', 'لا تُقضى، لأن هذا الوقت المعظَّم مخصوص بها.', 'Zawiya.sn (Q.69) ; Tidjaniya.com (EN, AR) ; Tidjania.ma (Q.51)', 'موقع الزاوية التجانية (س٦٩)؛ tidjaniya.com؛ الأجوبة الشافية (س٥١)'),
  (32, 'hadra', 'manque', 'Oubli avec une excuse', 'النسيان لعذر', 'Pas de blâme.', 'لا حرج عليه.', 'Tidjania.ma (Q.53)', 'الأجوبة الشافية (س٥٣)'),
  (33, 'hadra', 'manque', 'Négligence, sans excuse valable', 'التفويت تهاونا بلا عذر', 'Seïdina Ahmed Tijani : le disciple a laissé passer un immense bien qu''il ne pourra pas rattraper.', 'قال سيدنا أحمد التجاني إن المريد فاته خير عظيم لا يستطيع تداركه.', 'Zawiya.sn ; Tidjaniya.com (EN)', 'موقع الزاوية التجانية؛ tidjaniya.com (بالإنجليزية)'),
  (34, 'hadra', 'empechement', 'Malade', 'المريض', 'S''il guérit pendant le temps, il l''accomplit. S''il est incapable de réciter à cause de la maladie, elle tombe.', 'إن برئ في وقتها أتى بها. وإن عجز عن الذكر بسبب المرض سقطت عنه.', 'Tidjania.ma (Q.57)', 'الأجوبة الشافية (س٥٧)'),
  (35, 'hadra', 'empechement', 'Voyage un vendredi', 'السفر يوم الجمعة', 'Si l''on espère arriver chez soi à temps, on la reporte. Si l''on craint que le temps passe, on la fait comme on peut.', 'إن رجا أن يدرك الوقت في منزله أخّرها، وإن خاف خروج الوقت ذكر بما أمكن.', 'Tidjania.ma (Q.58)', 'الأجوبة الشافية (س٥٨)');

insert into public.wird_repair_notes
  (wird, note_type, order_index, label_fr, label_ar, text_fr, text_ar)
values
  ('all', 'intro', 1, null, null, 'La réparation s''appelle le jabr. Elle se fait avec l''intention de réparer (niya jabr). Les sources la décrivent pour le wird en général.', 'الجبر يكون بنية الجبر. وصفته المصادر للورد عموما.'),
  ('lazim', 'intro', 1, null, null, 'Le Lazim se fait le matin et le soir.', 'اللازم صباحا ومساء.'),
  ('lazim', 'timing', 1, 'Matin', 'الصباح', 'Préférable : après la prière du Soubh jusqu''à Duha al-A''la (environ le milieu de la matinée). Avec excuse : jusqu''à la prière du Maghreb. Entre le Fajr et le Soubh : interdit.', 'المختار: من بعد صلاة الصبح إلى الضحى الأعلى (نحو منتصف الصباح). وعند العذر إلى صلاة المغرب. ولا يصح بين الفجر وصلاة الصبح.'),
  ('lazim', 'timing', 2, 'Soir', 'المساء', 'Préférable : de l''Asr à l''Icha. Avec excuse : de l''Icha au Fajr.', 'المختار: من العصر إلى العشاء. وعند العذر من العشاء إلى الفجر.'),
  ('lazim', 'timing', 3, 'Avancer', 'التقديم', 'Le matin peut être fait la nuit après l''Icha, en laissant le temps de lire environ cinq hizb (1 h 30). Il doit être fini avant l''appel du Fajr, sinon on le refait. Le soir ne s''avance que la nuit précédant le jour concerné, jamais avant l''Asr. Si l''on avance les deux la même nuit, le matin se fait avant le soir.', 'يجوز تقديم الصباح ليلا بعد العشاء بقدر قراءة خمسة أحزاب (نحو ساعة ونصف)، وعليه أن يفرغ قبل أذان الفجر وإلا أعاده. ولا يُقدَّم المساء إلا في الليلة السابقة لليوم المعني، ولا قبل العصر أبدا. وإن قدّمهما معا في ليلة واحدة قدّم الصباح على المساء.'),
  ('lazim', 'warning', 1, null, null, 'Mises en garde de Hajj Hassan Ba''qili. Fait avant son heure, le Lazim est nul. Fait dans le temps de nécessité sans contrainte, c''est une grande faute dans la Tariqa. Fait après ses heures, c''est un manque d''adab et une désobéissance à l''ordre du Cheikh.', 'تحذيرات الحاج حسن بعقيلي. إذا قُرئ اللازم قبل وقته فهو باطل. وإذا قُرئ في وقت الضرورة بلا عذر فهو خطأ كبير في الطريقة. وإذا قُرئ بعد وقته فهو سوء أدب ومخالفة لأمر الشيخ.'),
  ('wazifa', 'intro', 1, null, null, 'La Wazifa est un wird quotidien. Les règles de rattrapage rejoignent celles du Lazim.', 'الوظيفة ورد يومي. وأحكام قضائها كأحكام اللازم.'),
  ('wazifa', 'timing', 1, 'Temps', 'الوقت', 'Au moins une fois par jour et par nuit. Deux fois (matin et soir, aux heures du Lazim) est préférable. Faite une seule fois, elle va de l''Asr à l''Asr du lendemain, et jusqu''au Maghreb du lendemain avec une excuse valable.', 'مرة واحدة على الأقل في اليوم والليلة، وقراءتها مرتين صباحا ومساء بمواقيت اللازم أفضل. وإن قُرئت مرة واحدة فوقتها من العصر إلى عصر اليوم التالي، وعند العذر إلى مغرب اليوم التالي.'),
  ('hadra', 'intro', 1, null, null, 'Les sources la nomment « Hailala » ou « ''Asrou ». Le temps passé, elle ne se rattrape pas.', 'تسميها المصادر «الهيللة» أو «العصرو». وإذا فات وقتها فلا تُقضى.'),
  ('hadra', 'timing', 1, 'Temps', 'الوقت', 'Le vendredi seulement, de l''Asr au Maghreb. Le meilleur moment est juste avant l''appel du Maghreb.', 'يوم الجمعة فقط، من العصر إلى المغرب. وأفضله قبيل أذان المغرب.'),
  ('hadra', 'timing', 2, 'Nombre', 'العدد', 'Entre 1 000 et 1 600 répétitions, selon l''engagement du disciple.', 'بين ألف وألف وستمائة، بحسب ما التزمه المريد.'),
  ('lazim', 'quick_answer', 1, null, null, 'Se rattrape', 'يُقضى'),
  ('wazifa', 'quick_answer', 1, null, null, 'Se rattrape', 'تُقضى'),
  ('hadra', 'quick_answer', 1, null, null, 'Ne se rattrape pas', 'لا تُقضى'),
  ('all', 'ask_moqaddam', 1, null, null, 'Une longue série de jours manqués, et le délai pour les rattraper.', 'تراكم أيام فائتة كثيرة، ومدة قضائها.'),
  ('all', 'ask_moqaddam', 2, null, null, 'Une erreur volontaire dans un wird, et la façon de le reprendre.', 'خطأ عمدي في ورد، وكيفية استئنافه.'),
  ('all', 'ask_moqaddam', 3, null, null, 'Une Hadratou-l-Jouma interrompue en cours de route.', 'انقطاع حضرة الجمعة في أثنائها.'),
  ('all', 'ask_moqaddam', 4, null, null, 'Les variantes de pratique selon les foyers.', 'اختلاف الممارسة بين الزوايا.');
