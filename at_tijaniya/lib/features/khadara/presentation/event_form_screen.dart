import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/image_source_sheet.dart';
import '../../../core/storage/image_upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../mouqaddam/presentation/mouqaddam_providers.dart';
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
  final _addressController = TextEditingController();
  final _dateNoteController = TextEditingController();
  final _imageUploadService = ImageUploadService();

  KhadaraEventType _type = KhadaraEventType.hadra;
  DateTime? _startsAt;
  DateTime? _endsAt;
  String? _zawiyaId;
  bool _saving = false;
  String? _errorMessage;

  // Récurrence hebdomadaire (Hadratou-l-Jouma...) — voir
  // `computeNextWeeklyOccurrence` (khadara_models.dart). Quand
  // `_isRecurring` est vrai, les champs date/heure de début/fin classiques
  // sont remplacés par jour de semaine + heure + fin optionnelle.
  bool _isRecurring = false;
  int _recurrenceDayOfWeek = DateTime.friday;
  TimeOfDay _recurrenceTime = const TimeOfDay(hour: 14, minute: 0);
  DateTime? _recurrenceUntil;

  // Date approximative (`events.is_date_approximate`) : proposée seulement
  // pour un évènement à date fixe, voir `KhadaraEvent.showsApproximateDate`.
  bool _isDateApproximate = false;

  // Image de couverture : soit une nouvelle image choisie sur l'appareil
  // (_pickedImageBytes non nul, pas encore téléversée), soit l'image déjà
  // en base pour un évènement existant (_existingImageUrl), soit aucune des
  // deux (_removeImage) si le disciple a explicitement retiré l'image
  // existante — le fichier Storage lui-même n'est pas supprimé dans ce cas
  // (juste la référence en base), même sobriété que le reste du module
  // (aucun nettoyage de Storage à la suppression d'un évènement non plus).
  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;
  String? _existingImageUrl;
  bool _removeImage = false;

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
      _addressController.text = event.addressText ?? '';
      _dateNoteController.text = event.dateNote ?? '';
      _isDateApproximate = event.isDateApproximate;
      _existingImageUrl = event.imageUrl;
      _isRecurring = event.isRecurring;
      if (event.isRecurring) {
        _recurrenceDayOfWeek = event.recurrenceDayOfWeek!;
        _recurrenceTime = TimeOfDay(hour: event.recurrenceHour!, minute: event.recurrenceMinute!);
        _recurrenceUntil = event.recurrenceUntil;
      }
    }
  }

  /// Pré-remplit l'adresse depuis la zawiya choisie — seulement si le champ
  /// est encore vide, pour ne jamais écraser une adresse déjà saisie ou
  /// modifiée à la main (cas d'un évènement ponctuel hors-zawiya). Appelé
  /// au changement de sélection dans le menu déroulant admin ; pas
  /// d'équivalent pour un mouqaddam créant pour sa propre zawiya (déjà
  /// fixe) — reste à saisir manuellement pour l'instant.
  void _prefillAddressFromZawiya(Zawiya? zawiya) {
    if (zawiya?.addressText == null || _addressController.text.trim().isNotEmpty) return;
    _addressController.text = zawiya!.addressText!;
  }

  Future<void> _pickImage() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final file = await _imageUploadService.pickImage(source);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExtension = imageExtensionFromPath(file.path);
      _removeImage = false;
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageExtension = null;
      _removeImage = _existingImageUrl != null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateNoteController.dispose();
    _addressController.dispose();
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
    setState(() => _startsAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickRecurrenceTime() async {
    final time = await showTimePicker(context: context, initialTime: _recurrenceTime);
    if (time == null || !mounted) return;
    setState(() => _recurrenceTime = time);
  }

  Future<void> _pickRecurrenceUntil() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recurrenceUntil ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() => _recurrenceUntil = DateTime(date.year, date.month, date.day));
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
      initialTime:
          TimeOfDay.fromDateTime(_endsAt ?? _startsAt ?? DateTime.now()),
    );
    if (time == null || !mounted) return;
    setState(() => _endsAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    // Un évènement récurrent n'a pas de date/heure de début saisie
    // directement : elle est calculée à partir du jour/heure de récurrence
    // (voir plus bas, `computeNextWeeklyOccurrence`) — seul un évènement
    // classique exige `_startsAt`.
    if (!_isRecurring && _startsAt == null) {
      setState(() => _errorMessage = l10n.eventFormStartsAtRequired);
      return;
    }
    if (!_isRecurring && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      setState(() => _errorMessage = l10n.eventFormEndsAtInvalid);
      return;
    }
    if (_isRecurring && _recurrenceUntil != null && !_recurrenceUntil!.isAfter(DateTime.now())) {
      setState(() => _errorMessage = l10n.eventFormRecurrenceUntilInvalid);
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final isAdmin = ref.read(isAdminProvider);
    // Mouqaddam : toujours la zawiya que l'admin lui a attribuée (jamais
    // celle du profil ni celle, possiblement périmée, de l'évènement en
    // édition) — c'est exactement ce que la RLS compare. Admin : la
    // sélection libre du formulaire.
    final zawiyaId = isAdmin ? _zawiyaId : ref.read(myManagedZawiyaIdProvider);
    final descriptionText = _descriptionController.text.trim();
    // Drapeau et précision sans objet pour un évènement récurrent : remis à
    // faux/vide plutôt que de laisser en base une valeur que l'écran ignore.
    final dateNoteText = _isRecurring ? '' : _dateNoteController.text.trim();
    final isDateApproximate = !_isRecurring && _isDateApproximate;
    final addressText = _addressController.text.trim();

    // Pour un évènement récurrent, `starts_at` (colonne `not null`) reçoit
    // la prochaine occurrence calculée plutôt qu'une saisie manuelle —
    // sert de première occurrence de référence, l'affichage réel s'appuie
    // ensuite sur `nextOccurrence()`.
    final effectiveStartsAt = _isRecurring
        ? computeNextWeeklyOccurrence(
            dayOfWeek: _recurrenceDayOfWeek,
            hour: _recurrenceTime.hour,
            minute: _recurrenceTime.minute,
          )!
        : _startsAt!;

    try {
      final repo = ref.read(khadaraRepositoryProvider);
      KhadaraEvent saved;
      if (widget.event == null) {
        saved = await repo.createEvent(
          title: _titleController.text.trim(),
          description: descriptionText.isEmpty ? null : descriptionText,
          type: _type,
          startsAt: effectiveStartsAt,
          endsAt: _isRecurring ? null : _endsAt,
          zawiyaId: zawiyaId,
          latitude: null,
          longitude: null,
          addressText: addressText.isEmpty ? null : addressText,
          isRecurring: _isRecurring,
          recurrenceDayOfWeek: _isRecurring ? _recurrenceDayOfWeek : null,
          recurrenceHour: _isRecurring ? _recurrenceTime.hour : null,
          recurrenceMinute: _isRecurring ? _recurrenceTime.minute : null,
          recurrenceUntil: _isRecurring ? _recurrenceUntil : null,
          isDateApproximate: isDateApproximate,
          dateNote: dateNoteText.isEmpty ? null : dateNoteText,
        );
      } else {
        saved = await repo.updateEvent(
          widget.event!.id,
          title: _titleController.text.trim(),
          description: descriptionText.isEmpty ? null : descriptionText,
          type: _type,
          startsAt: effectiveStartsAt,
          endsAt: _isRecurring ? null : _endsAt,
          zawiyaId: zawiyaId,
          latitude: widget.event!.latitude,
          longitude: widget.event!.longitude,
          addressText: addressText.isEmpty ? null : addressText,
          isRecurring: _isRecurring,
          recurrenceDayOfWeek: _isRecurring ? _recurrenceDayOfWeek : null,
          recurrenceHour: _isRecurring ? _recurrenceTime.hour : null,
          recurrenceMinute: _isRecurring ? _recurrenceTime.minute : null,
          recurrenceUntil: _isRecurring ? _recurrenceUntil : null,
          isDateApproximate: isDateApproximate,
          dateNote: dateNoteText.isEmpty ? null : dateNoteText,
        );
      }

      // Image : étape séparée, après coup — le chemin de Storage exige un
      // event_id déjà existant (voir KhadaraRepository.updateEventImage).
      String? imageUrl = saved.imageUrl;
      if (_pickedImageBytes != null) {
        imageUrl = await _imageUploadService.uploadImage(
          bucket: 'event-images',
          path: '${saved.id}/cover.$_pickedImageExtension',
          bytes: _pickedImageBytes!,
          contentType: imageContentTypeForExtension(_pickedImageExtension!),
        );
        await repo.updateEventImage(saved.id, imageUrl);
      } else if (_removeImage) {
        await repo.updateEventImage(saved.id, null);
        imageUrl = null;
      }

      ref.invalidate(upcomingEventsProvider);
      if (mounted) {
        Navigator.of(context).pop(
          KhadaraEvent(
            id: saved.id,
            zawiyaId: saved.zawiyaId,
            zawiyaName: saved.zawiyaName,
            title: saved.title,
            description: saved.description,
            type: saved.type,
            startsAt: saved.startsAt,
            endsAt: saved.endsAt,
            latitude: saved.latitude,
            longitude: saved.longitude,
            addressText: saved.addressText,
            createdBy: saved.createdBy,
            imageUrl: imageUrl,
            isRecurring: saved.isRecurring,
            recurrenceDayOfWeek: saved.recurrenceDayOfWeek,
            recurrenceHour: saved.recurrenceHour,
            recurrenceMinute: saved.recurrenceMinute,
            recurrenceUntil: saved.recurrenceUntil,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = l10n.eventFormSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildImagePicker(AppLocalizations l10n) {
    final hasPickedImage = _pickedImageBytes != null;
    final hasExistingImage =
        !hasPickedImage && !_removeImage && _existingImageUrl != null;

    Widget preview;
    if (hasPickedImage) {
      // Pas de hauteur fixe — voir la même remarque dans event_detail_screen.dart.
      preview = Image.memory(_pickedImageBytes!,
          width: double.infinity, fit: BoxFit.fitWidth);
    } else if (hasExistingImage) {
      preview = Image.network(
        _existingImageUrl!,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        // Voir la même note dans event_detail_screen.dart.
        cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    } else {
      preview = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPickedImage || hasExistingImage) ...[
          ClipRRect(borderRadius: BorderRadius.circular(12), child: preview),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(hasPickedImage || hasExistingImage
                    ? l10n.imagePickerChange
                    : l10n.imagePickerAdd),
              ),
            ),
            if (hasPickedImage || hasExistingImage) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.bronze),
                onPressed: _clearImage,
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = ref.watch(isAdminProvider);
    // Nom de la zawiya attribuée au mouqaddam, pour le champ en lecture
    // seule : retrouvé dans l'annuaire déjà chargé, sans requête de plus.
    final managedZawiyaId = ref.watch(myManagedZawiyaIdProvider);
    final managedZawiyaName = ref.watch(zawiyasProvider).valueOrNull
        ?.where((z) => z.id == managedZawiyaId)
        .map((z) => z.name)
        .firstOrNull;
    final isEdit = widget.event != null;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              isEdit ? l10n.eventFormEditTitle : l10n.eventFormCreateTitle)),
      // `SafeArea` : évite que le bouton Enregistrer se retrouve masqué sous
      // la barre de navigation Android (3 boutons).
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration:
                      InputDecoration(labelText: l10n.eventFormTitleLabel),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.eventFormTitleRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                      labelText: l10n.eventFormDescriptionLabel),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                Text(l10n.eventFormImageLabel,
                    style:
                        TextStyle(color: AppColors.bronze, fontSize: 13)),
                const SizedBox(height: 6),
                _buildImagePicker(l10n),
                const SizedBox(height: 16),
                DropdownButtonFormField<KhadaraEventType>(
                  initialValue: _type,
                  decoration:
                      InputDecoration(labelText: l10n.eventFormTypeLabel),
                  items: [
                    for (final type in KhadaraEventType.values)
                      DropdownMenuItem(
                          value: type,
                          child: Text(khadaraEventTypeLabel(type, l10n))),
                  ],
                  onChanged: (value) =>
                      setState(() => _type = value ?? KhadaraEventType.hadra),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isRecurring,
                  onChanged: (value) => setState(() => _isRecurring = value),
                  title: Text(l10n.eventFormRecurringSwitchLabel),
                ),
                if (_isRecurring) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _recurrenceDayOfWeek,
                    decoration: InputDecoration(labelText: l10n.eventFormRecurrenceDayLabel),
                    items: [
                      for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                        DropdownMenuItem(value: day, child: Text(khadaraWeekdayLabel(day, l10n))),
                    ],
                    onChanged: (value) => setState(() => _recurrenceDayOfWeek = value ?? DateTime.friday),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.eventFormRecurrenceTimeLabel, style: TextStyle(color: AppColors.bronze, fontSize: 13)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _pickRecurrenceTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(_recurrenceTime.format(context)),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.eventFormRecurrenceUntilLabel, style: TextStyle(color: AppColors.bronze, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickRecurrenceUntil,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(_recurrenceUntil != null
                              ? formatKhadaraDate(_recurrenceUntil!)
                              : l10n.eventFormPickDate),
                        ),
                      ),
                      if (_recurrenceUntil != null)
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.bronze),
                          onPressed: () => setState(() => _recurrenceUntil = null),
                        ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(l10n.eventFormStartsAtLabel,
                      style:
                          TextStyle(color: AppColors.bronze, fontSize: 13)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _pickStartsAt,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_startsAt != null
                        ? formatKhadaraDateTime(_startsAt!)
                        : l10n.eventFormPickDateTime),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.eventFormEndsAtLabel,
                      style:
                          TextStyle(color: AppColors.bronze, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickEndsAt,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(_endsAt != null
                              ? formatKhadaraDateTime(_endsAt!)
                              : l10n.eventFormPickDateTime),
                        ),
                      ),
                      if (_endsAt != null)
                        IconButton(
                          icon: Icon(Icons.close, color: AppColors.bronze),
                          onPressed: () => setState(() => _endsAt = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isDateApproximate,
                    onChanged: (value) => setState(() => _isDateApproximate = value),
                    title: Text(l10n.eventFormApproximateDateSwitchLabel),
                    subtitle: Text(l10n.eventFormApproximateDateSwitchHint),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dateNoteController,
                    decoration: InputDecoration(
                      labelText: l10n.eventFormDateNoteLabel,
                      helperText: l10n.eventFormDateNoteHint,
                      helperMaxLines: 2,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (isAdmin)
                  ref.watch(zawiyasProvider).when(
                        loading: () => LinearProgressIndicator(
                            color: AppColors.emerald),
                        error: (error, stackTrace) => Text(
                            l10n.khadaraLoadError,
                            style: TextStyle(color: AppColors.bronze)),
                        data: (list) => DropdownButtonFormField<String?>(
                          // `isExpanded` + ellipsis : sans eux la liste prend la largeur du
                          // nom le plus long et déborde ("right overflowed") avec les noms de
                          // zawiyas ajoutés fin septembre — constaté sur téléphone le 2026-10-01.
                          isExpanded: true,
                          initialValue: _zawiyaId,
                          decoration: InputDecoration(
                              labelText: l10n.eventFormZawiyaLabel),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('—')),
                            ...list.map((z) => DropdownMenuItem<String?>(
                                value: z.id, child: Text(z.name, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (value) => setState(() {
                            _zawiyaId = value;
                            Zawiya? selected;
                            for (final z in list) {
                              if (z.id == value) {
                                selected = z;
                                break;
                              }
                            }
                            _prefillAddressFromZawiya(selected);
                          }),
                        ),
                      )
                else
                  TextFormField(
                    enabled: false,
                    // `key` : le nom arrive après le premier build (annuaire
                    // en cours de chargement), `initialValue` seul resterait figé.
                    key: ValueKey(managedZawiyaName),
                    initialValue: managedZawiyaName ?? '—',
                    decoration:
                        InputDecoration(labelText: l10n.eventFormZawiyaLabel),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration:
                      InputDecoration(labelText: l10n.khadaraAddressLabel),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.eventFormSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
