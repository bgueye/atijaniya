import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';

/// Splash screen — logo Sceau-rosace sur fond zaytoune, animation discrète.
/// Priorité P0 (docs/03-architecture-ecrans.md).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1600), widget.onFinished);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.zaytoune,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: SizedBox(
            width: 160,
            height: 160,
            child: SvgPicture.asset(
              'assets/branding/logo-fond-sombre.svg',
              placeholderBuilder: (context) => const Icon(
                Icons.circle_outlined,
                color: AppColors.gold,
                size: 96,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
