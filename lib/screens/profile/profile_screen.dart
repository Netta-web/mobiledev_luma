import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import '../../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _picker   = ImagePicker();
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;
    await context
        .read<AuthProvider>()
        .uploadProfilePhoto(File(file.path));
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await context.read<AuthProvider>().updateDisplayName(name);
    if (mounted) setState(() => _editingName = false);
  }

  Future<void> _signOut() async {
    final nav       = Navigator.of(context);
    final auth      = context.read<AuthProvider>();
    final eventProv = context.read<EventProvider>();
    await auth.signOut();
    eventProv.stopListening();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final user   = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ── Avatar ──────────────────────────────────
            GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor:
                        isDark ? AppTheme.darkSurface : AppTheme.grey200,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            (user?.displayName ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ))
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt_outlined,
                        size: 14,
                        color: Theme.of(context).scaffoldBackgroundColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Tap to change photo',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary)),

            const SizedBox(height: 16),

            // ── Name hero ────────────────────────────────
            if (user?.displayName != null && user!.displayName!.isNotEmpty)
              Text(
                user.displayName!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            // ── Display name ─────────────────────────────
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Display name'),
                  const SizedBox(height: 8),
                  _editingName
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameCtrl,
                                autofocus: true,
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: const InputDecoration(
                                    hintText: 'Your name'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: _saveName,
                              child: const Text('Save'),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                user?.displayName ?? '—',
                                style:
                                    Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _editingName = true),
                              child: Icon(Icons.edit_outlined,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary),
                            ),
                          ],
                        ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Email ────────────────────────────────────
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Email'),
                  const SizedBox(height: 6),
                  Text(user?.email ?? '—',
                    style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Theme toggle ─────────────────────────────
            _Section(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Theme'),
                        Text(isDark ? 'Dark mode' : 'Light mode',
                          style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDark,
                    onChanged: (_) => LumaApp.of(context).toggleTheme(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Sign out ─────────────────────────────────
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 0.5),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.grey100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.grey300,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));
  }
}
