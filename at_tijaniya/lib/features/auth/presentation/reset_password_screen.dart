import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/content_text.dart';
import '../domain/auth_error_message.dart';

/// Message affiché quand le nouveau mot de passe est refusé (audit de
/// l'authentification du 2026-10-27, P2-3). Toutes les erreurs donnaient
/// « Impossible d'enregistrer… Réessayez », y compris un mot de passe
/// identique à l'ancien, que réessayer ne règle pas.
String resetPasswordErrorMessage(Object error, AppLocalizations l10n) {
  switch (classifyAuthError(error)) {
    case AuthErrorKind.samePassword:
      return l10n.resetPasswordSame;
    case AuthErrorKind.weakPassword:
      return l10n.authWeakPassword;
    case AuthErrorKind.network:
      return l10n.khadaraOfflineError;
    case AuthErrorKind.rateLimited:
      return l10n.authRateLimited;
    case AuthErrorKind.invalidCredentials:
    case AuthErrorKind.emailAlreadyRegistered:
    case AuthErrorKind.emailNotConfirmed:
    case AuthErrorKind.generic:
      return l10n.resetPasswordError;
  }
}

/// Nouveau mot de passe — ouvert automatiquement par `AtTijaniyaApp` quand le
/// lien de réinitialisation reçu par e-mail (deep link vers
/// `SupabaseConfig.authCallbackUrl`) établit une session
/// `AuthChangeEvent.passwordRecovery` (voir app.dart). Cette session est déjà
/// valide pour appeler `updateUser` : une fois le mot de passe changé, le
/// disciple est donc directement connecté, pas besoin de repasser par
/// l'écran de connexion.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone, required this.onCancel});

  final VoidCallback onDone;

  /// Abandon de la réinitialisation — l'appelant déconnecte la session
  /// ouverte par le lien (voir `app.dart`).
  final VoidCallback onCancel;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscured = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await SupabaseConfig.client.auth.updateUser(UserAttributes(password: _passwordController.text));
      // Propose d'enregistrer le nouveau mot de passe (P2-1).
      TextInput.finishAutofillContext();
      // Ferme les sessions ouvertes sur les autres appareils (P2-3) : si la
      // réinitialisation suit un vol de compte, l'autre appareil restait
      // connecté. Au mieux : le mot de passe est déjà changé.
      try {
        await SupabaseConfig.client.auth.signOut(scope: SignOutScope.others);
      } catch (_) {}
      widget.onDone();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = resetPasswordErrorMessage(error, l10n));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.offWhite,
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.bronze)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.resetPasswordTitle,
                    style: const TextStyle(color: AppColors.zaytoune, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.resetPasswordSubtitle,
                      style: TextStyle(color: AppColors.secondaryInk, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 24),
                  // Autoremplissage et clavier (audit de l'authentification du
                  // 2026-10-27, P2-1) ; la confirmation a son propre bouton
                  // afficher/masquer, qui agit sur les deux champs.
                  AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          obscureText: _obscured,
                          enabled: !_submitting,
                          decoration: _fieldDecoration(l10n.authPasswordLabel).copyWith(
                            suffixIcon: IconButton(
                              // Libellé de l'action réelle, selon l'état (P3-3).
                              tooltip: _obscured ? l10n.a11yShowPassword : l10n.a11yHidePassword,
                              icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.bronze),
                              onPressed: () => setState(() => _obscured = !_obscured),
                            ),
                          ),
                          validator: (value) {
                            final text = value ?? '';
                            if (text.isEmpty) return l10n.authPasswordRequired;
                            if (text.length < 8) return l10n.authPasswordTooShortSignup;
                            return null;
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(l10n.authPasswordMinCharsHint,
                            style: TextStyle(color: AppColors.secondaryInk, fontSize: 11)),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscured,
                          enabled: !_submitting,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submitting ? null : _submit(),
                          decoration: _fieldDecoration(l10n.resetPasswordConfirmLabel).copyWith(
                            suffixIcon: IconButton(
                              tooltip: _obscured ? l10n.a11yShowPassword : l10n.a11yHidePassword,
                              icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.bronze),
                              onPressed: () => setState(() => _obscured = !_obscured),
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) return l10n.resetPasswordMismatch;
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    ContentText(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l10n.resetPasswordSubmit, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting ? null : widget.onCancel,
                    child: Text(l10n.resetPasswordCancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
