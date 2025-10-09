import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../widgets/interaction_feedback.dart';

/// Collects new user details and guides them into the product.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _badgeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  AppUserType _userType = AppUserType.owner;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickDate() async {
    final DateTime initial =
        DateTime.now().subtract(const Duration(days: 365 * 25));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
      helpText: 'Select your date of birth',
    );
    if (picked != null) {
      _dobController.text = picked.toIso8601String().split('T').first;
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<AppRepository>();
      await repository.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        countryOfBirth: _countryController.text.trim(),
        dateOfBirth: DateTime.parse(_dobController.text),
        userType: _userType,
        company: _userType == AppUserType.employee
            ? _companyController.text.trim()
            : null,
        badgeNumber: _userType == AppUserType.employee
            ? _badgeController.text.trim()
            : null,
      );
      if (!mounted) return;
      await showActionFeedback(
        context: context,
        icon: Icons.rocket_launch_outlined,
        title: 'Account ready',
        message: 'Welcome to the Crashpad network.',
        color: AppPalette.neonPulse,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      _showMessage(error.message, isError: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unexpected error: $error');
      _showMessage('Unable to create account. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppPalette.danger : AppPalette.aurora.withValues(alpha: 0.9),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _countryController.dispose();
    _dobController.dispose();
    _companyController.dispose();
    _badgeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SignupBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (MediaQuery.sizeOf(context).width > 880)
                      const Expanded(child: _SignupHero()),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Crew onboarding',
                                  style: GoogleFonts.spaceGrotesk(
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Activate your access to immersive crashpads built for recovery, focus, and connection.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppPalette.softSlate),
                                ),
                                const SizedBox(height: 24),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownMenu<AppUserType>(
                                              initialSelection: _userType,
                                              label: const Text('I am registering as'),
                                              onSelected: (value) {
                                                if (value == null) return;
                                                setState(() => _userType = value);
                                              },
                                              dropdownMenuEntries: const [
                                                DropdownMenuEntry(
                                                  value: AppUserType.owner,
                                                  label: 'Crashpad owner',
                                                ),
                                                DropdownMenuEntry(
                                                  value: AppUserType.employee,
                                                  label: 'Airline crew',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _firstNameController,
                                              decoration: const InputDecoration(
                                                labelText: 'First name',
                                              ),
                                              validator: (value) =>
                                                  value == null || value.trim().isEmpty
                                                      ? 'First name is required'
                                                      : null,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _lastNameController,
                                              decoration: const InputDecoration(
                                                labelText: 'Last name',
                                              ),
                                              validator: (value) =>
                                                  value == null || value.trim().isEmpty
                                                      ? 'Last name is required'
                                                      : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _emailController,
                                        decoration: const InputDecoration(
                                          labelText: 'Email address',
                                          prefixIcon: Icon(Icons.alternate_email),
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty ||
                                              !value.contains('@')) {
                                            return 'Enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon:
                                              const Icon(Icons.password_outlined),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                            ),
                                            onPressed: () => setState(
                                              () =>
                                                  _obscurePassword = !_obscurePassword,
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().length < 6) {
                                            return 'Use at least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _countryController,
                                              decoration: const InputDecoration(
                                                labelText: 'Country of birth',
                                              ),
                                              validator: (value) =>
                                                  value == null || value.trim().isEmpty
                                                      ? 'Required'
                                                      : null,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _dobController,
                                              readOnly: true,
                                              onTap: _pickDate,
                                              decoration: const InputDecoration(
                                                labelText: 'Date of birth',
                                                suffixIcon: Icon(Icons.event_outlined),
                                              ),
                                              validator: (value) =>
                                                  value == null || value.trim().isEmpty
                                                      ? 'Select your birth date'
                                                      : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_userType == AppUserType.employee)
                                        Column(
                                          children: [
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: _companyController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Airline / company',
                                                    ),
                                                    validator: (value) =>
                                                        value == null ||
                                                                value.trim().isEmpty
                                                            ? 'Required for crew access'
                                                            : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: _badgeController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Crew badge ID',
                                                    ),
                                                    validator: (value) =>
                                                        value == null ||
                                                                value.trim().isEmpty
                                                            ? 'Enter your badge number'
                                                            : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: TapScale(
                                          enabled: !_isLoading,
                                          child: ElevatedButton(
                                            onPressed: _isLoading ? null : _handleSignup,
                                            child: _isLoading
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : const Text('Create my Crashpad account'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushReplacementNamed(
                                            context,
                                            '/login',
                                          );
                                        },
                                        child: const Text('Already registered? Sign in'),
                                      ),
                                      if (_errorMessage != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 16),
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: AppPalette.danger,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Provides a soft radial gradient for the onboarding hero.
class _SignupBackground extends StatelessWidget {
  const _SignupBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.2,
          colors: [
            Color(0xFF1B2240),
            Color(0xFF080B15),
          ],
        ),
      ),
    );
  }
}

/// Highlights the product value proposition beside the signup form.
class _SignupHero extends StatelessWidget {
  const _SignupHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color headlineColor =
        isDark ? AppPalette.softWhite : AppPalette.midnight;
    final Color supportingColor =
        isDark ? Colors.white70 : Colors.black87;
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [AppPalette.neonPulse, AppPalette.aurora],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Designed for\ncrew momentum.',
                  style: GoogleFonts.spaceGrotesk(
                    textStyle: textTheme.headlineSmall?.copyWith(
                      color: headlineColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Zero-lag Wi-Fi mesh | Neuroadaptive lighting | Smart sleep pods | Secure biometric entry | Seamless owner analytics',
                  style: TextStyle(
                    color: supportingColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.bolt_outlined, color: AppPalette.neonPulse),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Experience a minimalist tech aesthetic that instills confidence from the first login.',
                  style: TextStyle(color: AppPalette.softSlate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
