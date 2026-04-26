import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

class CreateEventScreen extends StatefulWidget {
  final EventModel? existing; // non-null when editing

  const CreateEventScreen({super.key, this.existing});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  String         _category  = 'personal';
  DateTime       _startDate = DateTime.now();
  DateTime?      _endDate;
  bool           _isSaving         = false;
  LocationResult? _location;
  bool           _fetchingLocation = false;

  static const _categories = [
    'academic', 'travel', 'personal', 'work', 'other'
  ];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _titleCtrl.text = e.title;
      _descCtrl.text  = e.description;
      _category       = e.category;
      _startDate      = e.startDate;
      _endDate        = e.endDate;
      // Restore saved location so the row shows the existing name
      if (e.locationName != null && e.latitude != null && e.longitude != null) {
        _location = LocationResult(
          latitude: e.latitude!,
          longitude: e.longitude!,
          placeName: e.locationName!,
        );
      }
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _fetchingLocation = true);
    final result = await LocationService().getCurrentLocation();
    if (mounted) setState(() { _location = result; _fetchingLocation = false; });
  }

  void _clearLocation() => setState(() => _location = null);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title.')));
      return;
    }
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    final eventProv = context.read<EventProvider>();
    bool ok;

    if (_isEditing) {
      final updated = widget.existing!.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        startDate: _startDate,
        endDate: _endDate,
        locationName: _location?.placeName,
        latitude: _location?.latitude,
        longitude: _location?.longitude,
      );
      ok = await eventProv.updateEvent(uid, updated);
    } else {
      final newEvent = EventModel(
        id: '',
        userId: uid,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        startDate: _startDate,
        endDate: _endDate,
        locationName: _location?.placeName,
        latitude: _location?.latitude,
        longitude: _location?.longitude,
        createdAt: DateTime.now(),
      );
      final created = await eventProv.createEvent(uid, newEvent);
      ok = created != null;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEditing ? 'Edit event' : 'New event'),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            _Label('Title'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. First Year at University'),
            ),
            const SizedBox(height: 20),

            // Description
            _Label('Description (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What is this chapter about?'),
            ),
            const SizedBox(height: 20),

            // Category
            _Label('Category'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _category == cat;
                final color    = AppTheme.categoryColor(cat);
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? color : AppTheme.grey300,
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: selected ? color : AppTheme.grey700,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Dates
            _Label('Start date'),
            const SizedBox(height: 6),
            _DateTile(
              label: fmt.format(_startDate),
              onTap: () => _pickDate(isStart: true),
            ),
            const SizedBox(height: 12),

            _Label('End date (optional)'),
            const SizedBox(height: 6),
            _DateTile(
              label: _endDate != null ? fmt.format(_endDate!) : 'Not set',
              onTap: () => _pickDate(isStart: false),
              trailing: _endDate != null
                  ? GestureDetector(
                      onTap: () => setState(() => _endDate = null),
                      child: const Icon(Icons.close, size: 16,
                          color: AppTheme.grey500),
                    )
                  : null,
            ),
            const SizedBox(height: 20),

            // Location
            _Label('Location (optional)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: _fetchingLocation
                      ? const Text('Fetching location…',
                          style: TextStyle(fontSize: 13, color: AppTheme.grey500))
                      : Text(
                          _location?.placeName ?? 'No location set',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary),
                        ),
                ),
                if (_location != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _clearLocation,
                    color: Theme.of(context).colorScheme.secondary,
                    tooltip: 'Remove location',
                  ),
                IconButton(
                  icon: const Icon(Icons.my_location_outlined, size: 16),
                  onPressed: _fetchingLocation ? null : _fetchLocation,
                  color: Theme.of(context).colorScheme.secondary,
                  tooltip: 'Detect current location',
                ),
              ],
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

class _DateTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DateTile({required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.grey200,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.grey300,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 15,
                color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
            ),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
