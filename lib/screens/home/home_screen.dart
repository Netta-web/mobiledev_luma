import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/event_card.dart';
import '../events/create_event_screen.dart';
import '../events/event_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../shared/shared_with_me_screen.dart';
import '../shared/share_link_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Start listening to events once we have the user's uid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<EventProvider>().startListening(uid);
      }
    });
  }

  Future<void> _confirmDeleteEvent(EventModel event) async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
            '"${event.title}" and all its memories will be permanently deleted.'),
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
      await context.read<EventProvider>().deleteEvent(uid, event.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final eventProv = context.watch<EventProvider>();
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final events    = eventProv.events;
    final userName  = auth.user?.displayName?.split(' ').first ?? 'there';
    final photoUrl  = auth.user?.photoURL;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hi, $userName',
                          style: Theme.of(context)
                              .textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Your life chapters',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.secondary)),
                      ],
                    ),
                  ),
                  // Open a shared link
                  IconButton(
                    icon: const Icon(Icons.link_outlined),
                    tooltip: 'Open a link',
                    onPressed: _openLinkDialog,
                  ),
                  // Inbox → Shared with me
                  IconButton(
                    icon: const Icon(Icons.inbox_outlined),
                    tooltip: 'Shared with me',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SharedWithMeScreen())),
                  ),
                  // Avatar → Profile
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          isDark ? AppTheme.darkSurface : AppTheme.grey200,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              (auth.user?.displayName ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ))
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats bar ────────────────────────────────────
            if (events.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    _StatBadge(
                      label: 'Events',
                      value: events.length.toString(),
                    ),
                    const SizedBox(width: 10),
                    _StatBadge(
                      label: 'Memories',
                      value: events
                          .fold(0, (sum, e) => sum + e.memoryCount)
                          .toString(),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ── Event list ───────────────────────────────────
            Expanded(
              child: eventProv.isLoading && events.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : events.isEmpty
                      ? _EmptyState(
                          onCreateTap: () => _openCreateEvent(),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: events.length,
                          itemBuilder: (_, i) => EventCard(
                            event: events[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EventDetailScreen(event: events[i]),
                              ),
                            ),
                            onDelete: () => _confirmDeleteEvent(events[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),

      // ── FAB ─────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateEvent,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).scaffoldBackgroundColor,
        icon: const Icon(Icons.add),
        label: const Text('New Event',
          style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _openCreateEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateEventScreen()),
    );
  }

  void _openLinkDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open a link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a Luma share link or code:',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.secondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'luma://s/…  or link code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              String input = ctrl.text.trim();
              if (input.isEmpty) return;
              // Strip scheme prefix if pasted as a full link
              if (input.startsWith('luma://s/')) {
                input = input.substring('luma://s/'.length);
              }
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => ShareLinkScreen(linkId: input)),
              );
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          Text(value,
            style: Theme.of(context)
                .textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No events yet',
              style: Theme.of(context)
                  .textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Create your first life chapter to start documenting your memories.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create event'),
            ),
          ],
        ),
      ),
    );
  }
}
