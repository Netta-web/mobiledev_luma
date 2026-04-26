import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/memory_entry_model.dart';
import '../theme/app_theme.dart';

class MemoryTile extends StatelessWidget {
  final MemoryEntryModel memory;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const MemoryTile({
    super.key,
    required this.memory,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.grey100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.grey300,
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail or placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: memory.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: memory.thumbnailUrl!,
                      width: 72, height: 72,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(isDark),
                      errorWidget: (_, __, ___) => _placeholder(isDark),
                    )
                  : _placeholder(isDark),
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${dateFormat.format(memory.createdAt)} · ${timeFormat.format(memory.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 11,
                            ),
                      ),
                      const Spacer(),
                      if (onDelete != null)
                        GestureDetector(
                          onTap: onDelete,
                          child: Icon(Icons.more_horiz,
                              size: 16,
                              color: Theme.of(context).colorScheme.secondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (memory.note.isNotEmpty)
                    Text(
                      memory.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 6),
                  if (memory.locationName.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12,
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            memory.locationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  fontSize: 11,
                                ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      width: 72, height: 72,
      color: isDark ? AppTheme.darkBorder : AppTheme.grey200,
      child: Icon(
        Icons.image_outlined,
        color: isDark ? AppTheme.darkMuted : AppTheme.grey500,
        size: 28,
      ),
    );
  }
}
