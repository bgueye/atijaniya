// Carte du prochain évènement sur l'accueil.
// Extrait de `home_screen.dart` (audit de l'accueil du 2026-10-26, P3-5).

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/domain/khadara_models.dart';
import '../../khadara/presentation/event_detail_screen.dart';
import '../../khadara/presentation/khadara_format.dart';
import '../../../core/widgets/directional_chevron.dart';
import '../../../core/widgets/content_text.dart';

class HomeKhadaraTeaserCard extends StatelessWidget {
  const HomeKhadaraTeaserCard({super.key, required this.event});

  final KhadaraEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: event.imageUrl != null
              ? Image.network(
                  event.imageUrl!,
                  width: 44,
                  height: 44,
                  // Voir la même note dans khadara_screen.dart.
                  cacheWidth: (44 * MediaQuery.of(context).devicePixelRatio).round(),
                  cacheHeight: (44 * MediaQuery.of(context).devicePixelRatio).round(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const _KhadaraThumbFallback(),
                )
              : const _KhadaraThumbFallback(),
        ),
        // Deux lignes : à 200 %, une seule coupait le titre (« Ziarra de Taïba… »).
        title: ContentText(event.title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(formatKhadaraEventSchedule(event, AppLocalizations.of(context)!),
            style: TextStyle(color: AppColors.secondaryInk, fontSize: 11.5)),
        trailing: DirectionalChevron(color: AppColors.bronze),
      ),
    );
  }
}

class _KhadaraThumbFallback extends StatelessWidget {
  const _KhadaraThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.zaytoune, AppColors.emerald],
        ),
      ),
    );
  }
}
