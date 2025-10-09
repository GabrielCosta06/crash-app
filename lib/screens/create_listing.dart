import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../widgets/interaction_feedback.dart';

/// Allows owners to publish a new crashpad with imagery and pricing.
class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _nearestAirportController = TextEditingController();

  final List<String> _base64Images = [];
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;
  String _bedType = 'Hot Bed';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _nearestAirportController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final messenger = ScaffoldMessenger.of(context);
    final files = await _picker.pickMultiImage(imageQuality: 75);
    if (!mounted) return;
    if (files.isEmpty) return;

    const maxImages = 6;
    if (_base64Images.length + files.length > maxImages) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You can upload up to 6 images.')),
      );
      return;
    }

    for (final file in files) {
      final bytes = await file.readAsBytes();
      _base64Images.add(base64Encode(bytes));
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _removeImage(int index) {
    setState(() {
      _base64Images.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null || user.userType != AppUserType.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only crashpad owners can create listings.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      await repository.addCrashpad(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        nearestAirport: _nearestAirportController.text.trim(),
        bedType: _bedType,
        price: price,
        imageUrls: _base64Images.isEmpty ? _placeholderImages : _base64Images,
      );
      if (!mounted) return;
      await showActionFeedback(
        context: context,
        icon: Icons.check_circle_outline,
        title: 'Crashpad published',
        message: 'Your sanctuary is ready for the crew.',
        color: AppPalette.neonPulse,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create listing: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AnimatedBackButton(),
        title: const Text('New crashpad'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Craft an unforgettable crew sanctuary.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Minimalist design, restorative amenities, and transparent data build loyalty. Start with the essentials below.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppPalette.softSlate),
              ),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Crashpad details',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Crashpad name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => value == null || value.trim().length < 20
                          ? 'Describe the crashpad (20+ characters)'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Nightly rate (USD)',
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a nightly rate';
                        }
                        final parsed = double.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownMenu<String>(
                      initialSelection: _bedType,
                      label: const Text('Bed type'),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'Hot Bed', label: 'Hot Bed'),
                        DropdownMenuEntry(value: 'Cold Bed', label: 'Cold Bed'),
                        DropdownMenuEntry(value: 'Both', label: 'Flexible / Both'),
                      ],
                      onSelected: (value) {
                        if (value != null) {
                          setState(() => _bedType = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Location',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Address, city, country',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nearestAirportController,
                      decoration: const InputDecoration(
                        labelText: 'Nearest airport code',
                        hintText: 'ex: SFO',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionCard(
                title: 'Gallery',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ..._base64Images.asMap().entries.map(
                              (entry) => Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.memory(
                                      base64Decode(entry.value),
                                      height: 100,
                                      width: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(entry.key),
                                      child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.black87,
                                        child: Icon(Icons.close, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        InkWell(
                          onTap: _pickImages,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload up to 6 images. We recommend at least 2 to showcase amenities.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppPalette.softSlate),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TapScale(
                enabled: !_isSubmitting,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Publish crashpad'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable container with consistent padding and rounding.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppPalette.deepSpace.withValues(alpha: 0.85),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

const List<String> _placeholderImages = [
  'https://images.unsplash.com/photo-1505691938895-1758d7feb511?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1200&q=80',
];
