import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/image_source_sheet.dart';
import '../../../core/storage/image_upload_service.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../khadara/presentation/khadara_providers.dart';
import '../../profil/presentation/profile_providers.dart';
import '../domain/community_models.dart';
import '../domain/group_models.dart';
import 'community_format.dart';
import 'community_providers.dart';
import 'conversations_screen.dart';
import 'group_detail_screen.dart';
import 'groups_providers.dart';
import 'post_detail_screen.dart';

/// Fil d'actualité + Groupes — publications communauté et discussions par
/// zawiya/région. Priorité P1 pour le fil, P2 pour les groupes
/// (docs/03-architecture-ecrans.md).
///
/// Comme le module Khadara, ce contenu vient de tables Supabase (`posts` /
/// `groups`) et non d'un fichier statique. Même structure à onglets que
/// `KhadaraScreen` (Évènements/Zawiyas) pour deux listes liées au même
/// module. La lignée spirituelle et le statut Mouqaddam restent dans des
/// écrans dédiés accessibles depuis le profil (données sensibles, cf.
/// CLAUDE.md), hors périmètre de cet écran.
class CommunauteScreen extends StatelessWidget {
  const CommunauteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  labelColor: AppColors.emerald,
                  unselectedLabelColor: AppColors.bronze,
                  indicatorColor: AppColors.emerald,
                  tabs: [
                    Tab(text: l10n.communityFeedTab),
                    Tab(text: l10n.communityGroupsTab),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.mail_outline, color: AppColors.bronze),
                tooltip: l10n.communityMessagesTooltip,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ConversationsScreen()),
                ),
              ),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _FeedTab(),
                _GroupsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final feed = ref.watch(communityFeedProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'communaute_create_post',
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.communityCreatePostButton),
      ),
      body: feed.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.communityLoadError,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(communityFeedProvider),
                  child: Text(l10n.communityRetry),
                ),
              ],
            ),
          ),
        ),
        data: (posts) => posts.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.communityFeedEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.bronze)),
                ),
              )
            : ListView.builder(
                // 100 plutôt que la seule hauteur du FAB : celui-ci masquait
                // encore le bas de la dernière carte (image d'une
                // publication) avec une marge de 88 — constaté à l'audit
                // design pré-publication Play Store.
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: posts.length,
                itemBuilder: (context, i) => _PostCard(
                    post: posts[i],
                    fallbackAuthor: l10n.communityDefaultAuthor),
              ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.communityCreatePostSignInRequired)));
      return;
    }
    final profile = ref.read(myProfileProvider).valueOrNull;
    if (profile?.zawiyaId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.communityCreatePostNeedsZawiya)));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.offWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _CreatePostSheet(
          zawiyaId: profile!.zawiyaId!, zawiyaName: profile.zawiyaName),
    );
  }
}

class _CreatePostSheet extends ConsumerStatefulWidget {
  const _CreatePostSheet({required this.zawiyaId, this.zawiyaName});

  final String zawiyaId;
  final String? zawiyaName;

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _imageUploadService = ImageUploadService();
  bool _saving = false;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
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
    });
  }

  void _clearImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageExtension = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? mediaUrl;
      if (_pickedImageBytes != null) {
        final userId = SupabaseConfig.client.auth.currentUser!.id;
        mediaUrl = await _imageUploadService.uploadImage(
          bucket: 'post-media',
          path:
              '$userId/${DateTime.now().microsecondsSinceEpoch}.$_pickedImageExtension',
          bytes: _pickedImageBytes!,
          contentType: imageContentTypeForExtension(_pickedImageExtension!),
        );
      }
      await ref.read(communityRepositoryProvider).createPost(
            _contentController.text.trim(),
            zawiyaId: widget.zawiyaId,
            mediaUrl: mediaUrl,
          );
      ref.invalidate(communityFeedProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // `SafeArea` : évite que le bouton Publier se retrouve masqué sous la
    // barre de navigation Android (3 boutons) — `viewInsets.bottom` seul ne
    // couvre que le clavier, jamais la zone système.
    // `SingleChildScrollView` : une fois une image ajoutée, le contenu peut
    // dépasser la hauteur du bottom sheet (contraint à l'écran) ; sans lui,
    // le `Column` déborde silencieusement et les boutons "Changer l'image"
    // / "Publier" se retrouvent hors champ, masqués sous la nav-bar Android.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.communityCreatePostTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              if (widget.zawiyaName != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.communityCreatePostZawiyaNote} (${widget.zawiyaName})',
                  style: TextStyle(color: AppColors.bronze, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                    labelText: l10n.communityCreatePostContentLabel),
                maxLines: 5,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.communityCreatePostContentRequired
                    : null,
              ),
              const SizedBox(height: 12),
              if (_pickedImageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_pickedImageBytes!,
                      width: double.infinity, fit: BoxFit.fitWidth),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_pickedImageBytes != null
                          ? l10n.imagePickerChange
                          : l10n.imagePickerAdd),
                    ),
                  ),
                  if (_pickedImageBytes != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.bronze),
                      onPressed: _clearImage,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.communityCreatePostSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final groups = ref.watch(groupsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'communaute_create_group',
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.communityGroupsCreateButton),
      ),
      body: groups.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: AppColors.bronze, size: 32),
                const SizedBox(height: 12),
                Text(l10n.communityGroupsLoadError,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.bronze)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(groupsProvider),
                  child: Text(l10n.communityGroupsRetry),
                ),
              ],
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.communityGroupsEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.bronze)),
                ),
              )
            : ListView.builder(
                // 100 plutôt que la seule hauteur du FAB : celui-ci masquait
                // encore le bas de la dernière carte (image d'une
                // publication) avec une marge de 88 — constaté à l'audit
                // design pré-publication Play Store.
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: list.length,
                itemBuilder: (context, i) => _GroupCard(group: list[i]),
              ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(l10n.communityGroupsSignInToCreate)));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.offWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _CreateGroupSheet(),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(group.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.ink)),
              if (group.description != null) ...[
                const SizedBox(height: 6),
                Text(
                  group.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.ink, fontSize: 14),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (group.locationLabel != null) ...[
                    Icon(Icons.place_outlined,
                        size: 16, color: AppColors.bronze),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        group.locationLabel!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.bronze, fontSize: 13),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Icon(Icons.people_alt_outlined,
                      size: 16, color: AppColors.bronze),
                  const SizedBox(width: 4),
                  Text('${group.memberCount}',
                      style: TextStyle(
                          color: AppColors.bronze, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _regionController = TextEditingController();
  String? _zawiyaId;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(groupsRepositoryProvider).createGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            zawiyaId: _zawiyaId,
            regionText: _regionController.text.trim().isEmpty
                ? null
                : _regionController.text.trim(),
          );
      ref.invalidate(groupsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final zawiyas = ref.watch(zawiyasProvider);

    // `SafeArea` : évite que le bouton Créer se retrouve masqué sous la
    // barre de navigation Android (3 boutons) — `viewInsets.bottom` seul ne
    // couvre que le clavier, jamais la zone système. `SingleChildScrollView`
    // (même choix que _CreatePostSheet) : évite un overflow du formulaire
    // une fois le clavier affiché avec une description longue.
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.communityGroupsCreateTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration:
                    InputDecoration(labelText: l10n.communityGroupsNameLabel),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.communityGroupsNameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                    labelText: l10n.communityGroupsDescriptionLabel),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              zawiyas.when(
                loading: () =>
                    LinearProgressIndicator(color: AppColors.emerald),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (list) => DropdownButtonFormField<String?>(
                  initialValue: _zawiyaId,
                  decoration: InputDecoration(
                      labelText: l10n.communityGroupsZawiyaLabel),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('—')),
                    ...list.map((z) => DropdownMenuItem<String?>(
                        value: z.id, child: Text(z.name))),
                  ],
                  onChanged: (value) => setState(() => _zawiyaId = value),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regionController,
                decoration:
                    InputDecoration(labelText: l10n.communityGroupsRegionLabel),
              ),
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
                    : Text(l10n.communityGroupsCreateSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({required this.post, required this.fallbackAuthor});

  final CommunityPost post;
  final String fallbackAuthor;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  // État local optimiste — même principe que PostDetailScreen._toggleLike :
  // aimer depuis le fil ne doit pas recharger toute la liste juste pour
  // refléter un compteur.
  late bool _liked = widget.post.isLikedByMe;
  late int _likeCount = widget.post.likeCount;
  bool _likeInFlight = false;

  bool get _isSignedIn => SupabaseConfig.client.auth.currentUser != null;

  void _promptSignIn() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.communitySignInToInteract)));
  }

  Future<void> _toggleLike() async {
    if (!_isSignedIn) {
      _promptSignIn();
      return;
    }
    if (_likeInFlight) return;
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
      _likeInFlight = true;
    });
    try {
      await ref
          .read(communityRepositoryProvider)
          .toggleLike(widget.post.id, currentlyLiked: wasLiked);
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final fallbackAuthor = widget.fallbackAuthor;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.authorLabel(fallbackAuthor),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.ink),
                    ),
                  ),
                  Text(formatCommunityDateTime(post.createdAt),
                      style: TextStyle(
                          color: AppColors.bronze, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.contentText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.ink, fontSize: 15),
              ),
              if (post.mediaUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.mediaUrl!,
                    // Pas de hauteur fixe — même choix que le bandeau de
                    // couverture Khadara (event_detail_screen.dart) : une
                    // hauteur fixe coupe la photo selon son orientation.
                    width: double.infinity,
                    // cacheWidth : voir la même note dans event_detail_screen.dart.
                    cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round(),
                    fit: BoxFit.fitWidth,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  // InkWell propre à cette zone : intercepte le tap avant
                  // qu'il n'atteigne l'InkWell de la carte (qui ouvre le
                  // détail), pour pouvoir aimer sans quitter le fil.
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _toggleLike,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            _liked ? Icons.favorite : Icons.favorite_border,
                            color:
                                _liked ? AppColors.emerald : AppColors.bronze,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text('$_likeCount',
                              style: TextStyle(
                                  color: AppColors.bronze, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.mode_comment_outlined,
                      color: AppColors.bronze, size: 18),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}',
                      style: TextStyle(
                          color: AppColors.bronze, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
