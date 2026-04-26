import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/memory_entry_model.dart';
import '../../models/event_model.dart';
import '../../theme/app_theme.dart';
import 'memory_detail_screen.dart';

class MemoryMapScreen extends StatefulWidget {
  final List<MemoryEntryModel> memories;
  final EventModel event;

  const MemoryMapScreen({
    super.key,
    required this.memories,
    required this.event,
  });

  @override
  State<MemoryMapScreen> createState() => _MemoryMapScreenState();
}

class _MemoryMapScreenState extends State<MemoryMapScreen> {
  GoogleMapController? _mapController;
  MemoryEntryModel? _selected;

  // Only memories that have a real GPS fix
  late final List<MemoryEntryModel> _located = widget.memories
      .where((m) => m.latitude != 0.0 || m.longitude != 0.0)
      .toList();

  late final Set<Marker> _markers = {
    for (final m in _located)
      Marker(
        markerId: MarkerId(m.id),
        position: LatLng(m.latitude, m.longitude),
        onTap: () => setState(() => _selected = m),
      ),
  };

  LatLng get _initialTarget {
    if (_located.isNotEmpty) {
      return LatLng(_located.first.latitude, _located.first.longitude);
    }
    return const LatLng(0, 0);
  }

  void _fitBounds() {
    if (_located.length < 2 || _mapController == null) return;
    double minLat = _located.first.latitude;
    double maxLat = _located.first.latitude;
    double minLng = _located.first.longitude;
    double maxLng = _located.first.longitude;
    for (final m in _located) {
      if (m.latitude < minLat) minLat = m.latitude;
      if (m.latitude > maxLat) maxLat = m.latitude;
      if (m.longitude < minLng) minLng = m.longitude;
      if (m.longitude > maxLng) maxLng = m.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        80,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ─────────────────────────────────────────
          _located.isEmpty
              ? _NoLocationState(eventTitle: widget.event.title)
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialTarget,
                    zoom: 13,
                  ),
                  markers: _markers,
                  onMapCreated: (ctrl) {
                    _mapController = ctrl;
                    Future.delayed(
                      const Duration(milliseconds: 300),
                      _fitBounds,
                    );
                  },
                  onTap: (_) => setState(() => _selected = null),
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                ),

          // ── App bar overlay ──────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    _MapButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurface.withValues(alpha: 0.95)
                              : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.event.title,
                              style: Theme.of(context)
                                  .textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                            Text(
                              '${_located.length} located ${_located.length == 1 ? 'memory' : 'memories'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme.secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Memory bottom card ───────────────────────────
          if (_selected != null)
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: _MemoryCard(
                memory: _selected!,
                event: widget.event,
                onDismiss: () => setState(() => _selected = null),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkSurface.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryEntryModel memory;
  final EventModel event;
  final VoidCallback onDismiss;
  const _MemoryCard({
    required this.memory,
    required this.event,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('MMM d, yyyy · h:mm a');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail
          if (memory.thumbnailUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: memory.thumbnailUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    height: 140,
                    color: isDark ? AppTheme.darkBorder : AppTheme.grey200),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + dismiss
                Row(
                  children: [
                    Icon(Icons.access_time_outlined,
                        size: 12,
                        color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        dateFmt.format(memory.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 11,
                            ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onDismiss,
                      child: Icon(Icons.close,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary),
                    ),
                  ],
                ),

                if (memory.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    memory.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],

                if (memory.locationName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          memory.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme.bodySmall
                              ?.copyWith(fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme.secondary),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MemoryDetailScreen(
                          memory: memory,
                          event: event,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 38),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('View memory'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoLocationState extends StatelessWidget {
  final String eventTitle;
  const _NoLocationState({required this.eventTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(eventTitle),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined,
                  size: 56,
                  color: Theme.of(context)
                      .colorScheme.secondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text('No locations recorded',
                  style: Theme.of(context)
                      .textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Memories with GPS coordinates will appear as pins on the map.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
