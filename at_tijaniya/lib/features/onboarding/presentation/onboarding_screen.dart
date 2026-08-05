import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/onboarding_store.dart';

/// Onboarding — présentation de l'app en 4 écrans (accueil, Wirds, Khadara,
/// Communauté). Priorité P1 (docs/03-architecture-ecrans.md : "3-4 écrans
/// d'introduction (wirds, khadara, communauté)"). Affiché une seule fois
/// (voir `OnboardingStore`), juste après le choix de la langue et avant
/// inscription/connexion.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _store = const OnboardingStore();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await _store.markSeen();
    if (mounted) widget.onFinished();
  }

  void _next(int pageCount) {
    if (_page == pageCount - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slides = [
      _OnboardingSlide(
        icon: Icons.auto_awesome,
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
      ),
      _OnboardingSlide(
        icon: Icons.menu_book_outlined,
        title: l10n.onboardingWirdTitle,
        body: l10n.onboardingWirdBody,
      ),
      _OnboardingSlide(
        icon: Icons.groups_outlined,
        title: l10n.onboardingKhadaraTitle,
        body: l10n.onboardingKhadaraBody,
      ),
      _OnboardingSlide(
        icon: Icons.people_alt_outlined,
        title: l10n.onboardingCommunityTitle,
        body: l10n.onboardingCommunityBody,
      ),
    ];
    final isLast = _page == slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Visibility(
                  visible: !isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(l10n.onboardingSkip, style: const TextStyle(color: AppColors.bronze)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: slides,
              ),
            ),
            _PageIndicator(count: slides.length, current: _page),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _next(slides.length),
                  child: Text(isLast ? l10n.onboardingStart : l10n.onboardingNext),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(color: AppColors.emeraldSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 56, color: AppColors.emerald),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.bronze, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? AppColors.emerald : AppColors.bronze.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
