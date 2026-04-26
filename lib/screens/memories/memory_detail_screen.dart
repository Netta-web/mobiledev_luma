import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/share_link_model.dart';
import '../../services/share_link_service.dart';
import '../../services/notification_service.dart';
import '../../models/memory_entry_model.dart';
import '../../models/event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/sharing_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';

class MemoryDetailScreen extends StatefulWidget {
  final MemoryEntryModel memory;
  final EventModel event;

  const MemoryDetailScreen({
    super.key,
    required this.memory,
    required this.event,
  });

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  int _currentMediaIndex = 0;
  // Local mutable copy so UI reflects media deletions and share updates immediately
  late MemoryEntryModel _memory;
  late List<String> _sharedWith;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _memory    = widget.memory;
    _sharedWith = List.from(widget.memory.sharedWith);
    _myUid     = context.read<AuthProvider>().user?.uid;
  }

  bool get _hasLocation =>
      _memory.latitude != 0.0 || _memory.longitude != 0.0;

  // ── Download / share all media as files ─────────────────────
  Future<void> _downloadMedia() async {
    final urls = _memory.mediaUrls;
    if (urls.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Preparing files…'),
      duration: Duration(seconds: 30),
    ));

    try {
      final tmpDir = await getTemporaryDirectory();
      final xFiles = <XFile>[];

      for (int i = 0; i < urls.length; i++) {
        final bytes = await StorageService().downloadFile(urls[i]);
        final ext   = (i < _memory.mediaTypes.length && _memory.mediaTypes[i] == 'video')
            ? 'mp4'
            : 'jpg';
        final file  = File('${tmpDir.path}/luma_${_memory.id}_$i.$ext');
        await file.writeAsBytes(bytes);
        xFiles.add(XFile(file.path));
      }

      messenger.hideCurrentSnackBar();
      await Share.shareXFiles(
        xFiles,
        subject: widget.event.title,
        text: _memory.note.isNotEmpty ? _memory.note : null,
      );
    } catch (_) {
      messenger.hideCurrentSnackBar();
      // Fallback: share public URLs as plain text
      final text = [
        if (_memory.note.isNotEmpty) _memory.note,
        ...urls,
      ].join('\n');
      await Share.share(text, subject: widget.event.title);
    }
  }

  // ── Delete a single media item from the memory ───────────────
  Future<void> _deleteCurrentMedia() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this item?'),
        content: const Text(
            'This photo or video will be permanently deleted from the memory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final uid      = _myUid ?? '';
    final idx      = _currentMediaIndex;
    final urlToRemove = _memory.mediaUrls[idx];

    final newUrls  = List<String>.from(_memory.mediaUrls)..removeAt(idx);
    final newTypes = List<String>.from(_memory.mediaTypes)..removeAt(idx);

    final updated = MemoryEntryModel(
      id:           _memory.id,
      eventId:      _memory.eventId,
      userId:       _memory.userId,
      note:         _memory.note,
      mediaUrls:    newUrls,
      mediaTypes:   newTypes,
      voiceNoteUrl: _memory.voiceNoteUrl,
      latitude:     _memory.latitude,
      longitude:    _memory.longitude,
      locationName: _memory.locationName,
      createdAt:    _memory.createdAt,
      sharedWith:   _memory.sharedWith,
      mood:         _memory.mood,
    );

    // Update Firestore first so the delete is persisted even if storage cleanup fails
    await FirestoreService().updateMemory(uid, _memory.eventId, updated);
    await StorageService().deleteFile(urlToRemove);

    if (!mounted) return;
    setState(() {
      _memory = updated;
      _currentMediaIndex =
          idx >= newUrls.length ? (newUrls.isEmpty ? 0 : newUrls.length - 1) : idx;
    });
  }

  // ── Shareable link management ────────────────────────────────
  void _openLinkSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _LinkSheet(
        memory: _memory,
        event: widget.event,
        ownerName: context.read<AuthProvider>().user?.displayName ?? '',
        isOwner: _myUid == _memory.userId,
      ),
    );
  }

  // ── Share memory with a contact ─────────────────────────────
  void _openShareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ShareSheet(
        memory: _memory,
        event: widget.event,
        currentSharedWith: _sharedWith,
        onSharedWithChanged: (updated) =>
            setState(() => _sharedWith = updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m     = _memory;
    final dtFmt = DateFormat('EEEE, MMM d yyyy · h:mm a');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────
          SliverAppBar(
            pinned: true,
            leading: const BackButton(),
            title: Text(widget.event.title,
                style: const TextStyle(fontSize: 15)),
            actions: [
              // Download / share media
              if (m.mediaUrls.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download',
                  onPressed: _downloadMedia,
                ),
              // Shareable link
              if (_myUid == m.userId)
                IconButton(
                  icon: const Icon(Icons.link_outlined),
                  tooltip: 'Shareable link',
                  onPressed: _openLinkSheet,
                ),
              // Share with a contact
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: 'Share with someone',
                onPressed: _openShareSheet,
              ),
            ],
          ),

          // ── Media carousel ─────────────────────────────
          if (m.mediaUrls.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Black background so letterboxed images look intentional
                        const ColoredBox(color: Colors.black),
                        PageView.builder(
                          itemCount: m.mediaUrls.length,
                          onPageChanged: (i) =>
                              setState(() => _currentMediaIndex = i),
                          itemBuilder: (_, i) {
                            final url  = m.mediaUrls[i];
                            final type = m.mediaTypes[i];
                            return type == 'image'
                                ? CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) =>
                                        const ColoredBox(color: Colors.black),
                                    errorWidget: (_, __, ___) => const Center(
                                        child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white54)),
                                  )
                                : const Center(
                                    child: Icon(Icons.play_circle_outline,
                                        size: 56, color: Colors.white),
                                  );
                          },
                        ),
                        // Delete button — owner only
                        if (_myUid == m.userId)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _MediaDeleteButton(
                                onTap: _deleteCurrentMedia),
                          ),
                      ],
                    ),
                  ),
                  if (m.mediaUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(m.mediaUrls.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentMediaIndex == i ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentMediaIndex == i
                                  ? Theme.of(context).colorScheme.primary
                                  : AppTheme.grey300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),

          // ── Body ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & time
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 13,
                          color:
                              Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 5),
                      Text(
                        dtFmt.format(m.createdAt),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme.secondary,
                                  fontSize: 12,
                                ),
                      ),
                    ],
                  ),

                  // Location name
                  if (m.locationName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13,
                            color: Theme.of(context)
                                .colorScheme.secondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            m.locationName,
                            style: Theme.of(context)
                                .textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme.secondary,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Mood badge
                  if (m.mood != null) ...[
                    const SizedBox(height: 12),
                    _MoodBadge(mood: m.mood!),
                  ],

                  // Note
                  if (m.note.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(m.note,
                        style: Theme.of(context)
                            .textTheme.bodyLarge
                            ?.copyWith(height: 1.6)),
                  ],

                  // ── Inline map ───────────────────────────
                  if (_hasLocation) ...[
                    const SizedBox(height: 20),
                    _SectionLabel('Location'),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 180,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                                m.latitude, m.longitude),
                            zoom: 14,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('loc'),
                              position:
                                  LatLng(m.latitude, m.longitude),
                            ),
                          },
                          // Locked — decorative only
                          scrollGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          mapToolbarEnabled: false,
                        ),
                      ),
                    ),
                  ],

                  // ── Shared with ──────────────────────────
                  if (_sharedWith.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionLabel('Shared with'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sharedWith
                          .map((e) => _ContactChip(email: e))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Share bottom sheet ─────────────────────────────────────────

class _ShareSheet extends StatefulWidget {
  final MemoryEntryModel memory;
  final EventModel event;
  final List<String> currentSharedWith;
  final ValueChanged<List<String>> onSharedWithChanged;

  const _ShareSheet({
    required this.memory,
    required this.event,
    required this.currentSharedWith,
    required this.onSharedWithChanged,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _sharing   = SharingService();
  final _firestore = FirestoreService();

  late List<String> _sharedWith;
  bool _isSaving   = false;
  bool _isSendingSms = false;
  String? _error;
  String? _smsError;

  @override
  void initState() {
    super.initState();
    _sharedWith = List.from(widget.currentSharedWith);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted || !mounted) return;
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;
      final fullContact = await FlutterContacts.getContact(contact.id);
      final email = fullContact?.emails.firstOrNull?.address ?? '';
      if (email.isNotEmpty) {
        _emailCtrl.text = email;
        setState(() => _error = null);
      } else {
        setState(() => _error = 'That contact has no email address.');
      }
    } catch (_) {
      setState(() => _error = 'Could not open contacts.');
    }
  }

  Future<void> _pickContactPhone() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted || !mounted) return;
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;
      final fullContact = await FlutterContacts.getContact(contact.id);
      final phone = fullContact?.phones.firstOrNull?.number ?? '';
      if (phone.isNotEmpty) {
        _phoneCtrl.text = phone;
        setState(() => _smsError = null);
      } else {
        setState(() => _smsError = 'That contact has no phone number.');
      }
    } catch (_) {
      setState(() => _smsError = 'Could not open contacts.');
    }
  }

  Future<void> _sendSms() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _smsError = 'Enter a phone number.');
      return;
    }
    setState(() { _isSendingSms = true; _smsError = null; });

    final auth     = context.read<AuthProvider>();
    final sender   = auth.user?.displayName ?? 'Someone';
    final parts    = <String>[
      '$sender shared a memory with you from "${widget.event.title}" on Luma.',
      if (widget.memory.note.isNotEmpty) widget.memory.note,
      ...widget.memory.mediaUrls,
    ];
    final body = parts.join('\n\n');

    // Normalise the phone number for the sms: URI (strip spaces/dashes)
    final digits = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri    = Uri(scheme: 'sms', path: digits,
        queryParameters: {'body': body});

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) _phoneCtrl.clear();
      } else {
        setState(() => _smsError = 'No SMS app found on this device.');
      }
    } catch (_) {
      setState(() => _smsError = 'Could not open SMS app.');
    } finally {
      if (mounted) setState(() => _isSendingSms = false);
    }
  }

  Future<void> _share() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = 'Enter an email address.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Please enter a valid email.');
      return;
    }
    if (_sharedWith.contains(email)) {
      setState(() => _error = 'Already shared with $email.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final uid  = auth.user?.uid ?? '';
    final name = auth.user?.displayName ?? 'Someone';
    final fromEmail = auth.user?.email ?? '';

    setState(() { _isSaving = true; _error = null; });
    try {
      await _sharing.shareMemory(
        fromUid: uid,
        fromName: name,
        fromEmail: fromEmail,
        memory: widget.memory,
        event: widget.event,
        recipientEmail: email,
      );

      // Persist updated sharedWith list on the memory document
      final updated = [..._sharedWith, email];
      final updatedMemory = MemoryEntryModel(
        id: widget.memory.id,
        eventId: widget.memory.eventId,
        userId: widget.memory.userId,
        note: widget.memory.note,
        mediaUrls: widget.memory.mediaUrls,
        mediaTypes: widget.memory.mediaTypes,
        voiceNoteUrl: widget.memory.voiceNoteUrl,
        latitude: widget.memory.latitude,
        longitude: widget.memory.longitude,
        locationName: widget.memory.locationName,
        createdAt: widget.memory.createdAt,
        sharedWith: updated,
        mood: widget.memory.mood,
      );
      await _firestore.updateMemory(uid, widget.memory.eventId, updatedMemory);

      setState(() { _sharedWith = updated; _isSaving = false; });
      _emailCtrl.clear();
      widget.onSharedWithChanged(_sharedWith);
      NotificationService.showLocalNotification(
        title: 'Memory shared',
        body: 'Your memory was shared with $email.',
      );
    } catch (e) {
      setState(() { _error = 'Failed to share. Try again.'; _isSaving = false; });
    }
  }

  Future<void> _revoke(String email) async {
    final uid = context.read<AuthProvider>().user?.uid ?? '';
    try {
      await _sharing.revokeShareForMemory(
        recipientEmail: email,
        originalMemoryId: widget.memory.id,
      );
      final updated = _sharedWith.where((e) => e != email).toList();
      final updatedMemory = MemoryEntryModel(
        id: widget.memory.id,
        eventId: widget.memory.eventId,
        userId: widget.memory.userId,
        note: widget.memory.note,
        mediaUrls: widget.memory.mediaUrls,
        mediaTypes: widget.memory.mediaTypes,
        voiceNoteUrl: widget.memory.voiceNoteUrl,
        latitude: widget.memory.latitude,
        longitude: widget.memory.longitude,
        locationName: widget.memory.locationName,
        createdAt: widget.memory.createdAt,
        sharedWith: updated,
        mood: widget.memory.mood,
      );
      await _firestore.updateMemory(uid, widget.memory.eventId, updatedMemory);
      setState(() => _sharedWith = updated);
      widget.onSharedWithChanged(_sharedWith);
    } catch (_) {
      // silent — UI will remain consistent
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.grey300,
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),

            Text('Share this memory',
              style: Theme.of(context)
                  .textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Recipients can view and download this memory.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary)),
            const SizedBox(height: 16),

            // Email input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _share(),
                    decoration: const InputDecoration(
                      hintText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined, size: 18)),
                  ),
                ),
                const SizedBox(width: 8),
                // Pick from contacts
                _IconRoundButton(
                  icon: Icons.contacts_outlined,
                  onTap: _pickContact,
                  tooltip: 'Pick from contacts',
                ),
                const SizedBox(width: 8),
                // Share button
                _IconRoundButton(
                  icon: _isSaving
                      ? Icons.hourglass_empty
                      : Icons.send_outlined,
                  onTap: _isSaving ? null : _share,
                  filled: true,
                  tooltip: 'Share',
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            // ── SMS divider ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or send link via SMS',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.secondary)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            ),

            // Phone number row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _sendSms(),
                    decoration: const InputDecoration(
                      hintText: 'Phone number',
                      prefixIcon: Icon(Icons.phone_outlined, size: 18)),
                  ),
                ),
                const SizedBox(width: 8),
                _IconRoundButton(
                  icon: Icons.contacts_outlined,
                  onTap: _pickContactPhone,
                  tooltip: 'Pick from contacts',
                ),
                const SizedBox(width: 8),
                _IconRoundButton(
                  icon: _isSendingSms
                      ? Icons.hourglass_empty
                      : Icons.sms_outlined,
                  onTap: _isSendingSms ? null : _sendSms,
                  filled: true,
                  tooltip: 'Send SMS',
                ),
              ],
            ),

            if (_smsError != null) ...[
              const SizedBox(height: 8),
              Text(_smsError!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],

            // Shared-with list
            if (_sharedWith.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Shared with',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...(_sharedWith.map((email) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          isDark ? AppTheme.darkBorder : AppTheme.grey200,
                      child: Text(
                        email[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    title: Text(email,
                      style: Theme.of(context).textTheme.bodyMedium),
                    trailing: GestureDetector(
                      onTap: () => _revoke(email),
                      child: const Icon(Icons.close,
                          size: 16, color: AppTheme.grey500),
                    ),
                  ))),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Small reusable widgets ─────────────────────────────────────

class _MoodBadge extends StatelessWidget {
  final String mood;
  const _MoodBadge({required this.mood});

  static const _emojiMap = {
    'Happy': '😊', 'Excited': '🤩', 'Peaceful': '😌', 'Grateful': '🙏',
    'Nostalgic': '🥹', 'Sad': '😢', 'Overwhelmed': '🤯', 'Tired': '😴',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emoji  = _emojiMap[mood] ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.grey100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.grey300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          Text(mood,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.secondary,
            )),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w600));
  }
}

class _ContactChip extends StatelessWidget {
  final String email;
  const _ContactChip({required this.email});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.grey200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.grey300,
            width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 12),
          const SizedBox(width: 4),
          Text(email, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ── Shareable link management sheet ───────────────────────────

class _LinkSheet extends StatefulWidget {
  final MemoryEntryModel memory;
  final EventModel event;
  final String ownerName;
  final bool isOwner;

  const _LinkSheet({
    required this.memory,
    required this.event,
    required this.ownerName,
    required this.isOwner,
  });

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  final _service = ShareLinkService();

  ShareLinkModel? _link;
  bool _loading    = true;
  bool _creating   = false;
  bool _newDownload = true; // toggle value before first link is created

  @override
  void initState() {
    super.initState();
    _loadLink();
  }

  Future<void> _loadLink() async {
    try {
      final links = await _service.getLinksForMemory(widget.memory.id);
      if (mounted) {
        setState(() {
          _link    = links.isNotEmpty ? links.first : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createLink() async {
    setState(() => _creating = true);
    try {
      final draft = ShareLinkModel(
        id:              '',
        ownerId:         widget.memory.userId,
        ownerName:       widget.ownerName,
        memoryId:        widget.memory.id,
        eventTitle:      widget.event.title,
        note:            widget.memory.note,
        mediaUrls:       widget.memory.mediaUrls,
        mediaTypes:      widget.memory.mediaTypes,
        locationName:    widget.memory.locationName,
        mood:            widget.memory.mood,
        downloadEnabled: _newDownload,
        createdAt:       DateTime.now(),
      );
      final id      = await _service.createLink(draft);
      final created = await _service.fetchLink(id);
      if (mounted) setState(() { _link = created; _creating = false; });
    } catch (_) {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _toggleDownload(bool enabled) async {
    final link = _link;
    if (link == null) return;
    await _service.setDownloadEnabled(link.id, enabled);
    if (mounted) setState(() => _link = link.copyWithDownload(enabled));
  }

  Future<void> _deleteLink() async {
    final link = _link;
    if (link == null) return;
    await _service.deleteLink(link.id);
    if (mounted) setState(() => _link = null);
  }

  void _copyLink() {
    final link = _link;
    if (link == null) return;
    Clipboard.setData(ClipboardData(text: 'luma://s/${link.id}'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Link copied to clipboard'),
      duration: Duration(seconds: 2),
    ));
  }

  void _shareLink() {
    final link = _link;
    if (link == null) return;
    Share.share(
      'luma://s/${link.id}',
      subject: widget.event.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppTheme.grey300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            Text('Shareable link',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Anyone with the link can view this memory — no Luma account required.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_link == null) ...[
              // ── Create mode ──
              Row(
                children: [
                  Expanded(
                    child: Text('Allow download',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Switch(
                    value: _newDownload,
                    onChanged: (v) => setState(() => _newDownload = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _creating ? null : _createLink,
                  icon: _creating
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.link_outlined, size: 18),
                  label: const Text('Create link'),
                ),
              ),
            ] else ...[
              // ── Manage mode ──
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBorder : AppTheme.grey100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkBorder
                        : AppTheme.grey300,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'luma://s/${_link!.id}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _copyLink,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Copy',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .scaffoldBackgroundColor,
                            )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _shareLink,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share link'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Allow download',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Switch(
                    value: _link!.downloadEnabled,
                    onChanged: _toggleDownload,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _deleteLink,
                icon: const Icon(Icons.link_off_outlined,
                    size: 16, color: Colors.red),
                label: const Text('Remove link',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaDeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MediaDeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, size: 20, color: Colors.white),
      ),
    );
  }
}

class _IconRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final String? tooltip;
  const _IconRoundButton({
    required this.icon,
    this.onTap,
    this.filled = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: filled
                ? Theme.of(context).colorScheme.primary
                : (isDark ? AppTheme.darkBorder : AppTheme.grey200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
            size: 18,
            color: filled
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
