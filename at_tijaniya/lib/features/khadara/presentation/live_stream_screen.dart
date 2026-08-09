import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/khadara_models.dart';
import 'live_stream_providers.dart';

/// Rejoindre un direct — lien externe (YouTube/Facebook/autre) + chat en
/// direct (`live_chat_messages`). Le "natif" n'est jamais atteignable via
/// `StartLiveStreamScreen` (option désactivée) ; si cet écran est malgré
/// tout ouvert sur un direct `native` (ancienne donnée, accès direct...),
/// il affiche un état honnête plutôt qu'un lien cassé.
class LiveStreamScreen extends ConsumerStatefulWidget {
  const LiveStreamScreen({super.key, required this.stream});

  final LiveStream stream;

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  final _messageController = TextEditingController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Pas de Supabase Realtime dans cet incrément (aucun précédent dans
    // l'app) : un polling léger tant que l'écran est ouvert suffit à
    // donner une sensation de "direct" au chat sans introduire une
    // dépendance/complexité supplémentaire.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) ref.invalidate(chatMessagesProvider(widget.stream.id));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openExternal() async {
    final l10n = AppLocalizations.of(context)!;
    final url = widget.stream.externalUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    final launched = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.khadaraOpenReplayError)));
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await ref.read(liveStreamRepositoryProvider).sendChatMessage(widget.stream.id, text);
    _messageController.clear();
    ref.invalidate(chatMessagesProvider(widget.stream.id));
  }

  Future<void> _confirmEnd() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.khadaraEndLiveConfirmTitle),
        content: Text(l10n.khadaraEndLiveConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.khadaraEndLiveConfirmAction)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(liveStreamRepositoryProvider).endLiveStream(widget.stream.id);
    ref.invalidate(latestStreamForEventProvider(widget.stream.eventId ?? ''));
    ref.invalidate(allLiveStreamsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final myUserId = ref.watch(currentUserIdProvider);
    final isOwner = myUserId != null && myUserId == widget.stream.startedBy;
    final isEnded = widget.stream.status == LiveStreamStatus.ended;
    final messages = ref.watch(chatMessagesProvider(widget.stream.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stream.eventTitle ?? l10n.khadaraLiveTab),
        actions: [
          if (isOwner && !isEnded)
            TextButton(
              onPressed: _confirmEnd,
              child: Text(l10n.khadaraEndLiveButton, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: widget.stream.sourceType == LiveStreamSourceType.native
                ? _NativeUnavailableBanner(l10n: l10n)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isEnded)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(l10n.khadaraLiveEnded, style: const TextStyle(color: AppColors.bronze)),
                        ),
                      FilledButton.icon(
                        onPressed: _openExternal,
                        icon: const Icon(Icons.open_in_new),
                        label: Text(l10n.khadaraWatchOn),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              error: (error, stackTrace) => Center(
                child: Text(l10n.khadaraLoadError, style: const TextStyle(color: AppColors.bronze)),
              ),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Text(l10n.khadaraChatEmpty, style: const TextStyle(color: AppColors.bronze)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, i) => _ChatBubble(message: list[i], isMine: list[i].userId == myUserId),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: myUserId == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.khadaraChatSignInToWrite, style: const TextStyle(color: AppColors.bronze)),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(hintText: l10n.khadaraChatHint),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.send, color: AppColors.emerald), onPressed: _send),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NativeUnavailableBanner extends StatelessWidget {
  const _NativeUnavailableBanner({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.emerald),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.khadaraNativeNotAvailable, style: const TextStyle(color: AppColors.ink, fontSize: 13))),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isMine});

  final LiveChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? AppColors.emeraldSoft : AppColors.offWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMine && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(message.senderName!, style: const TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            Text(message.message, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
