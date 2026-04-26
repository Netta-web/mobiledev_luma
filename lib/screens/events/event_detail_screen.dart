import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/memory_provider.dart';
import '../../models/event_model.dart';
import '../../models/memory_entry_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/memory_tile.dart';
import '../memories/add_memory_screen.dart';
import '../memories/memory_detail_screen.dart';
import '../memories/memory_map_screen.dart';
import 'create_event_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context
            .read<MemoryProvider>()
            .startListeningToEvent(uid, widget.event.id);
      }
    });
  }

  @override
  void dispose() {
    context.read<MemoryProvider>().stopListeningToEvent(widget.event.id);
    super.dispose();
  }

  Future<void> _confirmDeleteMemory(MemoryEntryModel memory) async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete memory?'),
        content: const Text('This memory will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context
          .read<MemoryProvider>()
          .deleteMemory(uid, widget.event.id, memory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memProv  = context.watch<MemoryProvider>();
    final memories = memProv.memoriesForEvent(widget.event.id);
    final catColor = AppTheme.categoryColor(widget.event.category);
    final fmt      = DateFormat('MMM d, yyyy');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Collapsible header ──────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            leading: const BackButton(),
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'View on map',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemoryMapScreen(
                      memories: memories,
                      event: widget.event,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateEventScreen(existing: widget.event),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      catColor.withValues(alpha: 0.15),
                      catColor.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 52, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _CategoryChip(
                            label: widget.event.category,
                            color: catColor),
                        const SizedBox(height: 8),
                        Text(
                          widget.event.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.event.endDate != null
                              ? '${fmt.format(widget.event.startDate)} – ${fmt.format(widget.event.endDate!)}'
                              : 'Since ${fmt.format(widget.event.startDate)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary,
                              ),
                        ),
                        if (widget.event.locationName != null &&
                            widget.event.locationName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.event.locationName!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        fontSize: 11,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Description ─────────────────────────────────
          if (widget.event.description.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  widget.event.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
              ),
            ),

          // ── Memory count label ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '${memories.length} ${memories.length == 1 ? 'memory' : 'memories'}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),

          // ── Memory list ──────────────────────────────────
          memProv.isLoading && memories.isEmpty
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
              : memories.isEmpty
                  ? const SliverFillRemaining(
                      child: _EmptyMemories(),
                    )
                  : SliverPadding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => MemoryTile(
                            memory: memories[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MemoryDetailScreen(
                                  memory: memories[i],
                                  event: widget.event,
                                ),
                              ),
                            ),
                            onDelete: () =>
                                _confirmDeleteMemory(memories[i]),
                          ),
                          childCount: memories.length,
                        ),
                      ),
                    ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMemory,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).scaffoldBackgroundColor,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add memory',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _openAddMemory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddMemoryScreen(event: widget.event),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CategoryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyMemories extends StatelessWidget {
  const _EmptyMemories();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 56,
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text('No memories yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap the button below to add your first moment.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    )),
          ],
        ),
      ),
    );
  }
}
