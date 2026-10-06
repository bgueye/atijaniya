import '../../../l10n/app_localizations.dart';

/// Codes de message posés par les contrôleurs du module Wirds (audio,
/// rappels) dans leur `errorMessage`. Les contrôleurs n'ont pas accès aux
/// traductions : ils écrivaient une phrase en français, affichée telle
/// quelle à un disciple arabophone (audit du 2026-10-04). Ils posent
/// désormais un code, et l'écran choisit le texte dans sa langue.
const wirdMsgPillarAudioUnavailable = 'audio_pillar_unavailable';
const wirdMsgWirdAudioUnavailable = 'audio_wird_unavailable';
const wirdMsgAudioPlayFailed = 'audio_play_failed';
const wirdMsgAudioStorageFull = 'audio_storage_full';
const wirdMsgAudioDownloadFailed = 'audio_download_failed';
const wirdMsgReminderPermissionDenied = 'reminder_permission_denied';

String wirdMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    wirdMsgPillarAudioUnavailable => l10n.wirdAudioPillarUnavailable,
    wirdMsgWirdAudioUnavailable => l10n.wirdAudioWirdUnavailable,
    wirdMsgAudioStorageFull => l10n.wirdAudioStorageFull,
    wirdMsgAudioDownloadFailed => l10n.wirdAudioDownloadFailed,
    wirdMsgReminderPermissionDenied => l10n.wirdReminderPermissionDenied,
    _ => l10n.wirdAudioPlayFailed,
  };
}
