import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
/// Le lien de confirmation envoyé par e-mail à l'inscription (et le lien de
/// réinitialisation du mot de passe) pointe vers la page par défaut de
/// Supabase, pas vers l'app (pas de deep link configuré côté client) :
/// limite connue, hors périmètre de cet écran.
///
/// Volontairement **sans boutons de connexion sociale** (Google/Apple/
/// Facebook), malgré la maquette `docs/atijaniya_login_signup_toggle.html` :
/// décision actée avec le porteur de projet le 2026-08-13. Ça nécessiterait
/// une configuration OAuth côté Supabase (aucun provider activé à ce jour)
/// et un deep link natif Android/iOS pour le retour vers l'app (aucun
/// schème personnalisé déclaré, navigation en `Navigator` classique sans
/// `go_router`) — chantier d'infrastructure à part, même statut que le
/// prestataire de paiement des dons ou le streaming natif Khadara. Même
/// principe déjà appliqué ailleurs dans l'app (audio des wirds, dons) :
/// jamais de bouton pour une fonctionnalité qui n'a pas d'implémentation
/// réelle derrière.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated, required this.onContinueAsGuest});

  final VoidCallback onAuthenticated;
  final VoidCallback onContinueAsGuest;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthAction { signIn, signUp, resetPassword }

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;

  // Panneau Connexion — formulaire et champs séparés du panneau Créer un
  // compte pour que basculer d'onglet réinitialise naturellement les
  // erreurs/saisies du panneau quitté, sans logique dédiée.
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginPasswordObscured = true;

  final _signupFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  bool _signupPasswordObscured = true;

  _AuthAction? _loadingAction;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _fullNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    super.dispose();
  }

  void _switchTab(bool isSignUp) {
    if (_isSignUp == isSignUp) return;
    setState(() {
      _isSignUp = isSignUp;
      _errorMessage = null;
      _infoMessage = null;
    });
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _loadingAction = _AuthAction.signIn;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
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
    if (!_signupFormKey.currentState!.validate()) return;
    setState(() {
      _loadingAction = _AuthAction.signUp;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: _signupEmailController.text.trim(),
        password: _signupPasswordController.text,
        // Clé lue par le trigger serveur `handle_new_user`
        // (`raw_user_meta_data->>'display_name'`) pour préremplir
        // `profiles.display_name` — voir database/schema.sql.
        data: {'display_name': _fullNameController.text.trim()},
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

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _loginEmailController.text.trim();
    final emailError = _validateEmail(email, l10n);
    if (emailError != null) {
      setState(() {
        _errorMessage = emailError;
        _infoMessage = null;
      });
      return;
    }
    setState(() {
      _loadingAction = _AuthAction.resetPassword;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(email);
      if (mounted) setState(() => _infoMessage = l10n.authResetPasswordSent);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(classifyAuthError(error), l10n));
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  String? _validateEmail(String? value, AppLocalizations l10n) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return l10n.authEmailRequired;
    if (!text.contains('@') || !text.contains('.')) return l10n.authEmailInvalid;
    return null;
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

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _SegmentedToggle(
                isSignUp: _isSignUp,
                loginLabel: l10n.authTabLogin,
                signupLabel: l10n.authTabSignup,
                onChanged: _switchTab,
              ),
              const SizedBox(height: 24),
              if (_isSignUp) _buildSignupPanel(l10n) else _buildLoginPanel(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPanel(AppLocalizations l10n) {
    final loading = _loadingAction != null;
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelTitle(title: l10n.authTitle, subtitle: l10n.authSubtitle),
          const SizedBox(height: 24),
          TextFormField(
            controller: _loginEmailController,
            decoration: _fieldDecoration(l10n.authEmailLabel),
            keyboardType: TextInputType.emailAddress,
            enabled: !loading,
            validator: (value) => _validateEmail(value, l10n),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _loginPasswordController,
            decoration: _fieldDecoration(l10n.authPasswordLabel).copyWith(
              suffixIcon: _obscureToggleIcon(
                obscured: _loginPasswordObscured,
                onPressed: () => setState(() => _loginPasswordObscured = !_loginPasswordObscured),
              ),
            ),
            obscureText: _loginPasswordObscured,
            enabled: !loading,
            validator: (value) {
              final text = value ?? '';
              if (text.isEmpty) return l10n.authPasswordRequired;
              if (text.length < 6) return l10n.authPasswordTooShort;
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: loading ? null : _resetPassword,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              child: _loadingAction == _AuthAction.resetPassword
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                    )
                  : Text(
                      l10n.authForgotPassword,
                      style: const TextStyle(
                        color: AppColors.emerald,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (_errorMessage != null) _MessageBanner(text: _errorMessage!, isError: true),
          if (_infoMessage != null) _MessageBanner(text: _infoMessage!, isError: false),
          const SizedBox(height: 8),
          _PrimaryButton(
            label: l10n.authSignInAction,
            loading: _loadingAction == _AuthAction.signIn,
            onPressed: loading ? null : _signIn,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: loading ? null : widget.onContinueAsGuest,
              child: Text(l10n.authContinueWithoutAccount, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupPanel(AppLocalizations l10n) {
    final loading = _loadingAction != null;
    return Form(
      key: _signupFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelTitle(title: l10n.authSignupTitle, subtitle: l10n.authSignupSubtitle),
          const SizedBox(height: 24),
          TextFormField(
            controller: _fullNameController,
            decoration: _fieldDecoration(l10n.authFullNameLabel),
            enabled: !loading,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return l10n.authFullNameRequired;
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _signupEmailController,
            decoration: _fieldDecoration(l10n.authEmailLabel),
            keyboardType: TextInputType.emailAddress,
            enabled: !loading,
            validator: (value) => _validateEmail(value, l10n),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _signupPasswordController,
            decoration: _fieldDecoration(l10n.authPasswordLabel).copyWith(
              suffixIcon: _obscureToggleIcon(
                obscured: _signupPasswordObscured,
                onPressed: () => setState(() => _signupPasswordObscured = !_signupPasswordObscured),
              ),
            ),
            obscureText: _signupPasswordObscured,
            enabled: !loading,
            validator: (value) {
              final text = value ?? '';
              if (text.isEmpty) return l10n.authPasswordRequired;
              if (text.length < 8) return l10n.authPasswordTooShortSignup;
              return null;
            },
          ),
          const SizedBox(height: 6),
          Text(
            l10n.authPasswordMinCharsHint,
            style: const TextStyle(color: AppColors.bronze, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null) _MessageBanner(text: _errorMessage!, isError: true),
          if (_infoMessage != null) _MessageBanner(text: _infoMessage!, isError: false),
          const SizedBox(height: 8),
          _PrimaryButton(
            label: l10n.authSignUpAction,
            loading: _loadingAction == _AuthAction.signUp,
            onPressed: loading ? null : _signUp,
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l10n.authLegalPrefix),
                TextSpan(text: l10n.authLegalTerms, style: const TextStyle(color: AppColors.emerald)),
                TextSpan(text: l10n.authLegalMiddle),
                TextSpan(text: l10n.authLegalPrivacy, style: const TextStyle(color: AppColors.emerald)),
                TextSpan(text: l10n.authLegalSuffix),
              ],
              style: const TextStyle(color: AppColors.bronze, fontSize: 11, height: 1.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.offWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.bronze),
      ),
    );
  }

  Widget _obscureToggleIcon({required bool obscured, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.bronze),
      onPressed: onPressed,
    );
  }
}

/// Titre (Cormorant Garamond) + sous-titre (Jost) partagés par les deux
/// panneaux — même hiérarchie typographique que le reste de l'app, réservée
/// aux titres pour la police serif (cf. règle du design system).
class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.zaytoune,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.bronze, fontSize: 12, height: 1.4)),
      ],
    );
  }
}

/// Toggle segmenté maison (pas de package) reproduisant `.tabs`/`label` de
/// `docs/atijaniya_login_signup_toggle.html` : piste or doux pilule, onglet
/// actif émeraude/texte blanc.
class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.isSignUp,
    required this.loginLabel,
    required this.signupLabel,
    required this.onChanged,
  });

  final bool isSignUp;
  final String loginLabel;
  final String signupLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Expanded(child: _segment(label: loginLabel, active: !isSignUp, onTap: () => onChanged(false))),
          Expanded(child: _segment(label: signupLabel, active: isSignUp, onTap: () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _segment({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.bronze,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: isError ? Colors.redAccent : AppColors.emerald)),
    );
  }
}
