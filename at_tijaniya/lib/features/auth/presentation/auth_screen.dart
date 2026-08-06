import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/auth_error_message.dart';

/// Inscription / Connexion — email/mot de passe. Téléphone/OTP hors
/// périmètre pour l'instant : nécessiterait un fournisseur SMS non
/// configuré (cf. docs/06-architecture-backend.md). Mode consultation sans
/// compte possible pour le module Wirds seul (cf.
/// docs/03-architecture-ecrans.md). Priorité P0.
///
/// Le lien de confirmation envoyé par e-mail à l'inscription pointe vers la
/// page par défaut de Supabase, pas vers l'app (pas de deep link configuré
/// côté client) : limite connue, hors périmètre de cet écran.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated, required this.onContinueAsGuest});

  final VoidCallback onAuthenticated;
  final VoidCallback onContinueAsGuest;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthAction { signIn, signUp }

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthAction? _loadingAction;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loadingAction = _AuthAction.signIn;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) widget.onAuthenticated();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(classifyAuthError(error), l10n));
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  Future<void> _signUp() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loadingAction = _AuthAction.signUp;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (response.session != null) {
        // Confirmation par e-mail désactivée côté projet : la session est
        // active immédiatement après l'inscription.
        widget.onAuthenticated();
      } else {
        // Confirmation par e-mail activée : pas de session tant que le lien
        // reçu par e-mail n'a pas été ouvert.
        setState(() => _infoMessage = l10n.authCheckEmailToConfirm);
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(classifyAuthError(error), l10n));
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  String _messageFor(AuthErrorKind kind, AppLocalizations l10n) {
    switch (kind) {
      case AuthErrorKind.invalidCredentials:
        return l10n.authInvalidCredentials;
      case AuthErrorKind.emailAlreadyRegistered:
        return l10n.authEmailAlreadyRegistered;
      case AuthErrorKind.weakPassword:
        return l10n.authWeakPassword;
      case AuthErrorKind.emailNotConfirmed:
        return l10n.authEmailNotConfirmed;
      case AuthErrorKind.rateLimited:
        return l10n.authRateLimited;
      case AuthErrorKind.generic:
        return l10n.authGenericError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loading = _loadingAction != null;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Text(l10n.authTitle, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(l10n.authSubtitle, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: l10n.authEmailLabel),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !loading,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return l10n.authEmailRequired;
                    if (!text.contains('@') || !text.contains('.')) return l10n.authEmailInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: l10n.authPasswordLabel),
                  obscureText: true,
                  enabled: !loading,
                  validator: (value) {
                    final text = value ?? '';
                    if (text.isEmpty) return l10n.authPasswordRequired;
                    if (text.length < 6) return l10n.authPasswordTooShort;
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                ],
                if (_infoMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_infoMessage!, style: const TextStyle(color: AppColors.emerald)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading ? null : _signIn,
                  child: _loadingAction == _AuthAction.signIn
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.authSignInAction),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: loading ? null : _signUp,
                  child: _loadingAction == _AuthAction.signUp
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                        )
                      : Text(l10n.authSignUpAction),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: loading ? null : widget.onContinueAsGuest,
                  child: Text(l10n.authContinueWithoutAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
