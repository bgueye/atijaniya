import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Inscription / Connexion — email ou téléphone. Mode consultation sans
/// compte possible pour le module Wirds seul (cf. docs/03-architecture-ecrans.md,
/// recommandation à valider par le porteur de projet).
/// Priorité P0.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated, required this.onContinueAsGuest});

  final VoidCallback onAuthenticated;
  final VoidCallback onContinueAsGuest;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              const SizedBox(height: 32),
              Text(l10n.authTitle, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(l10n.authSubtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: l10n.authEmailLabel),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: l10n.authPasswordLabel),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                // TODO(Phase 2/3) : brancher sur SupabaseConfig.client.auth.signInWithPassword
                onPressed: widget.onAuthenticated,
                child: Text(l10n.authSignInAction),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: widget.onAuthenticated,
                child: Text(l10n.authSignUpAction),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: widget.onContinueAsGuest,
                child: Text(l10n.authContinueWithoutAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
