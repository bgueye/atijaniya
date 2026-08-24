import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Nouveau mot de passe — ouvert automatiquement par `AtTijaniyaApp` quand le
/// lien de réinitialisation reçu par e-mail (deep link vers
/// `SupabaseConfig.authCallbackUrl`) établit une session
/// `AuthChangeEvent.passwordRecovery` (voir app.dart). Cette session est déjà
/// valide pour appeler `updateUser` : une fois le mot de passe changé, le
/// disciple est donc directement connecté, pas besoin de repasser par
/// l'écran de connexion.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone});

  final VoidCallback onDone;

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
      widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.resetPasswordError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.offWhite,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.bronze)),
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
                  Text(l10n.resetPasswordSubtitle, style: TextStyle(color: AppColors.bronze, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscured,
                    enabled: !_submitting,
                    decoration: _fieldDecoration(l10n.authPasswordLabel).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.bronze),
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
                  Text(l10n.authPasswordMinCharsHint, style: TextStyle(color: AppColors.bronze, fontSize: 11)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscured,
                    enabled: !_submitting,
                    decoration: _fieldDecoration(l10n.resetPasswordConfirmLabel),
                    validator: (value) {
                      if (value != _passwordController.text) return l10n.resetPasswordMismatch;
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
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
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(l10n.resetPasswordSubmit, style: const TextStyle(fontWeight: FontWeight.w600)),
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
