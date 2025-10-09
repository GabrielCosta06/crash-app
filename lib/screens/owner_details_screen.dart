import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/crashpad.dart';
import '../models/review.dart';
import '../theme/app_theme.dart';

class OwnerDetailsScreen extends StatefulWidget {
  const OwnerDetailsScreen({super.key, required this.crashpad});

  final Crashpad crashpad;

  @override
  State<OwnerDetailsScreen> createState() => _OwnerDetailsScreenState();
}

class _OwnerDetailsScreenState extends State<OwnerDetailsScreen> {
  late Crashpad _crashpad;
  late Future<List<Review>> _reviewsFuture;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _crashpad = widget.crashpad;
    _reviewsFuture = _fetchReviews();
    // Use post-frame callback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackClick();
    });
  }

  Future<void> _trackClick() async {
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user != null && user.email.toLowerCase() == _crashpad.owner.contact?.toLowerCase()) {
      return;
    }
    await repository.incrementClickCount(_crashpad.id);
  }

  Future<List<Review>> _fetchReviews() {
    final repository = context.read<AppRepository>();
    return repository.fetchReviews(_crashpad.id);
  }

  Future<void> _addReview() async {
    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null || user.userType != AppUserType.employee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only verified crew can write reviews.')),
      );
      return;
    }

    final result = await showDialog<_ReviewDraft>(
      context: context,
      builder: (context) => const _ReviewDialog(),
    );

    if (result == null) return;

    await repository.addReview(
      crashpadId: _crashpad.id,
      employeeName: user.displayName,
      comment: result.comment,
      rating: result.rating,
    );

    if (!mounted) return;
    final newFuture = _fetchReviews();
    setState(() {
      _reviewsFuture = newFuture;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review submitted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppRepository>();
    final isEmployee = repository.currentUser?.userType == AppUserType.employee;
    final averageRating = repository.calculateAverageRating(_crashpad.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crashpad overview'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Use pop instead of pushReplacementNamed to go back properly
            Navigator.of(context).pop();
          },
        ),
      ),
      floatingActionButton: isEmployee
          ? FloatingActionButton.extended(
              onPressed: _addReview,
              icon: const Icon(Icons.reviews_outlined),
              label: const Text('Share experience'),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImageCarousel(
              imageUrls: _crashpad.imageUrls,
              currentIndex: _currentImage,
              onPageChanged: (index) => setState(() => _currentImage = index),
              heroTag: 'crashpad-${_crashpad.id}',
            ),
            const SizedBox(height: 24),
            _PrimaryDetails(crashpad: _crashpad, rating: averageRating),
            const SizedBox(height: 24),
            _DescriptionCard(description: _crashpad.description),
            const SizedBox(height: 24),
            _OwnerContact(owner: _crashpad.owner),
            const SizedBox(height: 24),
            _ReviewsSection(reviewsFuture: _reviewsFuture),
          ],
        ),
      ),
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({
    required this.imageUrls,
    required this.currentIndex,
    required this.onPageChanged,
    this.heroTag,
  });

  final List<String> imageUrls;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final String? heroTag;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.currentIndex);
  }

  @override
  void didUpdateWidget(covariant _ImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex &&
        _controller.hasClients &&
        _controller.page?.round() != widget.currentIndex) {
      _controller.animateToPage(
        widget.currentIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppPalette.deepSpace.withValues(alpha: 0.8),
        ),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 48, color: AppPalette.softSlate),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.imageUrls.length,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];
              final page = _controller.hasClients
                  ? (_controller.page ?? _controller.initialPage.toDouble())
                  : _controller.initialPage.toDouble();
              final delta = (index - page);
              final content = ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Transform.translate(
                  offset: Offset(delta * 12, 0),
                  child: _buildImage(url),
                ),
              );
              if (index == 0 && widget.heroTag != null) {
                return Hero(tag: widget.heroTag!, child: content);
              }
              return content;
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.imageUrls.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: widget.currentIndex == index ? 24 : 12,
              decoration: BoxDecoration(
                color: widget.currentIndex == index
                    ? AppPalette.neonPulse
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          color: AppPalette.deepSpace.withValues(alpha: 0.8),
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppPalette.deepSpace.withValues(alpha: 0.8),
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
    }
    try {
      final bytes = base64Decode(url);
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return Container(
        color: AppPalette.deepSpace.withValues(alpha: 0.8),
        child: const Icon(Icons.broken_image_outlined),
      );
    }
  }
}

class _PrimaryDetails extends StatelessWidget {
  const _PrimaryDetails({required this.crashpad, required this.rating});

  final Crashpad crashpad;
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppPalette.deepSpace.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  crashpad.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppPalette.neonPulse.withValues(alpha: 0.15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: AppPalette.neonPulse, size: 18),
                    const SizedBox(width: 4),
                    Text(rating.toStringAsFixed(1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(crashpad.location)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.local_airport_outlined, size: 18),
              const SizedBox(width: 6),
              Text('Nearest airport: ${crashpad.nearestAirport}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.bed_outlined, size: 18),
              const SizedBox(width: 6),
              Text('Bed type: ${crashpad.bedType}'),
              const Spacer(),
              Text(
                '\$${crashpad.price.toStringAsFixed(0)}/night',
                style: const TextStyle(
                  color: AppPalette.neonPulse,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardColor = isLight ? AppPalette.lightSurface : AppPalette.deepSpace.withValues(alpha: 0.85);
    final textColor = isLight ? AppPalette.lightText : Colors.white;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Experience',
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _OwnerContact extends StatelessWidget {
  const _OwnerContact({required this.owner});

  final Owner owner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardColor = isLight ? AppPalette.lightSurface : AppPalette.deepSpace.withValues(alpha: 0.85);
  final borderColor = isLight ? AppPalette.lightPrimary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04);
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
            'Owner',
            style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(owner.name, style: theme.textTheme.bodyMedium?.copyWith(color: textColor)),
            ],
          ),
          if (owner.contact != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.alternate_email, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(owner.contact!)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.reviewsFuture});

  final Future<List<Review>> reviewsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppPalette.deepSpace.withValues(alpha: 0.85),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _ReviewError(onRetry: () {});
        }
        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppPalette.deepSpace.withValues(alpha: 0.85),
            ),
            child: const Text('No reviews yet. Be the first to share your experience.'),
          );
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppPalette.deepSpace.withValues(alpha: 0.85),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crew insights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              ...reviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ReviewTile(review: review),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 8),
              Text(
                review.employeeName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: AppPalette.warning),
                  const SizedBox(width: 4),
                  Text(review.rating.toStringAsFixed(1)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(review.createdAt),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.softSlate),
          ),
        ],
      ),
    );
  }
}

class _ReviewError extends StatelessWidget {
  const _ReviewError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppPalette.deepSpace.withValues(alpha: 0.85),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reviews unavailable'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ReviewDraft {
  _ReviewDraft({required this.comment, required this.rating});
  final String comment;
  final double rating;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _commentController = TextEditingController();
  double _rating = 4.5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share your experience'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment',
                hintText: 'What made this crashpad stand out?',
              ),
              validator: (value) =>
                  value == null || value.trim().length < 10 ? 'Be a bit more descriptive' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _rating,
                    onChanged: (value) => setState(() => _rating = value),
                    divisions: 8,
                    min: 1,
                    max: 5,
                    label: _rating.toStringAsFixed(1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_rating.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _ReviewDraft(
                  comment: _commentController.text.trim(),
                  rating: _rating,
                ),
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
