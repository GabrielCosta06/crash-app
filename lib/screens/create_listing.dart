import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/crashpad.dart';
import '../models/payment.dart';
import '../services/availability_service.dart';
import '../services/listing_content_service.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/interaction_feedback.dart';

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
  final TextEditingController _nearestAirportController =
      TextEditingController();
  final TextEditingController _minimumStayController =
      TextEditingController(text: '3');
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _customAmenityController =
      TextEditingController();
  final TextEditingController _customRuleController = TextEditingController();
  final ListingContentService _contentService = const ListingContentService();
  final Set<String> _selectedAmenities = <String>{
    'Wi-Fi',
    'Laundry',
    'Shared kitchen',
    'Secure entry',
  };
  final Set<String> _selectedRules = <String>{
    'Quiet hours after 10 PM',
    'Clean shared spaces after use',
  };

  final List<_RoomDraft> _rooms = <_RoomDraft>[
    _RoomDraft.initial(CrashpadBedModel.hot),
  ];
  final List<_ServiceDraft> _services = <_ServiceDraft>[];
  final List<_ChargeDraft> _checkoutCharges = <_ChargeDraft>[
    _ChargeDraft.initial(ChargeType.cleaning),
  ];
  final List<String> _base64Images = <String>[];
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;
  String _bedType = CrashpadBedModel.hot.label;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _nearestAirportController.dispose();
    _minimumStayController.dispose();
    _distanceController.dispose();
    _customAmenityController.dispose();
    _customRuleController.dispose();
    for (final room in _rooms) {
      room.dispose();
    }
    for (final service in _services) {
      service.dispose();
    }
    for (final charge in _checkoutCharges) {
      charge.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final messenger = ScaffoldMessenger.of(context);
    final files = await _picker.pickMultiImage(imageQuality: 75);
    if (!mounted || files.isEmpty) return;

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
    setState(() {});
  }

  void _removeImage(int index) {
    setState(() => _base64Images.removeAt(index));
  }

  void _setBedType(String value) {
    setState(() {
      _bedType = value;
      final model = crashpadBedModelFromLabel(value);
      if (model != CrashpadBedModel.flexible) {
        for (final room in _rooms) {
          room.bedModel = model;
          room.syncForModel();
        }
      }
    });
  }

  void _addRoom() {
    setState(() {
      final model = crashpadBedModelFromLabel(_bedType);
      _rooms.add(
        _RoomDraft.initial(
          model == CrashpadBedModel.flexible ? CrashpadBedModel.cold : model,
        ),
      );
    });
  }

  void _removeRoom(_RoomDraft room) {
    if (_rooms.length == 1) return;
    setState(() {
      _rooms.remove(room);
      room.dispose();
    });
  }

  void _addService() {
    setState(() => _services.add(_ServiceDraft.initial()));
  }

  void _removeService(_ServiceDraft service) {
    setState(() {
      _services.remove(service);
      service.dispose();
    });
  }

  void _addCheckoutCharge() {
    setState(
        () => _checkoutCharges.add(_ChargeDraft.initial(ChargeType.custom)));
  }

  void _toggleAmenity(String value, bool selected) {
    setState(() {
      if (selected) {
        _selectedAmenities.add(value);
      } else {
        _selectedAmenities.remove(value);
      }
    });
  }

  void _toggleRule(String value, bool selected) {
    setState(() {
      if (selected) {
        _selectedRules.add(value);
      } else {
        _selectedRules.remove(value);
      }
    });
  }

  void _addCustomAmenity() {
    final messenger = ScaffoldMessenger.of(context);
    final value = _contentService.normalize(_customAmenityController.text);
    final error = _contentService.validateCustomAmenity(value);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() {
      _selectedAmenities.add(value);
      _customAmenityController.clear();
    });
  }

  void _addCustomRule() {
    final messenger = ScaffoldMessenger.of(context);
    final value = _contentService.normalize(_customRuleController.text);
    final error = _contentService.validateCustomRule(value);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() {
      _selectedRules.add(value);
      _customRuleController.clear();
    });
  }

  void _removeCheckoutCharge(_ChargeDraft charge) {
    setState(() {
      _checkoutCharges.remove(charge);
      charge.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = context.read<AppRepository>();
    final user = repository.currentUser;
    if (user == null || user.userType != AppUserType.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only crashpad owners can create listings.'),
        ),
      );
      return;
    }

    final rooms = _buildRooms(strict: true);
    if (rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one room.')),
      );
      return;
    }
    if (_selectedAmenities.isEmpty || _selectedRules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one amenity and one house rule.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await repository.addCrashpad(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        nearestAirport: _nearestAirportController.text.trim().toUpperCase(),
        bedType: _resolveOverallBedType(rooms),
        price: double.parse(_priceController.text.trim()),
        imageUrls: _base64Images.isEmpty ? _placeholderImages : _base64Images,
        rooms: rooms,
        amenities: _contentService.normalizeSelection(_selectedAmenities),
        houseRules: _contentService.normalizeSelection(_selectedRules),
        services: _services
            .where((service) => service.hasMeaningfulData)
            .map((service) => service.toService())
            .toList(),
        checkoutCharges: _checkoutCharges
            .where((charge) => charge.hasMeaningfulData)
            .map((charge) => charge.toCheckoutCharge())
            .toList(),
        minimumStayNights: int.parse(_minimumStayController.text.trim()),
        distanceToAirportMiles:
            double.tryParse(_distanceController.text.trim()),
      );

      if (!mounted) return;
      await showActionFeedback(
        context: context,
        icon: Icons.check_circle_outline,
        title: 'Crashpad published',
        message: 'Inventory, rooms, fees, and capacity are now live.',
        color: AppPalette.success,
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

  List<CrashpadRoom> _buildRooms({required bool strict}) {
    return _rooms.asMap().entries.map((entry) {
      final index = entry.key;
      final room = entry.value;
      return room.toRoom(index: index, strict: strict);
    }).toList();
  }

  String _resolveOverallBedType(List<CrashpadRoom> rooms) {
    final hasHot = rooms.any((room) => room.bedModel == CrashpadBedModel.hot);
    final hasCold = rooms.any((room) => room.bedModel == CrashpadBedModel.cold);
    if (hasHot && hasCold) return CrashpadBedModel.flexible.label;
    if (hasCold) return CrashpadBedModel.cold.label;
    return CrashpadBedModel.hot.label;
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
          child: ResponsivePage(
            maxWidth: 1240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeading(
                  title: 'Create crashpad',
                  subtitle:
                      'Publish the actual property details owners need: rooms, beds, guests, fees, services, and house rules.',
                ),
                const SizedBox(height: AppSpacing.xxl),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        constraints.maxWidth >= AppBreakpoints.desktop;
                    final form = Column(
                      children: <Widget>[
                        _BasicsSection(
                          nameController: _nameController,
                          descriptionController: _descriptionController,
                          priceController: _priceController,
                          minimumStayController: _minimumStayController,
                          bedType: _bedType,
                          onBedTypeChanged: _setBedType,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _LocationSection(
                          locationController: _locationController,
                          nearestAirportController: _nearestAirportController,
                          distanceController: _distanceController,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _RoomsSection(
                          rooms: _rooms,
                          overallBedType: crashpadBedModelFromLabel(_bedType),
                          onAddRoom: _addRoom,
                          onRemoveRoom: _removeRoom,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _OperationsSection(
                          selectedAmenities: _selectedAmenities,
                          selectedRules: _selectedRules,
                          customAmenityController: _customAmenityController,
                          customRuleController: _customRuleController,
                          onAmenitySelected: _toggleAmenity,
                          onRuleSelected: _toggleRule,
                          onAddCustomAmenity: _addCustomAmenity,
                          onAddCustomRule: _addCustomRule,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _ServicesAndFeesSection(
                          services: _services,
                          charges: _checkoutCharges,
                          onAddService: _addService,
                          onRemoveService: _removeService,
                          onAddCharge: _addCheckoutCharge,
                          onRemoveCharge: _removeCheckoutCharge,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _GallerySection(
                          base64Images: _base64Images,
                          onPickImages: _pickImages,
                          onRemoveImage: _removeImage,
                        ),
                      ],
                    );

                    final preview = _LivePreview(
                      rooms: _buildRooms(strict: false),
                      nightlyRate:
                          double.tryParse(_priceController.text.trim()) ?? 0,
                      minimumStay:
                          int.tryParse(_minimumStayController.text.trim()) ??
                              AppConfig.defaultBookingNights,
                      services: _previewServices(),
                      charges: _previewCharges(),
                    );

                    if (!isWide) {
                      return Column(
                        children: <Widget>[
                          preview,
                          const SizedBox(height: AppSpacing.xxl),
                          form,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 7, child: form),
                        const SizedBox(width: AppSpacing.xxl),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: <Widget>[
                              preview,
                              const SizedBox(height: AppSpacing.xxl),
                              _SubmitPanel(
                                isSubmitting: _isSubmitting,
                                onSubmit: _submit,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= AppBreakpoints.desktop) {
                      return const SizedBox.shrink();
                    }
                    return _SubmitPanel(
                      isSubmitting: _isSubmitting,
                      onSubmit: _submit,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<CrashpadService> _previewServices() {
    return _services
        .where(
          (service) =>
              service.nameController.text.trim().isNotEmpty &&
              double.tryParse(service.priceController.text.trim()) != null,
        )
        .map((service) => service.toService())
        .toList();
  }

  List<CrashpadCheckoutCharge> _previewCharges() {
    return _checkoutCharges
        .where(
          (charge) =>
              charge.nameController.text.trim().isNotEmpty &&
              double.tryParse(charge.amountController.text.trim()) != null,
        )
        .map((charge) => charge.toCheckoutCharge())
        .toList();
  }
}

class _BasicsSection extends StatelessWidget {
  const _BasicsSection({
    required this.nameController,
    required this.descriptionController,
    required this.priceController,
    required this.minimumStayController,
    required this.bedType,
    required this.onBedTypeChanged,
    required this.onChanged,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController minimumStayController;
  final String bedType;
  final ValueChanged<String> onBedTypeChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Listing basics',
      child: Column(
        children: <Widget>[
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Crashpad name'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Guest-facing description',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().length < 20
                ? 'Describe the crashpad in at least 20 characters'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= AppBreakpoints.tablet;
              final rate = TextFormField(
                controller: priceController,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Nightly rate',
                  prefixText: r'$',
                ),
                keyboardType: TextInputType.number,
                validator: _positiveMoneyValidator,
              );
              final stay = TextFormField(
                controller: minimumStayController,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Minimum stay nights',
                ),
                keyboardType: TextInputType.number,
                validator: _positiveIntValidator,
              );
              final model = DropdownButtonFormField<String>(
                initialValue: bedType,
                decoration:
                    const InputDecoration(labelText: 'Property bed model'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'Hot Bed', child: Text('Hot Bed')),
                  DropdownMenuItem(value: 'Cold Bed', child: Text('Cold Bed')),
                  DropdownMenuItem(value: 'Both', child: Text('Mixed / Both')),
                ],
                onChanged: (value) {
                  if (value != null) onBedTypeChanged(value);
                },
              );

              if (!isWide) {
                return Column(
                  children: <Widget>[
                    rate,
                    const SizedBox(height: AppSpacing.lg),
                    stay,
                    const SizedBox(height: AppSpacing.lg),
                    model,
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: rate),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: stay),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: model),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.locationController,
    required this.nearestAirportController,
    required this.distanceController,
  });

  final TextEditingController locationController;
  final TextEditingController nearestAirportController;
  final TextEditingController distanceController;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Location',
      child: Column(
        children: <Widget>[
          TextFormField(
            controller: locationController,
            decoration:
                const InputDecoration(labelText: 'Address, city, country'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final airport = TextFormField(
                controller: nearestAirportController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Nearest airport code',
                  hintText: 'ex: SFO',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              );
              final distance = TextFormField(
                controller: distanceController,
                decoration: const InputDecoration(
                  labelText: 'Distance to airport',
                  suffixText: 'mi',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = double.tryParse(value.trim());
                  return parsed == null || parsed < 0
                      ? 'Enter a valid distance'
                      : null;
                },
              );

              if (constraints.maxWidth < AppBreakpoints.tablet) {
                return Column(
                  children: <Widget>[
                    airport,
                    const SizedBox(height: AppSpacing.lg),
                    distance,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: airport),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: distance),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoomsSection extends StatelessWidget {
  const _RoomsSection({
    required this.rooms,
    required this.overallBedType,
    required this.onAddRoom,
    required this.onRemoveRoom,
    required this.onChanged,
  });

  final List<_RoomDraft> rooms;
  final CrashpadBedModel overallBedType;
  final VoidCallback onAddRoom;
  final ValueChanged<_RoomDraft> onRemoveRoom;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Rooms, beds, and live capacity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'These values drive owner dashboard metrics and guest availability.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...rooms.map(
            (room) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _RoomCard(
                room: room,
                canRemove: rooms.length > 1,
                overallBedType: overallBedType,
                onRemove: () => onRemoveRoom(room),
                onChanged: onChanged,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAddRoom,
            icon: const Icon(Icons.add),
            label: const Text('Add room'),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.canRemove,
    required this.overallBedType,
    required this.onRemove,
    required this.onChanged,
  });

  final _RoomDraft room;
  final bool canRemove;
  final CrashpadBedModel overallBedType;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final allowModelSwitch = overallBedType == CrashpadBedModel.flexible;

    return CrashSurface(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Room setup',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove room',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: room.nameController,
            decoration: const InputDecoration(labelText: 'Room name'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<CrashpadBedModel>(
            initialValue: room.bedModel,
            decoration: const InputDecoration(labelText: 'Room bed model'),
            items: const <DropdownMenuItem<CrashpadBedModel>>[
              DropdownMenuItem(
                value: CrashpadBedModel.hot,
                child: Text('Hot bed room'),
              ),
              DropdownMenuItem(
                value: CrashpadBedModel.cold,
                child: Text('Cold bed room'),
              ),
            ],
            onChanged: allowModelSwitch
                ? (value) {
                    if (value == null) return;
                    room.bedModel = value;
                    room.syncForModel();
                    onChanged();
                  }
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = <Widget>[
                TextFormField(
                  controller: room.physicalBedsController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Physical beds'),
                  keyboardType: TextInputType.number,
                  validator: _positiveIntValidator,
                ),
                TextFormField(
                  controller: room.activeGuestsController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Active guests'),
                  keyboardType: TextInputType.number,
                  validator: (value) => room.validateActiveGuests(),
                ),
                if (room.bedModel == CrashpadBedModel.hot)
                  TextFormField(
                    controller: room.hotCapacityController,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Hot-bed max guests',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => room.validateHotCapacity(),
                  )
                else
                  TextFormField(
                    controller: room.assignedBedsController,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Assigned cold beds',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => room.validateAssignedBeds(),
                  ),
              ];

              if (constraints.maxWidth < AppBreakpoints.tablet) {
                return Column(
                  children: fields
                      .map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: field,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: fields
                    .map(
                      (field) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.lg),
                          child: field,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          TextFormField(
            controller: room.storageNoteController,
            decoration: const InputDecoration(
              labelText: 'Storage / bedding note',
              hintText: 'ex: Assigned bins for bedding and personal items',
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _OperationsSection extends StatelessWidget {
  const _OperationsSection({
    required this.selectedAmenities,
    required this.selectedRules,
    required this.customAmenityController,
    required this.customRuleController,
    required this.onAmenitySelected,
    required this.onRuleSelected,
    required this.onAddCustomAmenity,
    required this.onAddCustomRule,
  });

  final Set<String> selectedAmenities;
  final Set<String> selectedRules;
  final TextEditingController customAmenityController;
  final TextEditingController customRuleController;
  final void Function(String value, bool selected) onAmenitySelected;
  final void Function(String value, bool selected) onRuleSelected;
  final VoidCallback onAddCustomAmenity;
  final VoidCallback onAddCustomRule;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Amenities and house rules',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final amenities = _StructuredPicker(
            title: 'Amenities',
            subtitle:
                'Select known options or add a short validated custom item.',
            presets: ListingContentService.amenityPresets,
            selected: selectedAmenities,
            customController: customAmenityController,
            customLabel: 'Custom amenity',
            onSelected: onAmenitySelected,
            onAddCustom: onAddCustomAmenity,
          );
          final rules = _StructuredPicker(
            title: 'House rules',
            subtitle: 'Use clear rules guests can understand before booking.',
            presets: ListingContentService.houseRulePresets,
            selected: selectedRules,
            customController: customRuleController,
            customLabel: 'Custom rule',
            onSelected: onRuleSelected,
            onAddCustom: onAddCustomRule,
          );

          if (constraints.maxWidth < AppBreakpoints.tablet) {
            return Column(
              children: <Widget>[
                amenities,
                const SizedBox(height: AppSpacing.lg),
                rules,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: amenities),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: rules),
            ],
          );
        },
      ),
    );
  }
}

class _StructuredPicker extends StatelessWidget {
  const _StructuredPicker({
    required this.title,
    required this.subtitle,
    required this.presets,
    required this.selected,
    required this.customController,
    required this.customLabel,
    required this.onSelected,
    required this.onAddCustom,
  });

  final String title;
  final String subtitle;
  final List<String> presets;
  final Set<String> selected;
  final TextEditingController customController;
  final String customLabel;
  final void Function(String value, bool selected) onSelected;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    final customOnly = selected
        .where(
          (item) => !presets.any(
            (preset) => preset.toLowerCase() == item.toLowerCase(),
          ),
        )
        .toList();

    return CrashSurface(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((item) {
              return FilterChip(
                label: Text(item),
                selected: selected.contains(item),
                onSelected: (value) => onSelected(item, value),
              );
            }).toList(),
          ),
          if (customOnly.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: customOnly.map((item) {
                return InputChip(
                  label: Text(item),
                  onDeleted: () => onSelected(item, false),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: customController,
                  decoration: InputDecoration(labelText: customLabel),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAddCustom(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton.filledTonal(
                onPressed: onAddCustom,
                icon: const Icon(Icons.add),
                tooltip: 'Add custom item',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServicesAndFeesSection extends StatelessWidget {
  const _ServicesAndFeesSection({
    required this.services,
    required this.charges,
    required this.onAddService,
    required this.onRemoveService,
    required this.onAddCharge,
    required this.onRemoveCharge,
    required this.onChanged,
  });

  final List<_ServiceDraft> services;
  final List<_ChargeDraft> charges;
  final VoidCallback onAddService;
  final ValueChanged<_ServiceDraft> onRemoveService;
  final VoidCallback onAddCharge;
  final ValueChanged<_ChargeDraft> onRemoveCharge;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Additional services and checkout charges',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Services are optional guest add-ons. Checkout charges are owner-managed fees such as cleaning, damage, late checkout, or custom charges.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Additional services',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (services.isEmpty)
            Text(
              'No services added yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppPalette.textMuted),
            )
          else
            ...services.map(
              (service) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _ServiceCard(
                  service: service,
                  onRemove: () => onRemoveService(service),
                  onChanged: onChanged,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: onAddService,
            icon: const Icon(Icons.add),
            label: const Text('Add service'),
          ),
          const Divider(height: 36),
          Text('Checkout charges',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...charges.map(
            (charge) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _ChargeCard(
                charge: charge,
                canRemove: charges.length > 1,
                onRemove: () => onRemoveCharge(charge),
                onChanged: onChanged,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAddCharge,
            icon: const Icon(Icons.add),
            label: const Text('Add checkout charge'),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onRemove,
    required this.onChanged,
  });

  final _ServiceDraft service;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: service.nameController,
                  decoration: const InputDecoration(labelText: 'Service name'),
                  validator: (value) => service.validateName(),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove service',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: service.descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: service.priceController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Service price',
              prefixText: r'$',
            ),
            keyboardType: TextInputType.number,
            validator: (value) => service.validatePrice(),
          ),
        ],
      ),
    );
  }
}

class _ChargeCard extends StatelessWidget {
  const _ChargeCard({
    required this.charge,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _ChargeDraft charge;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<ChargeType>(
                  initialValue: charge.type,
                  decoration: const InputDecoration(labelText: 'Charge type'),
                  items: const <DropdownMenuItem<ChargeType>>[
                    DropdownMenuItem(
                      value: ChargeType.cleaning,
                      child: Text('Cleaning fee'),
                    ),
                    DropdownMenuItem(
                      value: ChargeType.damage,
                      child: Text('Damage fee'),
                    ),
                    DropdownMenuItem(
                      value: ChargeType.lateCheckout,
                      child: Text('Late checkout fee'),
                    ),
                    DropdownMenuItem(
                      value: ChargeType.custom,
                      child: Text('Custom charge'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    charge.type = value;
                    charge.applyTypeDefault();
                    onChanged();
                  },
                ),
              ),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove charge',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: charge.nameController,
            decoration: const InputDecoration(labelText: 'Charge label'),
            validator: (value) => charge.validateName(),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: charge.descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: charge.amountController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Default amount',
              prefixText: r'$',
            ),
            keyboardType: TextInputType.number,
            validator: (value) => charge.validateAmount(),
          ),
        ],
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({
    required this.base64Images,
    required this.onPickImages,
    required this.onRemoveImage,
  });

  final List<String> base64Images;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Gallery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              ...base64Images.asMap().entries.map(
                    (entry) => Stack(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
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
                            onTap: () => onRemoveImage(entry.key),
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
                onTap: onPickImages,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppPalette.borderStrong),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Upload up to 6 images. If none are uploaded, development placeholder photos are used.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.rooms,
    required this.nightlyRate,
    required this.minimumStay,
    required this.services,
    required this.charges,
  });

  final List<CrashpadRoom> rooms;
  final double nightlyRate;
  final int minimumStay;
  final List<CrashpadService> services;
  final List<CrashpadCheckoutCharge> charges;

  @override
  Widget build(BuildContext context) {
    final draftCrashpad = Crashpad(
      id: 'draft',
      name: 'Draft',
      description: 'Draft',
      location: 'Draft',
      nearestAirport: 'DRF',
      owner: const Owner(name: 'Draft'),
      imageUrls: const <String>[],
      dateAdded: DateTime.now(),
      bedType: _resolvePreviewBedType(rooms),
      price: nightlyRate,
      clickCount: 0,
      rooms: rooms,
      services: services,
      checkoutCharges: charges,
      minimumStayNights: minimumStay,
    );
    final availability = const AvailabilityService().summarize(draftCrashpad);
    final summary = const PaymentService().buildSummary(
      BookingDraft(
        crashpadId: 'draft',
        guestId: 'preview',
        nightlyRate: nightlyRate,
        nights: minimumStay <= 0 ? AppConfig.defaultBookingNights : minimumStay,
        guestCount: 1,
        additionalServices:
            services.take(1).map((service) => service.toLineItem()).toList(),
      ),
    );

    return Column(
      children: <Widget>[
        CrashSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Live owner metrics',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.lg),
              _PreviewMetric(
                label: 'Physical beds',
                value: '${availability.totalPhysicalBeds}',
              ),
              _PreviewMetric(
                label: 'Active guests',
                value: '${draftCrashpad.totalActiveGuests}',
              ),
              _PreviewMetric(
                label: 'Open capacity',
                value: '${availability.availableToBook}',
              ),
              _PreviewMetric(
                label:
                    '${minimumStay <= 0 ? AppConfig.defaultBookingNights : minimumStay}-night owner payout',
                value: '\$${summary.ownerPayout.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        PaymentSummaryCard(summary: summary, showStatus: false),
      ],
    );
  }

  String _resolvePreviewBedType(List<CrashpadRoom> rooms) {
    final hasHot = rooms.any((room) => room.bedModel == CrashpadBedModel.hot);
    final hasCold = rooms.any((room) => room.bedModel == CrashpadBedModel.cold);
    if (hasHot && hasCold) return CrashpadBedModel.flexible.label;
    if (hasCold) return CrashpadBedModel.cold.label;
    return CrashpadBedModel.hot.label;
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppPalette.textMuted),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SubmitPanel extends StatelessWidget {
  const _SubmitPanel({
    required this.isSubmitting,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Ready to publish',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This saves the operational values used by marketplace availability and owner dashboard metrics.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppPalette.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish_outlined),
            label: Text(isSubmitting ? 'Publishing...' : 'Publish crashpad'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CrashSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _RoomDraft {
  _RoomDraft({
    required this.bedModel,
    required String name,
    required int physicalBeds,
    required int activeGuests,
    required int hotCapacity,
    required int assignedBeds,
  })  : nameController = TextEditingController(text: name),
        physicalBedsController =
            TextEditingController(text: physicalBeds.toString()),
        activeGuestsController =
            TextEditingController(text: activeGuests.toString()),
        hotCapacityController =
            TextEditingController(text: hotCapacity.toString()),
        assignedBedsController =
            TextEditingController(text: assignedBeds.toString()),
        storageNoteController = TextEditingController();

  factory _RoomDraft.initial(CrashpadBedModel model) {
    return _RoomDraft(
      bedModel: model,
      name: model == CrashpadBedModel.hot ? 'Rotating room' : 'Assigned room',
      physicalBeds: 4,
      activeGuests: 0,
      hotCapacity: model == CrashpadBedModel.hot ? 6 : 4,
      assignedBeds: 0,
    );
  }

  CrashpadBedModel bedModel;
  final TextEditingController nameController;
  final TextEditingController physicalBedsController;
  final TextEditingController activeGuestsController;
  final TextEditingController hotCapacityController;
  final TextEditingController assignedBedsController;
  final TextEditingController storageNoteController;

  void dispose() {
    nameController.dispose();
    physicalBedsController.dispose();
    activeGuestsController.dispose();
    hotCapacityController.dispose();
    assignedBedsController.dispose();
    storageNoteController.dispose();
  }

  void syncForModel() {
    final physicalBeds = _parseInt(physicalBedsController.text, fallback: 1);
    if (bedModel == CrashpadBedModel.hot) {
      final currentCapacity =
          _parseInt(hotCapacityController.text, fallback: physicalBeds);
      if (currentCapacity < physicalBeds) {
        hotCapacityController.text = physicalBeds.toString();
      }
      assignedBedsController.text = '0';
    } else {
      hotCapacityController.text = physicalBeds.toString();
    }
  }

  CrashpadRoom toRoom({required int index, required bool strict}) {
    final physicalBeds = _parseInt(physicalBedsController.text, fallback: 0);
    final activeGuests = _parseInt(activeGuestsController.text, fallback: 0);
    final assignedBeds = bedModel == CrashpadBedModel.cold
        ? _parseInt(assignedBedsController.text, fallback: 0)
        : 0;
    final hotCapacity = bedModel == CrashpadBedModel.hot
        ? _parseInt(hotCapacityController.text, fallback: physicalBeds)
        : physicalBeds;
    final safePhysicalBeds = strict ? physicalBeds : physicalBeds.clamp(0, 999);
    final safeAssignedBeds = assignedBeds.clamp(0, safePhysicalBeds).toInt();

    return CrashpadRoom(
      id: 'room-${DateTime.now().microsecondsSinceEpoch}-$index',
      name: nameController.text.trim().isEmpty
          ? 'Room ${index + 1}'
          : nameController.text.trim(),
      bedModel: bedModel,
      beds: List<CrashpadBed>.generate(safePhysicalBeds, (bedIndex) {
        final bedNumber = bedIndex + 1;
        return CrashpadBed(
          id: 'room-$index-bed-$bedNumber',
          label: 'Bed $bedNumber',
          isAssigned: bedNumber <= safeAssignedBeds,
        );
      }),
      activeGuests: activeGuests.clamp(0, 999).toInt(),
      hotCapacity: hotCapacity.clamp(0, 999).toInt(),
      storageNote: storageNoteController.text.trim().isEmpty
          ? null
          : storageNoteController.text.trim(),
    );
  }

  String? validateActiveGuests() {
    final active = int.tryParse(activeGuestsController.text.trim());
    if (active == null || active < 0) return 'Enter 0 or more';
    if (bedModel == CrashpadBedModel.hot) {
      final capacity = _parseInt(hotCapacityController.text, fallback: 0);
      if (capacity > 0 && active > capacity) {
        return 'Cannot exceed hot-bed capacity';
      }
    } else {
      final assigned = _parseInt(assignedBedsController.text, fallback: 0);
      if (active > assigned) return 'Cannot exceed assigned beds';
    }
    return null;
  }

  String? validateHotCapacity() {
    final capacity = int.tryParse(hotCapacityController.text.trim());
    final beds = _parseInt(physicalBedsController.text, fallback: 0);
    final active = _parseInt(activeGuestsController.text, fallback: 0);
    if (capacity == null || capacity <= 0) return 'Enter a valid capacity';
    if (capacity < beds) return 'Must be at least physical beds';
    if (capacity < active) return 'Cannot be below active guests';
    return null;
  }

  String? validateAssignedBeds() {
    final assigned = int.tryParse(assignedBedsController.text.trim());
    final beds = _parseInt(physicalBedsController.text, fallback: 0);
    final active = _parseInt(activeGuestsController.text, fallback: 0);
    if (assigned == null || assigned < 0) return 'Enter 0 or more';
    if (assigned > beds) return 'Cannot exceed physical beds';
    if (active > assigned) return 'Cannot be below active guests';
    return null;
  }
}

class _ServiceDraft {
  _ServiceDraft({
    required String name,
    required String description,
    required double price,
  })  : nameController = TextEditingController(text: name),
        descriptionController = TextEditingController(text: description),
        priceController = TextEditingController(text: price.toStringAsFixed(0));

  factory _ServiceDraft.initial() {
    return _ServiceDraft(
      name: 'Fresh linen reset',
      description: 'Fresh sheets, towel, and pillowcase before arrival.',
      price: 18,
    );
  }

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;

  bool get hasMeaningfulData =>
      nameController.text.trim().isNotEmpty ||
      priceController.text.trim().isNotEmpty;

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
  }

  CrashpadService toService() {
    final name = nameController.text.trim();
    return CrashpadService(
      id: 'service-${name.hashCode}-${priceController.text.hashCode}',
      name: name,
      description: descriptionController.text.trim(),
      price: double.parse(priceController.text.trim()),
    );
  }

  String? validateName() {
    if (!hasMeaningfulData) return null;
    return nameController.text.trim().isEmpty ? 'Service name required' : null;
  }

  String? validatePrice() {
    if (!hasMeaningfulData) return null;
    return _positiveMoneyValidator(priceController.text);
  }
}

class _ChargeDraft {
  _ChargeDraft({
    required this.type,
    required String name,
    required String description,
    required double amount,
  })  : nameController = TextEditingController(text: name),
        descriptionController = TextEditingController(text: description),
        amountController =
            TextEditingController(text: amount.toStringAsFixed(0));

  factory _ChargeDraft.initial(ChargeType type) {
    return _ChargeDraft(
      type: type,
      name: _chargeName(type),
      description: _chargeDescription(type),
      amount: type == ChargeType.damage ? 75 : 35,
    );
  }

  ChargeType type;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController amountController;

  bool get hasMeaningfulData =>
      nameController.text.trim().isNotEmpty ||
      amountController.text.trim().isNotEmpty;

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    amountController.dispose();
  }

  void applyTypeDefault() {
    nameController.text = _chargeName(type);
    if (descriptionController.text.trim().isEmpty) {
      descriptionController.text = _chargeDescription(type);
    }
  }

  CrashpadCheckoutCharge toCheckoutCharge() {
    final name = nameController.text.trim();
    return CrashpadCheckoutCharge(
      id: 'charge-${type.name}-${name.hashCode}',
      name: name,
      description: descriptionController.text.trim(),
      amount: double.parse(amountController.text.trim()),
      type: type,
    );
  }

  String? validateName() {
    if (!hasMeaningfulData) return null;
    return nameController.text.trim().isEmpty ? 'Charge label required' : null;
  }

  String? validateAmount() {
    if (!hasMeaningfulData) return null;
    return _positiveMoneyValidator(amountController.text);
  }
}

String _chargeName(ChargeType type) {
  switch (type) {
    case ChargeType.cleaning:
      return 'Cleaning fee';
    case ChargeType.damage:
      return 'Damage fee';
    case ChargeType.lateCheckout:
      return 'Late checkout fee';
    case ChargeType.custom:
      return 'Custom charge';
    case ChargeType.booking:
    case ChargeType.additionalService:
    case ChargeType.checkout:
      return 'Checkout charge';
  }
}

String _chargeDescription(ChargeType type) {
  switch (type) {
    case ChargeType.cleaning:
      return 'Applied when checkout cleaning is not completed.';
    case ChargeType.damage:
      return 'Applied for verified damage after checkout.';
    case ChargeType.lateCheckout:
      return 'Applied when checkout happens after the agreed time.';
    case ChargeType.custom:
      return 'Owner-reviewed charge for custom checkout items.';
    case ChargeType.booking:
    case ChargeType.additionalService:
    case ChargeType.checkout:
      return 'Owner-managed checkout charge.';
  }
}

String? _positiveMoneyValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  final parsed = double.tryParse(value.trim());
  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
  return null;
}

String? _positiveIntValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed <= 0) return 'Enter a valid number';
  return null;
}

int _parseInt(String value, {required int fallback}) {
  return int.tryParse(value.trim()) ?? fallback;
}

const List<String> _placeholderImages = <String>[
  'https://images.unsplash.com/photo-1505691938895-1758d7feb511?auto=format&fit=crop&w=1200&q=80',
  'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1200&q=80',
];
