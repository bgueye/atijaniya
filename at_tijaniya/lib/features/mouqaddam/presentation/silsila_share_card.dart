/// Carte de partage de la silsila d'ijaza
/// (`docs/08-spec-animation-silsila.md` §7) — image dédiée générée à la
/// demande (jamais pré-générée/mise en cache côté serveur : le filtre de
/// confidentialité par maillon doit toujours refléter l'état courant de
/// `privacy_settings`), au format story 9:16.
///
/// Filtre de confidentialité IMPÉRATIF : un maillon n'affiche son nom que si
/// `IjazaChainLink.isVisibleForSharing` — sinon un pictogramme cadenas plutôt
/// que le nom, même si le disciple qui partage voit ce nom sur son propre
/// écran (`MouqaddamRepository.fetchMyIjazaChain` résout ce flag via
/// `get_ijaza_share_visibility`, jamais déduit côté client).
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/rosace_painter.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/mouqaddam_models.dart';

/// Ouvre l'aperçu plein écran de la carte de partage. La capture PNG réelle
/// n'a lieu qu'au tap sur le bouton "Partager l'image" (jamais à
/// l'ouverture) : générer l'image à la demande, comme le reste de l'écran.
Future<void> showSilsilaSharePreview(BuildContext context, List<IjazaChainLink> chain) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SilsilaSharePreviewScreen(chain: chain),
    ),
  );
}

class _SilsilaSharePreviewScreen extends StatefulWidget {
  const _SilsilaSharePreviewScreen({required this.chain});

  final List<IjazaChainLink> chain;

  @override
  State<_SilsilaSharePreviewScreen> createState() => _SilsilaSharePreviewScreenState();
}

class _SilsilaSharePreviewScreenState extends State<_SilsilaSharePreviewScreen> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _sharing = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // pixelRatio 4 sur une carte logique 270x480 -> export ~1080x1920
      // (format story 9:16 réel demandé par la spec §7).
      final image = await boundary.toImage(pixelRatio: 4);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/silsila_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: l10n.mouqaddamChainTitle);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.mouqaddamChainShareError)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.parchment,
        title: Text(l10n.mouqaddamChainShareButton),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _repaintKey,
                child: SilsilaShareCard(chain: widget.chain),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.zaytoune),
                      )
                    : const Icon(Icons.ios_share),
                label: Text(l10n.mouqaddamChainShareCardAction),
                style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.zaytoune),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le visuel exact de la carte (extrait dans un widget dédié, réutilisable
/// hors de l'aperçu si besoin) — dimensions logiques 270x480 (ratio 9:16
/// exact), reflet Flutter du prototype HTML (`.card9x16`).
class SilsilaShareCard extends StatelessWidget {
  const SilsilaShareCard({super.key, required this.chain});

  final List<IjazaChainLink> chain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 270,
        height: 480,
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.6, -1),
            end: Alignment(0.6, 1),
            colors: [AppColors.zaytoune, Color(0xFF16493A)],
          ),
        ),
        child: Stack(
          children: [
            // Filigrane rosace très discret, jamais en pattern répété (§5) —
            // volontairement plus petit que la carte (270x480) et calé dans
            // le coin : à la taille du prototype HTML (320, soit plus large
            // que la carte elle-même), le motif dominait visuellement toute
            // la carte une fois exporté en PNG haute résolution au lieu de
            // rester un discret coin de filigrane.
            Positioned(
              top: -20,
              right: -40,
              child: Opacity(
                opacity: 0.08,
                child: SizedBox(width: 150, height: 150, child: CustomPaint(painter: RosacePainter(color: AppColors.gold))),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('التجانية', textAlign: TextAlign.center, style: AppTheme.sacredText(fontSize: 15, color: AppColors.goldSoft)),
                const SizedBox(height: 4),
                Text(
                  l10n.mouqaddamChainTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: AppFonts.titlesFr, fontSize: 19, color: Colors.white),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    reverse: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (var i = chain.length - 1; i >= 0; i--) ...[
                          _ShareCardNode(link: chain[i], l10n: l10n),
                          if (i != 0) Container(width: 1, height: 10, color: AppColors.gold, margin: const EdgeInsets.symmetric(vertical: 2)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFFCFE0D6)),
                    children: [TextSpan(text: l10n.mouqaddamChainShareCardFooter)],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCardNode extends StatelessWidget {
  const _ShareCardNode({required this.link, required this.l10n});

  final IjazaChainLink link;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: link.isVisibleForSharing
          ? Text(
              link.displayName('—'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.goldSoft),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 11, color: Color(0xFFB9C9BE)),
                const SizedBox(width: 4),
                Text(
                  l10n.mouqaddamChainShareCardLockedNode,
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFB9C9BE)),
                ),
              ],
            ),
    );
  }
}
