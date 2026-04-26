import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/share_link_model.dart';
import '../../services/share_link_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';

class ShareLinkScreen extends StatefulWidget {
  final String linkId;
  const ShareLinkScreen({super.key, required this.linkId});

  @override
  State<ShareLinkScreen> createState() => _ShareLinkScreenState();
}

class _ShareLinkScreenState extends State<ShareLinkScreen> {
  final _service = ShareLinkService();
  ShareLinkModel? _link;
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _fetchLink();
  }

  Future<void> _fetchLink() async {
    try {
      final link = await _service.fetchLink(widget.linkId);
      if (mounted) {
        setState(() {
          _link  = link;
          _error = link == null ? 'This link no longer exists or has been removed.' : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error   = 'Could not load this link. Check your connection.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _downloadMedia() async {
    final link = _link;
    if (link == null || link.mediaUrls.isEmpty) return;

    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Preparing files…'),
      duration: Duration(seconds: 30),
    ));

    try {
      final tmpDir = await getTemporaryDirectory();
      final xFiles = <XFile>[];
      for (int i = 0; i < link.mediaUrls.length; i++) {
        final bytes = await StorageService().downloadFile(link.mediaUrls[i]);
        final ext = (i < link.mediaTypes.length && link.mediaTypes[i] == 'video')
            ? 'mp4'
            : 'jpg';
        final file = File('${tmpDir.path}/luma_sl_${link.id}_$i.$ext');
        await file.writeAsBytes(bytes);
        xFiles.add(XFile(file.path));
      }
      messenger.hideCurrentSnackBar();
      await Share.shareXFiles(
        xFiles,
        subject: link.eventTitle,
        text: link.note.isNotEmpty ? link.note : null,
      );
    } catch (_) {
      messenger.hideCurrentSnackBar();
      final text = [
        if (link.note.isNotEmpty) link.note,
        ...link.mediaUrls,
      ].join('\n');
      await Share.share(text, subject: link.eventTitle);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _link == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Shared memory'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off_outlined,
                    size: 56,
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(_error ?? 'Something went wrong.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }

    final link   = _link!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dtFmt  = DateFormat('EEEE, MMM d yyyy · h:mm a');

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(link.eventTitle, style: const TextStyle(fontSize: 15)),
        actions: [
          if (link.downloadEnabled && link.mediaUrls.isNotEmpty)
            IconButton(
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined),
              tooltip: 'Download all',
              onPressed: _downloading ? null : _downloadMedia,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Media carousel ────────────────────────────────
            if (link.mediaUrls.isNotEmpty) ...[
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Colors.black),
                    PageView.builder(
                      itemCount: link.mediaUrls.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) {
                        return link.mediaTypes[i] == 'image'
                            ? CachedNetworkImage(
                                imageUrl: link.mediaUrls[i],
                                fit: BoxFit.contain,
                                placeholder: (_, __) =>
                                    const ColoredBox(color: Colors.black),
                                errorWidget: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined,
                                        color: Colors.white54)),
                              )
                            : const Center(
                                child: Icon(Icons.play_circle_outline,
                                    size: 56, color: Colors.white),
                              );
                      },
                    ),
                  ],
                ),
              ),
              if (link.mediaUrls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(link.mediaUrls.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _page == i ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? Theme.of(context).colorScheme.primary
                              : AppTheme.grey300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
            ],

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Shared-by banner ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : AppTheme.grey100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.grey300,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              isDark ? AppTheme.darkBorder : AppTheme.grey200,
                          child: Text(
                            (link.ownerName.isNotEmpty
                                    ? link.ownerName[0]
                                    : '?')
                                .toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(link.ownerName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            Text('shared this memory with you',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 13,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 5),
                      Text(
                        dtFmt.format(link.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),

                  // Location
                  if (link.locationName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13,
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            link.locationName,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                  fontSize: 12,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Mood
                  if (link.mood != null) ...[
                    const SizedBox(height: 12),
                    _MoodBadge(mood: link.mood!),
                  ],

                  // Note
                  if (link.note.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(link.note,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.6)),
                  ],

                  // Download CTA
                  if (link.downloadEnabled && link.mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _downloading ? null : _downloadMedia,
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Download / Share'),
                      ),
                    ),
                  ],

                  if (!link.downloadEnabled && link.mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 14,
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 6),
                        Text(
                          'Download disabled by the owner.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Local mood badge (mirrors the one in memory_detail_screen) ──

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
            color: isDark ? AppTheme.darkBorder : AppTheme.grey300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          Text(mood,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary)),
        ],
      ),
    );
  }
}
