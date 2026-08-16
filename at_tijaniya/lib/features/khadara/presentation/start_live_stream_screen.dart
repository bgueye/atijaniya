import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/khadara_models.dart';
import 'live_stream_providers.dart';
import 'live_stream_screen.dart';

/// Démarrer un direct pour un évènement — "Lecteur natif + agrégation de
/// flux externes" (P2, docs/03-architecture-ecrans.md). Seule l'agrégation
/// est proposée : le choix du prestataire de streaming natif est "à
/// trancher séparément" (`docs/06-architecture-backend.md`), même statut
/// que le prestataire de paiement des dons — l'option native est donc
/// affichée mais désactivée, avec une explication honnête plutôt
/// qu'omise en silence.
class StartLiveStreamScreen extends ConsumerStatefulWidget {
  const StartLiveStreamScreen.forEvent(
      {super.key, required this.eventId, required this.contextTitle})
      : groupId = null;

  const StartLiveStreamScreen.forGroup(
      {super.key, required this.groupId, required this.contextTitle})
      : eventId = null;

  final String? eventId;
  final String? groupId;
  final String contextTitle;

  @override
  ConsumerState<StartLiveStreamScreen> createState() =>
      _StartLiveStreamScreenState();
}

class _StartLiveStreamScreenState extends ConsumerState<StartLiveStreamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  LiveStreamSourceType _source = LiveStreamSourceType.youtube;
  bool _starting = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _starting = true);
    try {
      final stream =
          await ref.read(liveStreamRepositoryProvider).startLiveStream(
                eventId: widget.eventId,
                groupId: widget.groupId,
                sourceType: _source,
                externalUrl: _urlController.text.trim(),
              );
      final eventId = widget.eventId;
      final groupId = widget.groupId;
      if (eventId != null) {
        ref.invalidate(latestStreamForEventProvider(eventId));
      }
      if (groupId != null) {
        ref.invalidate(latestStreamForGroupProvider(groupId));
      }
      ref.invalidate(allLiveStreamsProvider);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LiveStreamScreen(stream: stream)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.khadaraStartLiveError)));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.khadaraStartLiveTitle)),
      // `SafeArea` : évite que le bouton Démarrer se retrouve masqué sous la
      // barre de navigation Android (3 boutons).
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.contextTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              Text(l10n.khadaraStartLiveBody,
                  style:
                      const TextStyle(color: AppColors.bronze, fontSize: 13)),
              const SizedBox(height: 20),
              _SourceTile(
                label: l10n.khadaraSourceYoutube,
                icon: Icons.smart_display_outlined,
                selected: _source == LiveStreamSourceType.youtube,
                onTap: () =>
                    setState(() => _source = LiveStreamSourceType.youtube),
              ),
              _SourceTile(
                label: l10n.khadaraSourceFacebook,
                icon: Icons.facebook_outlined,
                selected: _source == LiveStreamSourceType.facebook,
                onTap: () =>
                    setState(() => _source = LiveStreamSourceType.facebook),
              ),
              _SourceTile(
                label: l10n.khadaraSourceOther,
                icon: Icons.link,
                selected: _source == LiveStreamSourceType.other,
                onTap: () =>
                    setState(() => _source = LiveStreamSourceType.other),
              ),
              _SourceTile(
                label: l10n.khadaraSourceNative,
                icon: Icons.videocam_outlined,
                selected: false,
                enabled: false,
                subtitle: l10n.khadaraSourceNativeUnavailable,
                onTap: null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration:
                    InputDecoration(labelText: l10n.khadaraExternalUrlLabel),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.khadaraExternalUrlRequired
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _starting ? null : _start,
                child: _starting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(l10n.khadaraStartLiveButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.subtitle,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? const BorderSide(color: AppColors.emerald, width: 2)
              : BorderSide.none,
        ),
        child: ListTile(
          leading: Icon(icon,
              color: selected ? AppColors.emerald : AppColors.bronze),
          title: Text(label),
          subtitle: subtitle != null
              ? Text(subtitle!, style: const TextStyle(fontSize: 12))
              : null,
          trailing: selected
              ? const Icon(Icons.check_circle, color: AppColors.emerald)
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
