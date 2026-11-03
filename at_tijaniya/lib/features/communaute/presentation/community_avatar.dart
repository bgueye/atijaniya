import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Avatar d'un disciple dans la Communauté (refonte du 2026-11-02) : son
/// initiale sur un aplat doux, ou sa photo si elle existe. La teinte dépend du
/// nom, pour qu'un même disciple garde la même couleur partout.
class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, required this.name, this.imageUrl, this.size = 40});

  final String name;
  final String? imageUrl;
  final double size;

  static final _tones = [
    (AppColors.emeraldSoft, AppColors.emerald),
    (AppColors.goldSoft, AppColors.ink),
    (AppColors.bronze.withValues(alpha: 0.16), AppColors.ink),
  ];

  /// Teinte stable pour [name] : somme des codes de caractères.
  static (Color, Color) toneFor(String name) => _tones[name.codeUnits.fold<int>(0, (a, b) => a + b) % _tones.length];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final (background, foreground) = toneFor(trimmed);
    final url = imageUrl;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _initial(initial, foreground),
              )
            : _initial(initial, foreground),
      ),
    );
  }

  Widget _initial(String initial, Color color) =>
      Text(initial, style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w600, color: color));
}
