// Outillage commun des tests de capture (composants du kit, écrans refaits
// d'après les maquettes) : vraies polices de l'app, repli arabe, écriture des
// images. Les tests de capture sont ignorés sans les deux variables
// d'environnement (mode d'emploi en tête de `kit_captures_test.dart`) :
//
//   KIT_FONTS_DIR     dossier des polices (`Jost_500.ttf`, `Amiri_regular.ttf`,
//                     `NotoSansArabic_*.ttf`, `MaterialIcons.otf`...)
//   KIT_CAPTURES_DIR  dossier où écrire les images (hors dépôt)

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;

import 'package:at_tijaniya/core/theme/app_theme.dart';

final String? captureFontsDir = Platform.environment['KIT_FONTS_DIR'];
final String? captureOutDir = Platform.environment['KIT_CAPTURES_DIR'];

/// Raison d'ignorer un test de capture, `null` s'il peut tourner.
final String? captureSkipReason =
    captureFontsDir == null || captureOutDir == null ? 'KIT_FONTS_DIR et KIT_CAPTURES_DIR non fournis' : null;

/// Charge les polices et les sert à `google_fonts` (à appeler dans
/// `setUpAll`, seulement si [captureSkipReason] est `null`).
Future<void> setUpCaptureFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  AppTheme.debugFontFallback = const ['NotoSansArabic'];
  await _loadFonts(captureFontsDir!);
  final assets = _googleFontsAssets(captureFontsDir!);
  google_fonts_base.assetManifest = _FontsManifest(assets);
  // Le paquet lit ces « assets » par le canal des assets de Flutter : on
  // lui sert les fichiers du dossier des polices.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
      (message) async {
    final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes)));
    final file = assets[key];
    return file == null ? null : ByteData.sublistView(file.readAsBytesSync());
  });
}

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

/// Thème des captures : le thème de l'app, dont le texte d'interface reçoit
/// Noto Sans Arabic en repli (`AppTheme.debugFontFallback`, posé par
/// [setUpCaptureFonts]) — comme le fait Android avec sa police système.
ThemeData captureTheme() => AppTheme.standard;

Future<void> captureToFile(WidgetTester tester, Finder finder, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$captureOutDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
