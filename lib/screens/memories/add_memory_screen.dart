import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/memory_provider.dart';
import '../../models/event_model.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

// Mood options: emoji + label pairs
const _kMoods = [
  ('😊', 'Happy'),
  ('🤩', 'Excited'),
  ('😌', 'Peaceful'),
  ('🙏', 'Grateful'),
  ('🥹', 'Nostalgic'),
  ('😢', 'Sad'),
  ('🤯', 'Overwhelmed'),
  ('😴', 'Tired'),
];

class AddMemoryScreen extends StatefulWidget {
  final EventModel event;
  const AddMemoryScreen({super.key, required this.event});

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  final _noteCtrl = TextEditingController();
  final _picker   = ImagePicker();

  final List<File>   _mediaFiles = [];
  final List<String> _mediaTypes = [];

  String? _selectedMood;
  LocationResult? _location;
  bool _fetchingLocation = false;
  bool _isSaving         = false;

  @override
  void initState() {
    super.initState();
    _autoFetchLocation();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoFetchLocation() async {
    setState(() => _fetchingLocation = true);
    final result = await context.read<MemoryProvider>().fetchLocation();
    if (mounted) setState(() { _location = result; _fetchingLocation = false; });
  }

  // Single photo or video from camera
  Future<void> _pickSingle(ImageSource source, {bool isVideo = false}) async {
    final XFile? file = isVideo
        ? await _picker.pickVideo(source: source)
        : await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _mediaFiles.add(File(file.path));
      _mediaTypes.add(isVideo ? 'video' : 'image');
    });
  }

  // Multi-select from gallery — picks both images and videos
  Future<void> _pickMultipleFromGallery() async {
    final files = await _picker.pickMultipleMedia();
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        _mediaFiles.add(File(f.path));
        _mediaTypes.add(_isVideoPath(f.path) ? 'video' : 'image');
      }
    });
  }

  bool _isVideoPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'm4v'].contains(ext);
  }

  void _showMediaSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.grey300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            _SheetOption(
              icon: Icons.camera_alt_outlined,
              label: 'Take photo',
              onTap: () { Navigator.pop(context); _pickSingle(ImageSource.camera); },
            ),
            _SheetOption(
              icon: Icons.videocam_outlined,
              label: 'Record video',
              onTap: () { Navigator.pop(context); _pickSingle(ImageSource.camera, isVideo: true); },
            ),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              subtitle: 'Photos & videos — select multiple',
              onTap: () { Navigator.pop(context); _pickMultipleFromGallery(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
      _mediaTypes.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_noteCtrl.text.trim().isEmpty && _mediaFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a note or photo to continue.')));
      return;
    }
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    final ok = await context.read<MemoryProvider>().createMemory(
      uid: uid,
      eventId: widget.event.id,
      note: _noteCtrl.text.trim(),
      mediaFiles: _mediaFiles,
      mediaTypes: _mediaTypes,
      latitude: _location?.latitude ?? 0.0,
      longitude: _location?.longitude ?? 0.0,
      locationName: _location?.placeName ?? '',
      mood: _selectedMood,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      NotificationService.showLocalNotification(
        title: 'Memory saved',
        body: 'Your moment was added to "${widget.event.title}".',
      );
      Navigator.of(context).pop();
    } else {
      final err = context.read<MemoryProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Failed to save. Check your connection.'),
        backgroundColor: Colors.red[700],
      ));
      context.read<MemoryProvider>().clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Add memory'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
        bottom: (_isSaving && _mediaFiles.isNotEmpty)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: null, // indeterminate — Supabase doesn't stream progress
                  minHeight: 4,
                  backgroundColor: Theme.of(context)
                      .colorScheme.primary.withValues(alpha: 0.15),
                ),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Media picker row ──────────────────────────
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: _showMediaSheet,
                    child: Container(
                      width: 90, height: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.grey200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark ? AppTheme.darkBorder : AppTheme.grey300,
                            width: 0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 24,
                              color: Theme.of(context).colorScheme.secondary),
                          const SizedBox(height: 4),
                          Text('Add media',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 10,
                                      color: Theme.of(context).colorScheme.secondary)),
                        ],
                      ),
                    ),
                  ),
                  ..._mediaFiles.asMap().entries.map((e) {
                    final i = e.key;
                    return Stack(
                      children: [
                        Container(
                          width: 90, height: 90,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: _mediaTypes[i] == 'image'
                                ? DecorationImage(
                                    image: FileImage(_mediaFiles[i]),
                                    fit: BoxFit.cover)
                                : null,
                            color: isDark ? AppTheme.darkBorder : AppTheme.grey300,
                          ),
                          child: _mediaTypes[i] == 'video'
                              ? const Center(
                                  child: Icon(Icons.videocam, size: 28, color: Colors.white70))
                              : null,
                        ),
                        Positioned(
                          top: 4, right: 14,
                          child: GestureDetector(
                            onTap: () => _removeMedia(i),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Note ─────────────────────────────────────
            _Label('Write a note'),
            const SizedBox(height: 6),
            TextField(
              controller: _noteCtrl,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'What happened? How did it feel?'),
            ),
            const SizedBox(height: 20),

            // ── Mood picker ───────────────────────────────
            _Label('Mood  (optional)'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kMoods.map((m) {
                final emoji = m.$1;
                final label = m.$2;
                final selected = _selectedMood == label;
                return GestureDetector(
                  onTap: () => setState(() =>
                      _selectedMood = selected ? null : label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : isDark ? AppTheme.darkSurface : AppTheme.grey100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : isDark ? AppTheme.darkBorder : AppTheme.grey300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Theme.of(context).scaffoldBackgroundColor
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Location ──────────────────────────────────
            _Label('Location'),
            const SizedBox(height: 8),
            _LocationRow(
              isLoading: _fetchingLocation,
              placeName: _location?.placeName,
              onRefresh: _autoFetchLocation,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w600));
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _SheetOption(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary))
          : null,
      onTap: onTap,
    );
  }
}

class _LocationRow extends StatelessWidget {
  final bool isLoading;
  final String? placeName;
  final VoidCallback onRefresh;
  const _LocationRow(
      {required this.isLoading,
      required this.placeName,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on_outlined,
            size: 16, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: isLoading
              ? const Text('Fetching location…',
                  style: TextStyle(fontSize: 13, color: AppTheme.grey500))
              : Text(
                  placeName ?? 'Location unavailable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary),
                ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 16),
          onPressed: onRefresh,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ],
    );
  }
}
