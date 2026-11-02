// Captures des composants du kit (docs/kit/, lib/core/widgets/), en français
// et en arabe, avec les vraies polices de l'app : une image PNG par composant
// et par langue, pour vérifier le rendu à l'œil sans téléphone.
//
// Ignoré par défaut : il faut fournir les polices, que le dépôt ne contient
// pas (elles sont servies par `google_fonts` à l'exécution, voir pubspec.yaml).
// Lancement :
//
//   KIT_FONTS_DIR=<dossier des polices> KIT_CAPTURES_DIR=<dossier de sortie> \
//     flutter test test/kit_captures_test.dart
//
// Le dossier des polices contient des fichiers nommés comme les familles
// enregistrées par `google_fonts` (`Jost_regular.ttf`, `Jost_500.ttf`,
// `CormorantGaramond_600.ttf`, `Amiri_regular.ttf`, `Amiri_700.ttf`...), les
// fichiers `NotoSansArabic_*.ttf` et `MaterialIcons.otf` (copié du SDK
// Flutter, `bin/cache/artifacts/material_fonts/`). Noto Sans Arabic joue le
// rôle de la police de repli du téléphone : Jost n'a pas de glyphes arabes, et
// sans elle les libellés de l'interface arabe sortaient en carrés — c'est ce
// qui avait empêché de vérifier l'arabe de l'accueil le 2026-11-01.
//
// Les images ne sont pas versionnées (décision du 2026-11-02) : leur rendu
// dépend de la machine qui les produit, elles ne valent pas comme référence.
//
// Les libellés viennent des fichiers de traduction de l'app quand ils
// existent ; les autres sont des échantillons de test, jamais affichés dans
// l'app. Aucun texte religieux n'est écrit ici : les noms de wirds viennent
// du corpus validé (`wirds_content.dart`).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;

import 'package:at_tijaniya/core/theme/app_colors.dart';
import 'package:at_tijaniya/core/theme/app_theme.dart';
import 'package:at_tijaniya/core/widgets/app_buttons.dart';
import 'package:at_tijaniya/core/widgets/content_sheet.dart';
import 'package:at_tijaniya/core/widgets/date_block.dart';
import 'package:at_tijaniya/core/widgets/eyebrow.dart';
import 'package:at_tijaniya/core/widgets/filter_chips.dart';
import 'package:at_tijaniya/core/widgets/list_group.dart';
import 'package:at_tijaniya/core/widgets/notice.dart';
import 'package:at_tijaniya/core/widgets/section_title.dart';
import 'package:at_tijaniya/core/widgets/segmented_switch.dart';
import 'package:at_tijaniya/core/widgets/stat_tile.dart';
import 'package:at_tijaniya/core/widgets/state_pill.dart';
import 'package:at_tijaniya/features/mouqaddam/presentation/sponsorship_badge.dart';
import 'package:at_tijaniya/features/wird/data/wirds_content.dart';
import 'package:at_tijaniya/features/wird/domain/wird_models.dart';
import 'package:at_tijaniya/features/wird/presentation/wird_band.dart';
import 'package:at_tijaniya/l10n/app_localizations.dart';

final _fontsDir = Platform.environment['KIT_FONTS_DIR'];
final _outDir = Platform.environment['KIT_CAPTURES_DIR'];

/// Échantillon de test dans la langue de la capture.
String _t(BuildContext context, String fr, String ar) => Localizations.localeOf(context).languageCode == 'ar' ? ar : fr;

/// Planche d'un composant : un fond parchemin et ses variantes.
typedef _Sheet = Widget Function(BuildContext context, AppLocalizations l10n);

final Map<String, _Sheet> _sheets = {
  'eyebrow': (context, l10n) => Wrap(spacing: 16, runSpacing: 12, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Eyebrow(l10n.homeNextStepEyebrow),
          Text(wirdBandName(context, wazifa), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.zaytoune, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Eyebrow(l10n.homeDiscoverCaseEyebrow(l10n.wirdRepairKindErreur), onDark: true),
            Text(l10n.homeDiscoverWhatToDo, style: AppTheme.titleText(fontSize: 20, color: AppColors.offWhite)),
          ]),
        ),
      ]),
  'section_title': (context, l10n) => Column(mainAxisSize: MainAxisSize.min, children: [
        SectionTitle(l10n.homeSectionUpcoming, actionLabel: l10n.homeSeeAll, onAction: () {}),
        SectionTitle(l10n.homeSectionFeaturedFigure),
      ]),
  // Étirée sur la largeur, comme dans un écran : la rangée commence au bord
  // de début (à droite en arabe) au lieu d'être centrée.
  'filter_chips': (context, l10n) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        FilterChips<int>(
          items: [
            FilterChipItem(value: 0, label: l10n.homeDiscoverFilterForYou),
            FilterChipItem(value: 1, label: l10n.homeDiscoverFilterRepair),
            FilterChipItem(value: 2, label: l10n.homeDiscoverFilterConditions),
            FilterChipItem(value: 3, label: l10n.homeDiscoverFilterBenefits),
          ],
          selected: 0,
          onSelected: (_) {},
        ),
        FilterChips<int>(
          items: [
            FilterChipItem(value: 0, label: l10n.khadaraFilterAll),
            FilterChipItem(value: 1, label: l10n.khadaraFilterZawiyas, count: 34),
            FilterChipItem(value: 2, label: l10n.khadaraFilterHolyPlaces, count: 5),
          ],
          selected: 1,
          onSelected: (_) {},
        ),
      ]),
  'date_block': (context, l10n) => Row(children: [
        DateBlock(date: DateTime(2026, 12, 25), approximate: true),
        const SizedBox(width: 12),
        DateBlock(date: DateTime(2027, 4, 4)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(_t(context, 'Ziarra annuelle', 'الزيارة السنوية'),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
            Text(_t(context, 'Vers le 25/12/2026 (date approximative)', 'نحو 25/12/2026 (تاريخ تقريبي)'),
                style: TextStyle(fontSize: 12, color: AppColors.secondaryInk)),
          ]),
        ),
      ]),
  'state_pill': (context, l10n) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatePill(_t(context, 'Fait ce matin', 'تمّ هذا الصباح'), variant: StatePillVariant.done),
          StatePill(_t(context, 'À renseigner', 'للإكمال'), variant: StatePillVariant.todo),
          StatePill(_t(context, 'Date approximative', 'تاريخ تقريبي'), variant: StatePillVariant.todo),
          StatePill(_t(context, 'Privée', 'خاص')),
          const StatePill.count(2),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.zaytoune, borderRadius: BorderRadius.circular(12)),
          child: Wrap(spacing: 8, children: [
            StatePill(_t(context, "À faire aujourd'hui", 'للقيام اليوم'), variant: StatePillVariant.onDark),
            StatePill(_t(context, 'En pause', 'متوقف مؤقتًا'), variant: StatePillVariant.gold),
          ]),
        ),
      ]),
  'stat_tile': (context, l10n) => Wrap(spacing: 8, runSpacing: 8, children: [
        StatTile(value: '7', label: l10n.wirdHistoryStreakDays, dark: true),
        StatTile(value: '52', label: l10n.wirdHistoryDaysPractised),
        StatTile(value: '3', label: l10n.wirdHistoryStreakFridays),
      ]),
  'segmented_switch': (context, l10n) => Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedSwitch<int>(
          items: [
            SegmentedSwitchItem(value: 0, label: _t(context, 'Lieux', 'الأماكن'), count: 34),
            SegmentedSwitchItem(value: 1, label: _t(context, 'Agenda', 'المواعيد'), count: 17),
          ],
          selected: 0,
          onChanged: (_) {},
        ),
        const SizedBox(height: 10),
        SegmentedSwitch<int>(
          items: [
            SegmentedSwitchItem(value: 0, label: l10n.communityFeedTab),
            SegmentedSwitchItem(value: 1, label: l10n.communityGroupsTab),
            SegmentedSwitchItem(value: 2, label: l10n.communityMessagesTooltip, unread: 2),
          ],
          selected: 1,
          onChanged: (_) {},
        ),
      ]),
  'list_group': (context, l10n) => ListGroup(items: [
        ListGroupItem(
          icon: Icons.account_tree_outlined,
          title: l10n.profileMyLineage,
          subtitle: _t(context, 'Renseignée', 'مُدخلة'),
          tone: ListGroupTone.sacred,
          trailing: StatePill(_t(context, 'Privée', 'خاص')),
          onTap: () {},
        ),
        ListGroupItem(
          icon: Icons.groups_outlined,
          title: l10n.lineageFindDisciplesCta,
          subtitle: _t(context, '2 correspondances', 'تطابقان'),
          trailing: const StatePill.count(2),
          onTap: () {},
        ),
        ListGroupItem(
          icon: Icons.contrast,
          title: l10n.settingsHighContrastTitle,
          subtitle: l10n.settingsHighContrastSubtitle,
          tone: ListGroupTone.neutral,
          trailing: Switch(value: false, onChanged: (_) {}),
        ),
        ListGroupItem(
            icon: Icons.language, title: l10n.settingsLanguageSection, tone: ListGroupTone.neutral, onTap: () {}),
      ]),
  'notice': (context, l10n) => Column(mainAxisSize: MainAxisSize.min, children: [
        Notice.info(l10n.homeEventsEmpty),
        const SizedBox(height: 10),
        Notice.error(l10n.homeEventsLoadError, offline: true, onRetry: () {}),
        const SizedBox(height: 10),
        Notice.error(l10n.homeEventsLoadError, onRetry: () {}),
      ]),
  'buttons': (context, l10n) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: () {}, child: Text(l10n.homeNextStepStart)),
          FilledButton.tonal(onPressed: () {}, style: AppButtonStyles.tonal, child: Text(l10n.homeQuickTasbihLabel)),
          OutlinedButton(onPressed: () {}, child: Text(_t(context, 'Guide', 'الدليل'))),
          TextButton(onPressed: () {}, child: Text(l10n.commonClose)),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {}, child: Text(l10n.profileSave))),
        const SizedBox(height: 4),
        DangerLinkButton(label: l10n.profileDeleteAccount, onPressed: () {}),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.zaytoune, borderRadius: BorderRadius.circular(14)),
          child: PracticeButton(
            icon: Icons.check,
            label: _t(context, 'Terminer le ${lazim.nameFrench}', 'إنهاء ${lazim.nameArabic}'),
            onPressed: () {},
          ),
        ),
      ]),
  'card_and_badge': (context, l10n) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                  child: Text(l10n.tariqaConditionsCardTitle,
                      style: AppTheme.titleText(fontSize: 18, color: AppColors.ink))),
              const SponsorshipBadge(),
            ]),
          ),
        ),
      ]),
  'wird_band': (context, l10n) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final (wird, state) in [
          (lazim, StatePill(_t(context, 'Fait ce matin', 'تمّ هذا الصباح'), variant: StatePillVariant.done)),
          (wazifa, StatePill(_t(context, "À faire aujourd'hui", 'للقيام اليوم'), variant: StatePillVariant.onDark)),
          (hadratouJouma, StatePill(_t(context, 'Vendredi', 'الجمعة'), variant: StatePillVariant.neutral)),
        ]) ...[
          ClipRRect(borderRadius: BorderRadius.circular(18), child: WirdBand(wird: wird, state: state)),
          const SizedBox(height: 10),
        ],
      ]),
};

/// Nom d'un wird dans la langue de la capture (comme `wirdDisplayName`).
String wirdBandName(BuildContext context, Wird wird) => _t(context, wird.nameFrench, wird.nameArabic);

Future<void> _loadFonts(String dir) async {
  final families = <String, FontLoader>{};
  for (final entity in Directory(dir).listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.endsWith('.ttf') && !name.endsWith('.otf')) continue;
    var family = name.substring(0, name.lastIndexOf('.'));
    // Toutes les graisses de Noto Sans Arabic dans une seule famille : c'est
    // la police de repli, choisie par graisse comme sur le téléphone.
    if (family.startsWith('NotoSansArabic')) family = 'NotoSansArabic';
    final bytes = entity.readAsBytesSync();
    (families[family] ??= FontLoader(family)).addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await Future.wait(families.values.map((loader) => loader.load()));
}

/// Fichiers de polices exposés à `google_fonts` comme s'ils étaient des
/// assets de l'app : sans eux, chaque style `GoogleFonts.*` cherche sa police
/// dans les assets, ne la trouve pas et lève une erreur une fois le test
/// terminé, ce qui le fait échouer alors que le rendu est correct (la police
/// est déjà chargée par [_loadFonts]). Le nom attendu est celui des fichiers
/// de Google Fonts (`Jost-Medium.ttf`), d'où la table des graisses.
Map<String, File> _googleFontsAssets(String dir) {
  const variants = {'regular': 'Regular', 'italic': 'Italic', '500': 'Medium', '600': 'SemiBold', '700': 'Bold'};
  final assets = <String, File>{};
  for (final entity in Directory(dir).listSync()) {
    if (entity is! File || !entity.path.endsWith('.ttf')) continue;
    final name = entity.uri.pathSegments.last.replaceAll('.ttf', '');
    final separator = name.lastIndexOf('_');
    if (separator < 0) continue;
    final variant = variants[name.substring(separator + 1)];
    if (variant == null) continue;
    assets['google_fonts/${name.substring(0, separator)}-$variant.ttf'] = entity;
  }
  return assets;
}

class _FontsManifest implements AssetManifest {
  _FontsManifest(this.assets);

  final Map<String, File> assets;

  @override
  List<String> listAssets() => assets.keys.toList();

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

ThemeData _captureTheme() {
  final theme = AppTheme.standard;
  // Repli arabe pour les libellés en Jost, comme le fait Android avec sa
  // police système. Le moteur de test n'a pas de repli système : sans cette
  // liste, un libellé arabe en Jost ne s'affiche pas du tout.
  const fallback = ['NotoSansArabic'];
  // Le style de texte d'un bouton remplace celui du thème au lieu de s'y
  // fusionner : il faut lui ajouter le repli à part.
  ButtonStyle? withFallback(ButtonStyle? style) {
    final label = style?.textStyle?.resolve(const {});
    if (style == null || label == null) return style;
    return style.copyWith(textStyle: WidgetStatePropertyAll(label.copyWith(fontFamilyFallback: fallback)));
  }

  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamilyFallback: fallback),
    filledButtonTheme: FilledButtonThemeData(style: withFallback(theme.filledButtonTheme.style)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: withFallback(theme.outlinedButtonTheme.style)),
    textButtonTheme: TextButtonThemeData(style: withFallback(theme.textButtonTheme.style)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: withFallback(theme.elevatedButtonTheme.style)),
  );
}

Future<void> _capture(WidgetTester tester, Finder finder, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  final skip = _fontsDir == null || _outDir == null ? 'KIT_FONTS_DIR et KIT_CAPTURES_DIR non fournis' : null;

  setUpAll(() async {
    if (skip != null) return;
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts(_fontsDir!);
    final assets = _googleFontsAssets(_fontsDir!);
    google_fonts_base.assetManifest = _FontsManifest(assets);
    // Le paquet lit ces « assets » par le canal des assets de Flutter : on
    // lui sert les fichiers du dossier des polices.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
        (message) async {
      final key =
          Uri.decodeFull(utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes)));
      final file = assets[key];
      return file == null ? null : ByteData.sublistView(file.readAsBytesSync());
    });
  });

  for (final locale in const [Locale('fr'), Locale('ar')]) {
    Widget app(Widget home) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _captureTheme(),
          locale: locale,
          supportedLocales: const [Locale('fr'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        );

    for (final entry in _sheets.entries) {
      testWidgets('capture ${entry.key} (${locale.languageCode})', skip: skip != null, (tester) async {
        tester.view.physicalSize = const Size(400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(app(Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: RepaintBoundary(
              key: key,
              child: Container(
                width: 400,
                color: AppColors.parchment,
                padding: const EdgeInsets.all(16),
                child: Builder(builder: (context) => entry.value(context, AppLocalizations.of(context)!)),
              ),
            ),
          ),
        )));
        await tester.pumpAndSettle();
        await _capture(tester, find.byKey(key), '${entry.key}_${locale.languageCode}');
      });
    }

    // La feuille du bas s'ouvre par-dessus un écran : capture de l'écran
    // entier, feuille ouverte.
    testWidgets('capture content_sheet (${locale.languageCode})', skip: skip != null, (tester) async {
      tester.view.physicalSize = const Size(400, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: app(Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Center(
                child: TextButton(
                  onPressed: () => showContentSheet(
                    context,
                    eyebrow: l10n.homeDiscoverCaseEyebrow(l10n.wirdRepairKindErreur),
                    source: l10n.wirdRepairSource(_t(context, 'échantillon de test', 'عيّنة اختبار')),
                    onOpenFullPage: () {},
                    children: [
                      Text(l10n.wirdRepairCardTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(l10n.settingsHighContrastSubtitle, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                  child: const Text('open'),
                ),
              );
            },
          ),
        )),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _capture(tester, find.byKey(key), 'content_sheet_${locale.languageCode}');
    });
  }
}
