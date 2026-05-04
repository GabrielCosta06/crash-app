import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/interaction_feedback.dart';

/// Lightweight flow to request a password reset link.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final repository = context.read<AppRepository>();
    final email = _emailController.text.trim();

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (!repository.userExists(email)) {
      setState(
        () => _errorMessage =
            'We could not find an account for that email. Check the address or create a new account.',
      );
    } else {
      await showActionFeedback(
        context: context,
        icon: Icons.mail_lock_outlined,
        title: 'Reset link sent',
        message: 'Check your inbox at $email.',
        color: AppPalette.neonPulse,
      );
      if (!mounted) return;
      Navigator.pop(context);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AnimatedBackButton(),
        title: const Text('Recover access'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: AppPalette.deepSpace.withValues(alpha: 0.85),
                border: Border.all(color: AppPalette.border),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.mail_lock_outlined,
                          size: 48, color: AppPalette.neonPulse),
                      const SizedBox(height: 16),
                      Text(
                        'Reset your access code',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your crew email and we\'ll send over a secure reset link.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppPalette.softSlate),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        onFieldSubmitted: (_) {
                          if (!_isSubmitting) _sendResetLink();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Crew email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty ||
                              !value.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppPalette.danger,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TapScale(
                        enabled: !_isSubmitting,
                        child: SizedBox(
                          width: double.infinity,
                          child: AppPrimaryButton(
                            onPressed: _isSubmitting ? null : _sendResetLink,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Send reset link'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
