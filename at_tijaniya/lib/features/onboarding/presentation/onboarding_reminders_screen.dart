import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/content_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../wird/data/wird_reminder_bulk.dart';
import '../../wird/data/wird_reminder_slots.dart';
import '../../wird/data/wirds_content.dart';
import '../../wird/domain/wird_models.dart';
import '../../wird/domain/wird_reminder.dart';
import '../../wird/presentation/wird_band.dart';

/// Fonction d'activation des rappels, remplaçable dans les tests (qui n'ont
/// ni notifications ni stockage réel).
typedef EnableReminders = Future<BulkReminderOutcome> Function({
  required List<Wird> wirds,
  required Set<String> slotIds,
  required Locale locale,
});

/// Étape « Rappels » du parcours d'entrée (refonte du 2026-11-03, maquette
/// `docs/maquettes/parcours-entree.html`, décision validée du 2026-11-02) :
/// facultative, juste après la découverte, une seule fois.
///
/// Les créneaux sont ceux de l'app (`wird_reminder_slots.dart`), à leur heure
/// par défaut (`WirdReminderSetting.defaultHourFor`, heures validées le
/// 2026-11-03), avec la couleur de chaque wird. L'autorisation des
/// notifications n'est demandée qu'au toucher de « Activer », quand le
/// disciple sait pourquoi : sur Android 13 et plus, un refus ne peut plus
/// être redemandé par l'app. « Plus tard » passe sans rien activer ni rien
/// demander. Les heures se changent ensuite depuis chaque wird.
class OnboardingRemindersScreen extends StatefulWidget {
  const OnboardingRemindersScreen({super.key, required this.onFinished, this.enable = enableWirdReminders});

  final VoidCallback onFinished;
  final EnableReminders enable;

  @override
  State<OnboardingRemindersScreen> createState() => _OnboardingRemindersScreenState();
}

class _OnboardingRemindersScreenState extends State<OnboardingRemindersScreen> {
  static const _wirds = [lazim, wazifa, hadratouJouma];

  /// Créneaux cochés. Par défaut, les rappels quotidiens (comme la
  /// maquette) ; celui du vendredi est laissé au choix du disciple.
  late final Set<String> _selected = {
    for (final wird in _wirds)
      for (final slot in wirdReminderSlots[wird.id] ?? const <WirdReminderSlot>[])
        if (slot.frequency == ReminderFrequency.daily) slot.id,
  };

  bool _busy = false;

  Future<void> _activate() async {
    if (_selected.isEmpty) {
      widget.onFinished();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final outcome = await widget.enable(
      wirds: _wirds,
      slotIds: Set.of(_selected),
      locale: Localizations.localeOf(context),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    // Le parcours continue dans tous les cas ; un refus ou un échec est dit
    // une fois, par le messager de l'app, qui survit au changement d'écran.
    final message = switch (outcome) {
      BulkReminderOutcome.done => null,
      BulkReminderOutcome.permissionDenied => l10n.wirdReminderPermissionDenied,
      BulkReminderOutcome.partialFailure => l10n.wirdReminderScheduleFailed,
    };
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
    }
    widget.onFinished();
  }

  String _slotLabel(AppLocalizations l10n, WirdReminderSlot slot) {
    return switch (slot.id) {
      'lazim_morning' => l10n.reminderSlotMorning,
      'lazim_evening' => l10n.reminderSlotEvening,
      'wazifa_daily' => l10n.reminderSlotDaily,
      'hadratou_jouma_weekly' => l10n.reminderSlotFriday,
      _ => slot.label,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = [
      for (final wird in _wirds)
        for (final slot in wirdReminderSlots[wird.id] ?? const <WirdReminderSlot>[]) (wird, slot),
    ];
    final count = _selected.length;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: _busy ? null : widget.onFinished,
                  style: TextButton.styleFrom(foregroundColor: AppColors.secondaryInk),
                  child: Text(l10n.remindersOnboardingLater),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.remindersOnboardingTitle,
                      style: entryTitleStyle(context, fontSize: 26),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.remindersOnboardingBody,
                    style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.secondaryInk),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: AppColors.bronze.withValues(alpha: 0.2)),
                          _ReminderRow(
                            wird: rows[i].$1,
                            slotLabel: _slotLabel(l10n, rows[i].$2),
                            time: TimeOfDay(hour: WirdReminderSetting.defaultHourFor(rows[i].$2), minute: 0),
                            value: _selected.contains(rows[i].$2.id),
                            onChanged: _busy
                                ? null
                                : (on) =>
                                    setState(() => on ? _selected.add(rows[i].$2.id) : _selected.remove(rows[i].$2.id)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: ElevatedButton(
                onPressed: _busy ? null : _activate,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(count == 0 ? l10n.continueLabel : l10n.remindersOnboardingActivate(count)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un créneau : filet à la couleur du wird, nom du wird et du créneau, heure
/// proposée, interrupteur. Toute la ligne bascule l'interrupteur.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.wird,
    required this.slotLabel,
    required this.time,
    required this.value,
    required this.onChanged,
  });

  final Wird wird;
  final String slotLabel;
  final TimeOfDay time;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final timeText = localizations.formatTimeOfDay(time, alwaysUse24HourFormat: true);
    final name = Localizations.localeOf(context).languageCode == 'ar' ? wird.nameArabic : wird.nameFrench;
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 36,
                  decoration: BoxDecoration(
                    color: wirdBandColors(wird.id).background,
                    borderRadius: BorderRadius.circular(4),
                    // Hadratou-l-Jouma : or doux, peu visible sur le blanc
                    // cassé sans un filet.
                    border: Border.all(color: AppColors.bronze.withValues(alpha: 0.25)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ContentText(name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink)),
                      Text(slotLabel, style: TextStyle(fontSize: 12.5, color: AppColors.secondaryInk)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.emerald,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
