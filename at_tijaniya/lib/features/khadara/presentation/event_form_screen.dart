import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/khadara_models.dart';
import 'khadara_format.dart';
import 'khadara_providers.dart';

/// Création/édition d'un évènement Khadara — réservé par RLS à un admin ou
/// un mouqaddam vérifié (voir `canCreateEventProvider`,
/// `events_create_admin_or_own_zawiya_mouqaddam`). Un mouqaddam ne peut
/// créer/garder un évènement que pour sa propre zawiya de rattachement
/// (`profiles.zawiya_id`) : champ verrouillé pour lui, sélectionnable pour
/// un admin. Exception explicite et scopée aux évènements Khadara à la
/// règle "le statut mouqaddam n'accorde aucune permission technique"
/// (CLAUDE.md), actée avec le porteur de projet.
///
/// `event == null` → création ; sinon édition, préremplie synchroniquement
/// depuis l'objet déjà en mémoire (pas de fetch réseau supplémentaire).
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.event});

  final KhadaraEvent? event;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  KhadaraEventType _type = KhadaraEventType.hadra;
  DateTime? _startsAt;
  DateTime? _endsAt;
  String? _zawiyaId;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _type = event.type;
      _startsAt = event.startsAt;
      _endsAt = event.endsAt;
      _zawiyaId = event.zawiyaId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickStartsAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? DateTime.now()),
    );
    if (time == null || !mounted) return;
    setState(() => _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickEndsAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endsAt ?? _startsAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endsAt ?? _startsAt ?? DateTime.now()),
    );
    if (time == null || !mounted) return;
    setState(() => _endsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_startsAt == null) {
      setState(() => _errorMessage = l10n.eventFormStartsAtRequired);
      return;
    }
    if (_endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      setState(() => _errorMessage = l10n.eventFormEndsAtInvalid);
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final isAdmin = ref.read(isAdminProvider);
    final myProfile = ref.read(myProfileProvider).valueOrNull;
    // Mouqaddam : toujours sa zawiya actuelle (jamais celle, possiblement
    // périmée, de l'évènement en édition) — la RLS s'aligne naturellement
    // dessus. Admin : la sélection libre du formulaire.
    final zawiyaId = isAdmin ? _zawiyaId : myProfile?.zawiyaId;
    final descriptionText = _descriptionController.text.trim();

    try {
      final repo = ref.read(khadaraRepositoryProvider);
      if (widget.event == null) {
        await repo.createEvent(
          title: _titleController.text.trim(),
          description: descriptionText.isEmpty ? null : descriptionText,
          type: _type,
          startsAt: _startsAt!,
          endsAt: _endsAt,
          zawiyaId: zawiyaId,
          latitude: null,
          longitude: null,
        );
        ref.invalidate(upcomingEventsProvider);
        if (mounted) Navigator.of(context).pop();
      } else {
        final updated = await repo.updateEvent(
          widget.event!.id,
          title: _titleController.text.trim(),
          description: descriptionText.isEmpty ? null : descriptionText,
          type: _type,
          startsAt: _startsAt!,
          endsAt: _endsAt,
          zawiyaId: zawiyaId,
          latitude: widget.event!.latitude,
          longitude: widget.event!.longitude,
        );
        ref.invalidate(upcomingEventsProvider);
        if (mounted) Navigator.of(context).pop(updated);
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.eventFormSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = ref.watch(isAdminProvider);
    final myProfileAsync = ref.watch(myProfileProvider);
    final isEdit = widget.event != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? l10n.eventFormEditTitle : l10n.eventFormCreateTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: l10n.eventFormTitleLabel),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? l10n.eventFormTitleRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: l10n.eventFormDescriptionLabel),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<KhadaraEventType>(
                initialValue: _type,
                decoration: InputDecoration(labelText: l10n.eventFormTypeLabel),
                items: [
                  for (final type in KhadaraEventType.values)
                    DropdownMenuItem(value: type, child: Text(khadaraEventTypeLabel(type, l10n))),
                ],
                onChanged: (value) => setState(() => _type = value ?? KhadaraEventType.hadra),
              ),
              const SizedBox(height: 16),
              Text(l10n.eventFormStartsAtLabel, style: const TextStyle(color: AppColors.bronze, fontSize: 13)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _pickStartsAt,
                icon: const Icon(Icons.event_outlined),
                label: Text(_startsAt != null ? formatKhadaraDateTime(_startsAt!) : l10n.eventFormPickDateTime),
              ),
              const SizedBox(height: 16),
              Text(l10n.eventFormEndsAtLabel, style: const TextStyle(color: AppColors.bronze, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndsAt,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_endsAt != null ? formatKhadaraDateTime(_endsAt!) : l10n.eventFormPickDateTime),
                    ),
                  ),
                  if (_endsAt != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.bronze),
                      onPressed: () => setState(() => _endsAt = null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (isAdmin)
                ref.watch(zawiyasProvider).when(
                      loading: () => const LinearProgressIndicator(color: AppColors.emerald),
                      error: (error, stackTrace) => Text(l10n.khadaraLoadError, style: const TextStyle(color: AppColors.bronze)),
                      data: (list) => DropdownButtonFormField<String?>(
                        initialValue: _zawiyaId,
                        decoration: InputDecoration(labelText: l10n.eventFormZawiyaLabel),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('—')),
                          ...list.map((z) => DropdownMenuItem<String?>(value: z.id, child: Text(z.name))),
                        ],
                        onChanged: (value) => setState(() => _zawiyaId = value),
                      ),
                    )
              else
                TextFormField(
                  enabled: false,
                  initialValue: myProfileAsync.valueOrNull?.zawiyaName ?? '—',
                  decoration: InputDecoration(labelText: l10n.eventFormZawiyaLabel),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.eventFormSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
