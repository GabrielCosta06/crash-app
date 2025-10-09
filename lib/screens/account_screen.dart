import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../theme/app_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = context.read<AppRepository>();

    setState(() => _isUploading = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (file == null) {
        if (mounted) {
          setState(() => _isUploading = false);
        }
        return;
      }

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      await repository.updateProfileAvatar(base64Image);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile image updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update image: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final user = repository.currentUser;

    if (user == null) {
      return const _SignedOutView();
    }

    final avatarBytes =
        user.avatarBase64 != null ? base64Decode(user.avatarBase64!) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await repository.logOut();
              navigator.pushNamedAndRemoveUntil('/login', (route) => false);
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          children: [
            // ...existing code...
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).cardColor,
                border: Border.all(
          color: Theme.of(context).brightness == Brightness.light
            ? AppPalette.lightPrimary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 42,
            backgroundColor: Theme.of(context).brightness == Brightness.light
              ? AppPalette.lightPrimary.withValues(alpha: 0.12)
              : AppPalette.aurora.withValues(alpha: 0.2),
                        backgroundImage:
                            avatarBytes != null ? MemoryImage(avatarBytes) : null,
                        child: avatarBytes == null
                            ? Text(
                                user.initials,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAvatar,
                          child: CircleAvatar(
                            backgroundColor: AppPalette.neonPulse,
                            radius: 14,
                            child: _isUploading
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.edit, size: 14, color: Theme.of(context).brightness == Brightness.light ? AppPalette.lightText : Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.light ? AppPalette.lightText : Colors.white,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          user.email,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Theme.of(context).brightness == Brightness.light ? AppPalette.lightTextSecondary : AppPalette.softSlate),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
              color: user.isSubscribed
                ? AppPalette.success.withValues(alpha: 0.15)
                : (Theme.of(context).brightness == Brightness.light ? AppPalette.lightPrimary.withValues(alpha: 0.06) : AppPalette.deepSpace.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            user.isSubscribed ? 'Crew Pro Member' : 'Free plan',
                            style: TextStyle(
                              color: user.isSubscribed ? AppPalette.success : (Theme.of(context).brightness == Brightness.light ? AppPalette.lightTextSecondary : AppPalette.softSlate),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _InfoCard(
              title: 'Personal details',
              items: [
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Name',
                  value: user.displayName,
                ),
                _InfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Date of birth',
                  value: _formatDate(user.dateOfBirth),
                ),
                _InfoRow(
                  icon: Icons.public,
                  label: 'Country of birth',
                  value: user.countryOfBirth,
                ),
                if (user.isEmployee) ...[
                  _InfoRow(
                    icon: Icons.flight_takeoff_outlined,
                    label: 'Airline',
                    value: user.company ?? '',
                  ),
                  _InfoRow(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Badge',
                    value: user.badgeNumber ?? '',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            // Theme toggle as its own card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).cardColor,
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const _ThemeToggleRow(),
            ),
            _InfoCard(
              title: 'Security',
              items: [
                _InfoRow(
                  icon: Icons.lock_outline,
                  label: 'Subscription',
                  value: user.isSubscribed
                      ? 'Access enabled | \$15/month'
                      : 'Upgrade to unlock owner contact details',
                  trailing: user.isSubscribed
                      ? null
                      : ElevatedButton(
                          onPressed: () => Navigator.pushNamed(context, '/subscribe'),
                          child: const Text('Upgrade'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.items});

  final String title;
  final List<_InfoRow> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardColor = isLight ? AppPalette.lightSurface : AppPalette.deepSpace.withValues(alpha: 0.85);
  final borderColor = isLight ? AppPalette.lightPrimary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.06);
    final textColor = isLight ? AppPalette.lightText : Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cardColor,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppPalette.neonPulse),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppPalette.softSlate),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off_outlined, size: 56, color: AppPalette.softSlate),
            const SizedBox(height: 16),
            const Text('You are not signed in.'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _ThemeToggleRow extends StatelessWidget {
  const _ThemeToggleRow();

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    
    return Row(
      children: [
        Icon(
          repository.isDarkTheme ? Icons.dark_mode : Icons.light_mode,
          color: Theme.of(context).iconTheme.color,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                repository.isDarkTheme ? 'Dark mode' : 'Light mode',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: repository.isDarkTheme 
                        ? AppPalette.softSlate 
                        : AppPalette.lightTextSecondary,
                    ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: repository.isDarkTheme,
          onChanged: (_) => repository.toggleTheme(),
          activeTrackColor: repository.isDarkTheme
              ? AppPalette.neonPulse
              : AppPalette.lightPrimary,
        ),
      ],
    );
  }
}

