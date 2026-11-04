import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:supabase_flutter/supabase_flutter.dart' show GoTrueClient, OtpType;

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/validation/text_limits.dart';
import '../../../core/widgets/content_text.dart';
import '../../../core/widgets/segmented_switch.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/privacy_policy_screen.dart';
import '../domain/auth_error_message.dart';
import 'auth_widgets.dart';

/// Inscription / Connexion — email/mot de passe. Téléphone/OTP hors
/// périmètre pour l'instant : nécessiterait un fournisseur SMS non
/// configuré (cf. docs/06-architecture-backend.md). Priorité P0.
///
/// Le lien de confirmation envoyé par e-mail à l'inscription et le lien de
/// réinitialisation du mot de passe pointent vers `SupabaseConfig.authCallbackUrl`
/// (deep link natif, voir AndroidManifest.xml/Info.plist) plutôt que vers le
/// Site URL par défaut de Supabase — supabase_flutter intercepte ce lien tout
/// seul et émet `AuthChangeEvent.passwordRecovery`/`signedIn`, écoutés dans
/// `app.dart` pour rediriger respectivement vers `ResetPasswordScreen` ou
/// directement vers `HomeShell`.
///
/// Volontairement **sans boutons de connexion sociale** (Google/Apple/
/// Facebook), malgré la maquette `docs/atijaniya_login_signup_toggle.html` :
/// décision actée avec le porteur de projet le 2026-08-13. Ça nécessiterait
/// une configuration OAuth côté Supabase (aucun provider activé à ce jour)
/// et un deep link natif Android/iOS pour le retour vers l'app — chantier
/// d'infrastructure à part, même statut que le prestataire de paiement des
/// dons ou le streaming natif Khadara : jamais de bouton pour une
/// fonctionnalité qui n'a pas d'implémentation réelle derrière.
///
/// Refait le 2026-11-03 d'après `docs/maquettes/parcours-entree.html`
/// (décisions validées du 2026-11-02) :
/// - on y arrive depuis l'écran d'entrée (`WelcomeScreen`), qui porte
///   désormais « Découvrir sans compte » ; d'où « Retour » au lieu du lien
///   « Continuer sans compte » ;
/// - « Nom affiché » au lieu de « Nom complet », même `display_name` ;
/// - « Afficher » / « Masquer » en toutes lettres, règles du mot de passe
///   cochées pendant la saisie, « Créer un compte » grisé sous 8 caractères ;
/// - boîte mail en écran à part entière, renvoi avec un délai visible.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    required this.onBack,
    this.initialSignUp = false,
    this.resendCooldown = const Duration(seconds: 60),
    this.auth,
  });

  final VoidCallback onAuthenticated;

  /// « Retour » et le retour système : vers l'écran d'entrée, ou vers l'app
  /// pour un invité venu s'y connecter depuis un écran (Profil, Communauté).
  final VoidCallback onBack;

  /// Ouvre sur « Créer un compte » plutôt que sur « Connexion ».
  final bool initialSignUp;

  /// Attente avant de pouvoir renvoyer l'e-mail de confirmation. Supabase
  /// refuse un renvoi rapproché (une minute par défaut) : le bouton le dit au
  /// lieu d'échouer sur « Trop de tentatives ».
  final Duration resendCooldown;

  /// Client d'authentification — celui de Supabase par défaut ; remplacé
  /// dans les tests de l'écran, qui n'ont pas de serveur.
  @visibleForTesting
  final GoTrueClient? auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthAction { signIn, signUp, resetPassword, resendConfirmation }

class _AuthScreenState extends State<AuthScreen> {
  late bool _isSignUp = widget.initialSignUp;

  GoTrueClient get _auth => widget.auth ?? SupabaseConfig.client.auth;

  /// Connexion refusée parce que l'adresse n'est pas confirmée : l'onglet
  /// Connexion propose alors de renvoyer l'e-mail de confirmation (audit de
  /// l'authentification du 2026-10-27, P2-6). Ce renvoi n'existait que dans le
  /// panneau qui suit l'inscription, perdu à la fermeture de l'app : le
  /// disciple dont le lien avait expiré restait sans issue visible.
  bool _offerResendFromLogin = false;

  // Panneau Connexion — formulaire et champs séparés du panneau Créer un
  // compte pour que basculer d'onglet réinitialise naturellement les
  // erreurs/saisies du panneau quitté, sans logique dédiée.
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginPasswordObscured = true;

  final _signupFormKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  bool _signupPasswordObscured = true;

  _AuthAction? _loadingAction;
  String? _errorMessage;
  String? _infoMessage;

  /// Adresse d'une inscription qui attend la confirmation par e-mail. Tant
  /// qu'elle est renseignée, l'onglet « Créer un compte » montre
  /// [SignupCheckEmailPanel] au lieu du formulaire. Avant le 2026-10-18, le
  /// formulaire restait affiché et rempli sous un simple message, et rien
  /// n'empêchait de recommencer — retour du test fermé. Avec la même adresse,
  /// Supabase ne répond ni par une erreur (pour ne pas révéler qu'un compte
  /// existe) ni par un nouvel e-mail : l'utilisateur croyait avoir recréé un
  /// compte qu'il ne pouvait jamais confirmer.
  String? _pendingConfirmationEmail;

  /// Secondes avant que « Renvoyer l'e-mail » redevienne disponible.
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _displayNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    super.dispose();
  }

  /// Démarre (ou relance) l'attente du renvoi : après l'inscription, puis
  /// après chaque renvoi réussi.
  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = widget.resendCooldown.inSeconds);
    if (_resendSecondsLeft <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSecondsLeft--);
      if (_resendSecondsLeft <= 0) timer.cancel();
    });
  }

  void _switchTab(bool isSignUp) {
    if (_isSignUp == isSignUp) return;
    setState(() {
      _isSignUp = isSignUp;
      _errorMessage = null;
      _infoMessage = null;
      _offerResendFromLogin = false;
    });
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _loadingAction = _AuthAction.signIn;
      _errorMessage = null;
      _infoMessage = null;
      _offerResendFromLogin = false;
    });
    try {
      await _auth.signInWithPassword(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      // Propose d'enregistrer l'identifiant dans le gestionnaire de mots de
      // passe (P2-1).
      TextInput.finishAutofillContext();
      if (mounted) widget.onAuthenticated();
    } catch (error) {
      final kind = classifyAuthError(error);
      if (mounted) {
        setState(() {
          _errorMessage = _messageFor(kind, l10n);
          _offerResendFromLogin = kind == AuthErrorKind.emailNotConfirmed;
        });
      }
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
      final response = await _auth.signUp(
        email: _signupEmailController.text.trim(),
        password: _signupPasswordController.text,
        // Clé lue par le trigger serveur `handle_new_user`
        // (`raw_user_meta_data->>'display_name'`) pour préremplir
        // `profiles.display_name` — voir database/schema.sql.
        data: {'display_name': _displayNameController.text.trim()},
        emailRedirectTo: SupabaseConfig.authCallbackUrl,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      if (response.session != null) {
        // Confirmation par e-mail désactivée côté projet : la session est
        // active immédiatement après l'inscription.
        widget.onAuthenticated();
      } else {
        // Confirmation par e-mail activée : pas de session tant que le lien
        // reçu par e-mail n'a pas été ouvert. Le formulaire laisse la place
        // au panneau « Vérifiez votre boîte mail » ; le mot de passe saisi
        // n'a plus à rester à l'écran. Un e-mail vient de partir : le renvoi
        // attend le délai de Supabase.
        setState(() => _pendingConfirmationEmail = _signupEmailController.text.trim());
        _signupPasswordController.clear();
        _startResendCooldown();
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(classifyAuthError(error), l10n));
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  /// Renvoie l'e-mail de confirmation de l'inscription en attente, ou de
  /// l'adresse saisie dans l'onglet Connexion ([fromLogin], P2-6). Supabase
  /// limite la fréquence des envois : un renvoi trop rapproché revient en
  /// erreur `rateLimited`, affichée par le message habituel.
  Future<void> _resendConfirmation({bool fromLogin = false}) async {
    final l10n = AppLocalizations.of(context)!;
    final email = fromLogin ? _loginEmailController.text.trim() : _pendingConfirmationEmail;
    if (email == null || email.isEmpty) return;
    setState(() {
      _loadingAction = _AuthAction.resendConfirmation;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await _auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: SupabaseConfig.authCallbackUrl,
      );
      if (mounted) {
        setState(() => _infoMessage = l10n.authConfirmationResent);
        if (!fromLogin) _startResendCooldown();
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(classifyAuthError(error), l10n));
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  /// Passe à l'onglet Connexion avec l'adresse déjà saisie : c'est là que
  /// l'utilisateur finit, une fois le lien de confirmation ouvert.
  void _goToLoginAfterSignup() {
    _loginEmailController.text = _pendingConfirmationEmail ?? '';
    _switchTab(false);
  }

  /// Revient au formulaire d'inscription, adresse conservée, pour corriger
  /// une faute de frappe.
  void _editSignupEmail() {
    setState(() {
      _pendingConfirmationEmail = null;
      _errorMessage = null;
      _infoMessage = null;
    });
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
      await _auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConfig.authCallbackUrl,
      );
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
      case AuthErrorKind.samePassword:
        return l10n.resetPasswordSame;
      case AuthErrorKind.emailNotConfirmed:
        return l10n.authEmailNotConfirmed;
      case AuthErrorKind.rateLimited:
        return l10n.authRateLimited;
      case AuthErrorKind.network:
        return l10n.khadaraOfflineError;
      case AuthErrorKind.generic:
        return l10n.authGenericError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pending = _pendingConfirmationEmail;
    final checkingEmail = _isSignUp && pending != null;

    // Retour système = « Retour » : sans ça, il fermait l'app depuis cette
    // étape, qui n'est pas une route poussée mais l'écran racine.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.parchment,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: ConstrainedBox(
                // Hauteur visible moins les marges : les boutons du bas
                // restent en bas quand tout tient, et l'écran défile sinon.
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _loadingAction != null ? null : widget.onBack,
                          style: TextButton.styleFrom(foregroundColor: AppColors.secondaryInk),
                          // `arrow_back` suit le sens de lecture (flèche
                          // vers la droite en arabe).
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: Text(l10n.authBack),
                        ),
                      ),
                      if (checkingEmail)
                        Expanded(
                          child: SignupCheckEmailPanel(
                            email: pending,
                            resending: _loadingAction == _AuthAction.resendConfirmation,
                            resendSecondsLeft: _resendSecondsLeft,
                            errorMessage: _errorMessage,
                            infoMessage: _infoMessage,
                            onGoToLogin: _goToLoginAfterSignup,
                            onResend: _resendConfirmation,
                            onEditEmail: _editSignupEmail,
                          ),
                        )
                      else ...[
                        const SizedBox(height: 4),
                        _PanelTitle(
                          title: _isSignUp ? l10n.authSignupTitle : l10n.authTitle,
                          subtitle: _isSignUp ? l10n.authSignupSubtitle : l10n.authSubtitle,
                        ),
                        const SizedBox(height: 16),
                        // Composant du kit (docs/kit/components/SegmentedSwitch),
                        // à la place du contrôle maison de 2026-08.
                        SegmentedSwitch<bool>(
                          items: [
                            SegmentedSwitchItem(value: false, label: l10n.authTabLogin),
                            SegmentedSwitchItem(value: true, label: l10n.authTabSignup),
                          ],
                          selected: _isSignUp,
                          onChanged: _switchTab,
                        ),
                        const SizedBox(height: 18),
                        Expanded(child: _isSignUp ? _buildSignupPanel(l10n) : _buildLoginPanel(l10n)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
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
          // Autoremplissage et touche « suivant »/« OK » du clavier (audit de
          // l'authentification du 2026-10-27, P2-1) : le gestionnaire de mots
          // de passe d'Android ne proposait rien, et Entrée ne faisait rien.
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _loginEmailController,
                  decoration: _fieldDecoration(l10n.authEmailLabel),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                  validator: (value) => _validateEmail(value, l10n),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _loginPasswordController,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => loading ? null : _signIn(),
                  decoration: _fieldDecoration(l10n.authPasswordLabel).copyWith(
                    suffixIcon: PasswordVisibilityButton(
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
              ],
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: loading ? null : _resetPassword,
              style: TextButton.styleFrom(foregroundColor: AppColors.emerald, minimumSize: const Size(0, 48)),
              child: _loadingAction == _AuthAction.resetPassword
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                    )
                  : Text(l10n.authForgotPassword),
            ),
          ),
          const SizedBox(height: 4),
          if (_errorMessage != null) _MessageBanner(text: _errorMessage!, isError: true),
          if (_infoMessage != null) _MessageBanner(text: _infoMessage!, isError: false),
          if (_offerResendFromLogin)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: loading ? null : () => _resendConfirmation(fromLogin: true),
                child: _loadingAction == _AuthAction.resendConfirmation
                    ? SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                      )
                    : Text(l10n.authResendConfirmation),
              ),
            ),
          const Spacer(),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: l10n.authSignInAction,
            loading: _loadingAction == _AuthAction.signIn,
            onPressed: loading ? null : _signIn,
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
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // « Nom affiché » (décision validée du 2026-11-02) : ce nom
                // signe les publications (« Nom · zawiya »). Demander un nom
                // complet sans dire qu'il serait visible allait contre l'esprit
                // de la lignée privée par défaut. Même `display_name` en base.
                TextFormField(
                  controller: _displayNameController,
                  maxLength: TextLimits.displayName,
                  decoration: _fieldDecoration(l10n.authDisplayNameLabel).copyWith(
                    helperText: l10n.authDisplayNameHint,
                    helperMaxLines: 2,
                    helperStyle: TextStyle(color: AppColors.secondaryInk, fontSize: 12.5, height: 1.35),
                  ),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  // Le prénom plutôt que le nom complet : « un prénom suffit ».
                  autofillHints: const [AutofillHints.givenName],
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return l10n.authDisplayNameRequired;
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _signupEmailController,
                  decoration: _fieldDecoration(l10n.authEmailLabel),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                  validator: (value) => _validateEmail(value, l10n),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _signupPasswordController,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => loading ? null : _signUp(),
                  decoration: _fieldDecoration(l10n.authPasswordLabel).copyWith(
                    suffixIcon: PasswordVisibilityButton(
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
              ],
            ),
          ),
          // Règles cochées pendant la saisie, au lieu d'une consigne fixe puis
          // d'une erreur après coup.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _signupPasswordController,
            builder: (context, value, _) => PasswordRulesList(rules: newPasswordRules(value.text, l10n)),
          ),
          const SizedBox(height: 10),
          if (_errorMessage != null) _MessageBanner(text: _errorMessage!, isError: true),
          if (_infoMessage != null) _MessageBanner(text: _infoMessage!, isError: false),
          // Mention légale (audit de l'authentification du 2026-10-27, P2-5) :
          // toute la phrase ouvre la politique de confidentialité, une cible
          // de 48 dp plutôt qu'un lien de 11 px dans le texte. Avant le bouton
          // depuis la refonte : on la lit avant d'accepter.
          Semantics(
            link: true,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.authLegalPrefix),
                        TextSpan(
                          text: l10n.authLegalPrivacy,
                          style: TextStyle(color: AppColors.emerald, decoration: TextDecoration.underline),
                        ),
                        TextSpan(text: l10n.authLegalSuffix),
                      ],
                      style: TextStyle(color: AppColors.secondaryInk, fontSize: 12.5, height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(height: 12),
          // Grisé tant que la règle des 8 caractères n'est pas remplie.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _signupPasswordController,
            builder: (context, value, _) => _PrimaryButton(
              label: l10n.authSignUpAction,
              loading: _loadingAction == _AuthAction.signUp,
              onPressed: loading || value.text.length < 8 ? null : _signUp,
            ),
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
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.bronze),
      ),
    );
  }
}

/// Titre + sous-titre de l'écran (connexion, création de compte). Textes
/// secondaires en `AppColors.secondaryInk` depuis l'audit de
/// l'authentification du 2026-10-27 (P1-3) : le bronze faisait 3,72:1 sur le
/// parchemin, sous les 4,5:1 requis. Le bronze reste pour les bordures.
class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: entryTitleStyle(context, fontSize: 28))),
        const SizedBox(height: 4),
        ContentText(subtitle, style: TextStyle(color: AppColors.secondaryInk, fontSize: 14, height: 1.45)),
      ],
    );
  }
}

/// Bouton « block » du kit (thème) : pleine largeur, fin de formulaire.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
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
      // Région live (audit de l'authentification du 2026-10-27, P2-2) :
      // TalkBack annonce le message dès qu'il paraît (« Adresse e-mail ou
      // mot de passe incorrect », « E-mail renvoyé »…), sans qu'il faille le
      // chercher à l'écran.
      child: Semantics(
        liveRegion: true,
        child: ContentText(text, style: TextStyle(color: isError ? AppColors.danger : AppColors.emerald)),
      ),
    );
  }
}

/// Ce qui remplace le formulaire d'inscription quand le compte attend la
/// confirmation de son adresse : où le lien a été envoyé, et les trois suites
/// possibles — se connecter une fois le lien ouvert, renvoyer l'e-mail, ou
/// corriger l'adresse. Plus de bouton « Créer un compte » ici : c'est lui qui
/// poussait à recommencer une inscription déjà faite.
///
/// Mis au kit le 2026-11-03 (maquette `parcours-entree.html`) : écran à part
/// entière, sans les onglets, adresse mise en évidence, et renvoi qui dit
/// dans combien de temps il sera possible ([resendSecondsLeft]) au lieu
/// d'échouer sur « Trop de tentatives ».
///
/// Public pour être testé sans Supabase : toutes les actions sont des
/// callbacks de [AuthScreen].
class SignupCheckEmailPanel extends StatelessWidget {
  const SignupCheckEmailPanel({
    super.key,
    required this.email,
    required this.resending,
    required this.onGoToLogin,
    required this.onResend,
    required this.onEditEmail,
    this.resendSecondsLeft = 0,
    this.errorMessage,
    this.infoMessage,
  });

  final String email;

  /// Renvoi en cours : les actions sont désactivées le temps de l'envoi.
  final bool resending;

  /// Secondes avant que le renvoi soit possible ; 0 : disponible.
  final int resendSecondsLeft;
  final String? errorMessage;
  final String? infoMessage;
  final VoidCallback onGoToLogin;
  final VoidCallback onResend;
  final VoidCallback onEditEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final waiting = resendSecondsLeft > 0;
    final secondary = TextStyle(color: AppColors.secondaryInk, fontSize: 14, height: 1.45);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: AppColors.emeraldSoft, borderRadius: BorderRadius.circular(24)),
            child: Icon(Icons.mark_email_unread_outlined, color: AppColors.emerald, size: 40),
          ),
        ),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(l10n.authCheckEmailTitle,
              textAlign: TextAlign.center, style: entryTitleStyle(context, fontSize: 27)),
        ),
        const SizedBox(height: 6),
        Text(l10n.authCheckEmailSentTo, textAlign: TextAlign.center, style: secondary),
        const SizedBox(height: 8),
        // L'adresse, à vérifier d'un coup d'œil : une faute de frappe est la
        // première cause d'un e-mail jamais reçu.
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.bronze.withValues(alpha: 0.3)),
            ),
            child: Text(
              email,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(l10n.authCheckEmailOpen, textAlign: TextAlign.center, style: secondary),
        const Spacer(),
        const SizedBox(height: 20),
        if (errorMessage != null) _MessageBanner(text: errorMessage!, isError: true),
        if (infoMessage != null) _MessageBanner(text: infoMessage!, isError: false),
        _PrimaryButton(label: l10n.authGoToLogin, loading: false, onPressed: resending ? null : onGoToLogin),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: resending || waiting ? null : onResend,
          child: resending
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(waiting ? l10n.authResendIn(resendSecondsLeft) : l10n.authResendConfirmation),
        ),
        const SizedBox(height: 2),
        TextButton(
          onPressed: resending ? null : onEditEmail,
          child: Text(l10n.authChangeEmail),
        ),
        const SizedBox(height: 4),
        Text(l10n.authCheckEmailSpamHint,
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryInk, fontSize: 12.5)),
      ],
    );
  }
}
