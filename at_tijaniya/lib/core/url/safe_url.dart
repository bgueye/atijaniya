/// Garde d'URL pour tout lien saisi par un utilisateur puis ouvert par
/// d'autres (direct, rediffusion) — audit du 2026-10-04, point S05c.
///
/// Sans ce filtre, `launchUrl` ouvrait n'importe quel schéma : un lien
/// `tel:`, `sms:` ou `intent:` enregistré comme « direct » était notifié à
/// tous les disciples puis lancé au tap. La base applique la même règle
/// (contraintes `live_streams_external_url_http_check` et
/// `stream_replays_video_url_http_check`) ; ce fichier évite seulement
/// d'envoyer une valeur qu'elle refuserait, et protège l'ouverture d'un lien
/// déjà enregistré avant la contrainte.
library;

/// Renvoie l'URI si [value] est un lien `http`/`https` avec un hôte, sinon
/// `null`. Les espaces autour sont ignorés.
Uri? parseSafeHttpUrl(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return uri;
}
