import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/shared_memory_model.dart';
import '../../services/sharing_service.dart';
import '../../theme/app_theme.dart';

class SharedWithMeScreen extends StatelessWidget {
  const SharedWithMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Shared with me'),
      ),
      body: email.isEmpty
          ? const Center(child: Text('Not signed in.'))
          : StreamBuilder<List<SharedMemoryModel>>(
              stream: SharingService().watchReceivedMemories(email),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return _EmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _SharedMemoryTile(item: items[i]),
                );
              },
            ),
    );
  }
}

class _SharedMemoryTile extends StatelessWidget {
  final SharedMemoryModel item;
  const _SharedMemoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('MMM d, yyyy');

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _SharedMemoryDetail(item: item),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.grey100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.grey300,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(13)),
              child: item.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: item.thumbnailUrl!,
                      width: 80, height: 80,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          _placeholder(isDark),
                      errorWidget: (_, __, ___) =>
                          _placeholder(isDark),
                    )
                  : _placeholder(isDark),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // From + event
                    Text(
                      item.eventTitle,
                      style: Theme.of(context)
                          .textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From ${item.sharedByName}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme.secondary),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      dateFmt.format(item.sharedAt),
                      style: Theme.of(context)
                          .textTheme.bodySmall
                          ?.copyWith(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme.secondary),
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isDark) => Container(
        width: 80, height: 80,
        color: isDark ? AppTheme.darkBorder : AppTheme.grey200,
        child: Icon(Icons.image_outlined,
            color: isDark ? AppTheme.darkMuted : AppTheme.grey500,
            size: 28),
      );
}

// ── Full detail view for a shared memory ───────────────────────

class _SharedMemoryDetail extends StatefulWidget {
  final SharedMemoryModel item;
  const _SharedMemoryDetail({required this.item});

  @override
  State<_SharedMemoryDetail> createState() => _SharedMemoryDetailState();
}

class _SharedMemoryDetailState extends State<_SharedMemoryDetail> {
  int _page = 0;
  bool _sharing = false;

  Future<void> _shareItem() async {
    final urls = widget.item.mediaUrls;
    if (urls.isEmpty) return;
    setState(() => _sharing = true);
    try {
      // Share the storage URL as text — Android will offer browser/save options.
      // If there is a note, include it for context.
      final text = [
        if (widget.item.note.isNotEmpty) widget.item.note,
        ...urls,
      ].join('\n');
      await Share.share(text, subject: widget.item.eventTitle);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item   = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dtFmt  = DateFormat('EEEE, MMM d yyyy · h:mm a');

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(item.eventTitle,
            style: const TextStyle(fontSize: 15)),
        actions: [
          if (item.mediaUrls.isNotEmpty)
            IconButton(
              icon: _sharing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined),
              tooltip: 'Download / Share',
              onPressed: _sharing ? null : _shareItem,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Media carousel ─────────────────────────────
            if (item.mediaUrls.isNotEmpty) ...[
              AspectRatio(
                aspectRatio: 4 / 3,
                child: PageView.builder(
                  itemCount: item.mediaUrls.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    return item.mediaTypes[i] == 'image'
                        ? CachedNetworkImage(
                            imageUrl: item.mediaUrls[i],
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                color: isDark
                                    ? AppTheme.darkSurface
                                    : AppTheme.grey200),
                          )
                        : Container(
                            color: Colors.black,
                            child: const Center(
                              child: Icon(Icons.play_circle_outline,
                                  size: 56, color: Colors.white),
                            ),
                          );
                  },
                ),
              ),
              if (item.mediaUrls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(item.mediaUrls.length, (i) {
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
                  // Sender banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurface
                          : AppTheme.grey100,
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
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.grey200,
                          child: Text(
                            (item.sharedByName.isNotEmpty
                                    ? item.sharedByName[0]
                                    : '?')
                                .toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.sharedByName,
                              style: Theme.of(context)
                                  .textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                            Text('shared this memory with you',
                              style: Theme.of(context)
                                  .textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme.secondary,
                                  )),
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
                        dtFmt.format(item.originalCreatedAt),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),

                  // Location
                  if (item.locationName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13,
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.locationName,
                            style: Theme.of(context).textTheme.bodySmall
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

                  // Note
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(item.note,
                      style: Theme.of(context)
                          .textTheme.bodyLarge
                          ?.copyWith(height: 1.6)),
                  ],

                  // Download button
                  if (item.mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _sharing ? null : _shareItem,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Download / Share'),
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
              size: 56,
              color: Theme.of(context)
                  .colorScheme.secondary.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text('Nothing shared with you yet',
              style: Theme.of(context)
                  .textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'When someone shares a memory with your email, it will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
