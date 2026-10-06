import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_snackbar.dart';

/// Champ de saisie + bouton d'envoi, partagé par la messagerie privée, la
/// discussion d'un groupe et le chat d'un direct.
///
/// Écrit lors de l'audit du 2026-10-04 : les trois écrans avaient chacun
/// leur copie du même envoi, avec les mêmes défauts — aucune gestion
/// d'erreur (un échec réseau restait muet), aucun verrou (deux appuis
/// rapides envoyaient deux messages), effacement du champ APRÈS l'envoi (ce
/// qui supprimait aussi ce qui avait été tapé entre-temps) et usage du
/// contrôleur après la fermeture de l'écran.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.hintText,
    required this.sendTooltip,
    required this.errorMessage,
    required this.onSend,
    this.maxLength = 2000,
  });

  final String hintText;
  final String sendTooltip;

  /// Affiché si [onSend] échoue ; le texte est alors remis dans le champ.
  final String errorMessage;

  /// Envoie le message. Une exception signale l'échec.
  final Future<void> Function(String text) onSend;

  /// Garde-fou côté client : les colonnes sont en `text` sans limite.
  final int maxLength;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    // Champ vidé tout de suite : ce qui est tapé pendant l'envoi est conservé.
    _controller.clear();
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
    } catch (_) {
      if (!mounted) return;
      // On rend le texte au disciple plutôt que de le perdre.
      if (_controller.text.isEmpty) _controller.text = text;
      showErrorSnackBar(context, widget.errorMessage);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              maxLength: widget.maxLength,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              // Le compteur de caractères n'apporte rien dans une discussion.
              decoration: InputDecoration(hintText: widget.hintText, counterText: ''),
            ),
          ),
          IconButton(
            tooltip: widget.sendTooltip,
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.send, color: AppColors.emerald),
          ),
        ],
      ),
    );
  }
}
