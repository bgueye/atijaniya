import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/featured_figure.dart';
import '../domain/figure_models.dart';
import 'figures_providers.dart';

/// Épinglage admin de la "Figure de la semaine" (accueil, `home_screen.dart`)
/// — permet de choisir volontairement une figure pour une semaine donnée
/// (ex. l'aligner sur un Gamou à venir) plutôt que de laisser la rotation
/// automatique décider (`pickFigureOfTheWeek`, `featured_figure.dart`).
/// Accessible depuis `FiguresScreen` uniquement quand `isAdminProvider` vaut
/// `true` — la RLS `featured_figures_admin_write`/`_update`/`_delete` refuse
/// de toute façon l'écriture à tout autre compte.
///
/// Restreint la sélection aux figures dotées d'un portrait
/// ([eligibleForRotation]) : la carte affichée au disciple suppose toujours
/// une photo (demande explicite du porteur de projet, 2026-08-17), donc
/// épingler une figure sans portrait produirait une carte incomplète que la
/// rotation automatique n'aurait jamais produite d'elle-même.
class FeaturedFigureAdminScreen extends ConsumerStatefulWidget {
  const FeaturedFigureAdminScreen({super.key});

  @override
  ConsumerState<FeaturedFigureAdminScreen> createState() => _FeaturedFigureAdminScreenState();
}

class _FeaturedFigureAdminScreenState extends ConsumerState<FeaturedFigureAdminScreen> {
  late DateTime _weekStart = weekStartFor(DateTime.now());
  String? _selectedFigureId;
  bool _saving = false;
  String? _errorMessage;

  void _changeWeek(int deltaWeeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
      _selectedFigureId = null;
      _errorMessage = null;
    });
  }

  Future<void> _pin() async {
    final l10n = AppLocalizations.of(context)!;
    final figureId = _selectedFigureId;
    if (figureId == null) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(figuresRepositoryProvider).setFeaturedFigure(weekStart: _weekStart, figureId: figureId);
      ref.invalidate(featuredFigureOverrideProvider(_weekStart));
      ref.invalidate(featuredFigureProvider);
      if (mounted) setState(() => _selectedFigureId = null);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.featuredFigureAdminSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(figuresRepositoryProvider).clearFeaturedFigure(_weekStart);
      ref.invalidate(featuredFigureOverrideProvider(_weekStart));
      ref.invalidate(featuredFigureProvider);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.featuredFigureAdminSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _weekLabel() {
    String two(int n) => n.toString().padLeft(2, '0');
    final end = _weekStart.add(const Duration(days: 6));
    return '${two(_weekStart.day)}/${two(_weekStart.month)} – ${two(end.day)}/${two(end.month)}/${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final figuresAsync = ref.watch(figuresProvider);
    final overrideAsync = ref.watch(featuredFigureOverrideProvider(_weekStart));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featuredFigureAdminTitle)),
      body: SafeArea(
        child: figuresAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (error, stackTrace) => Center(
            child: Text(l10n.figuresLoadError, style: TextStyle(color: AppColors.bronze)),
          ),
          data: (figures) {
            final eligible = eligibleForRotation(figures);
            final pinnedId = overrideAsync.maybeWhen(data: (id) => id, orElse: () => null);
            Figure? pinnedFigure;
            for (final figure in figures) {
              if (figure.id == pinnedId) {
                pinnedFigure = figure;
                break;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.featuredFigureAdminIntro, style: TextStyle(color: AppColors.bronze, fontSize: 13)),
                  const SizedBox(height: 20),
                  Builder(builder: (context) {
                    // Transform.flip sur les deux glyphes : Row inverse déjà
                    // l'ordre physique des boutons selon la locale (le
                    // premier enfant reste "précédent" côté début de
                    // lecture), mais `Icon` ne retourne pas le glyphe lui-même
                    // — sans ça chaque chevron resterait figé et pointerait
                    // dans le mauvais sens une fois sa position inversée en
                    // arabe.
                    final isRtl = Directionality.of(context) == TextDirection.rtl;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => _changeWeek(-1),
                          icon: Transform.flip(flipX: isRtl, child: const Icon(Icons.chevron_left)),
                        ),
                        Text(_weekLabel(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        IconButton(
                          onPressed: () => _changeWeek(1),
                          icon: Transform.flip(flipX: isRtl, child: const Icon(Icons.chevron_right)),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  if (pinnedFigure != null)
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.push_pin, color: AppColors.gold),
                        title: Text(pinnedFigure.nameFrench),
                        subtitle: Text(l10n.featuredFigureAdminPinnedLabel),
                        trailing: TextButton(
                          onPressed: _saving ? null : _clear,
                          child: Text(l10n.featuredFigureAdminClear),
                        ),
                      ),
                    )
                  else
                    Text(l10n.featuredFigureAdminNoPin, style: TextStyle(color: AppColors.bronze, fontSize: 13)),
                  const SizedBox(height: 20),
                  if (eligible.isEmpty)
                    Text(l10n.featuredFigureAdminNoEligible, style: TextStyle(color: AppColors.bronze))
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedFigureId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.featuredFigureAdminPickLabel),
                      items: [
                        for (final figure in eligible)
                          DropdownMenuItem(
                            value: figure.id,
                            child: Text(figure.nameFrench, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) => setState(() => _selectedFigureId = value),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saving || _selectedFigureId == null ? null : _pin,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(l10n.featuredFigureAdminPinCta),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
