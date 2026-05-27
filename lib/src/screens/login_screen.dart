import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_controller.dart';
import '../theme.dart';

enum _LoginMode { signIn, requestReset }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _LoginMode _mode = _LoginMode.signIn;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);

    ref.listen(appControllerProvider, (previous, next) {
      if (next.isSignedIn && !next.isPasswordRecoverySession) {
        context.go('/home');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LogoMark(),
                    const SizedBox(height: 24),
                    if (controller.isPasswordRecoverySession)
                      _buildPasswordUpdateForm(controller)
                    else if (_mode == _LoginMode.requestReset)
                      _buildResetRequestForm(controller)
                    else
                      _buildSignInForm(controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(appControllerProvider);
    await controller.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  Widget _buildSignInForm(AppController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EmailField(controller: _emailController),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) => value == null || value.length < 6
              ? 'Use at least 6 characters'
              : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: controller.isBusy ? null : _showResetRequest,
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: controller.isBusy ? null : _submit,
          icon: controller.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Sign In'),
        ),
        const SizedBox(height: 14),
        _AuthFeedback(
          errorMessage: controller.errorMessage,
          successMessage: controller.passwordResetMessage,
        ),
      ],
    );
  }

  Widget _buildResetRequestForm(AppController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Reset password',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the account email and open the reset link on this device.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
        ),
        const SizedBox(height: 18),
        _EmailField(controller: _emailController),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: controller.isBusy ? null : _sendResetLink,
          icon: controller.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mail_outline),
          label: const Text('Send Reset Link'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isBusy ? null : _showSignIn,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Sign In'),
        ),
        const SizedBox(height: 14),
        _AuthFeedback(
          errorMessage: controller.errorMessage,
          successMessage: controller.passwordResetMessage,
        ),
        if (!controller.isSupabaseConfigured)
          const _AccessNote(
            text: 'Password reset is available after Supabase is configured.',
          ),
      ],
    );
  }

  Widget _buildPasswordUpdateForm(AppController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose a new password',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        if ((controller.activeEmail ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            controller.activeEmail!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: KasudloColors.muted),
          ),
        ],
        const SizedBox(height: 18),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            labelText: 'New password',
            prefixIcon: const Icon(Icons.lock_reset),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
          ),
          validator: (value) => value == null || value.length < 6
              ? 'Use at least 6 characters'
              : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Confirm the password';
            }
            if (value != _newPasswordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: controller.isBusy ? null : _completePasswordReset,
          icon: controller.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline),
          label: const Text('Update Password'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isBusy ? null : _cancelPasswordReset,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Sign In'),
        ),
        const SizedBox(height: 14),
        _AuthFeedback(
          errorMessage: controller.errorMessage,
          successMessage: controller.passwordResetMessage,
        ),
      ],
    );
  }

  void _showResetRequest() {
    ref.read(appControllerProvider).clearAuthMessages();
    _passwordController.clear();
    setState(() {
      _mode = _LoginMode.requestReset;
    });
  }

  void _showSignIn() {
    ref.read(appControllerProvider).clearAuthMessages();
    setState(() {
      _mode = _LoginMode.signIn;
    });
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(appControllerProvider)
        .requestPasswordReset(_emailController.text.trim());
  }

  Future<void> _completePasswordReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(appControllerProvider);
    await controller.completePasswordReset(_newPasswordController.text);
    if (!mounted) {
      return;
    }
    if (!controller.isPasswordRecoverySession) {
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _mode = _LoginMode.signIn;
      });
    }
  }

  Future<void> _cancelPasswordReset() async {
    await ref.read(appControllerProvider).signOut();
    if (!mounted) {
      return;
    }
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _mode = _LoginMode.signIn;
    });
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.mail_outline),
      ),
      validator: (value) =>
          value == null || !value.contains('@') ? 'Enter a valid email' : null,
    );
  }
}

class _AuthFeedback extends StatelessWidget {
  const _AuthFeedback({this.errorMessage, this.successMessage});

  final String? errorMessage;
  final String? successMessage;

  @override
  Widget build(BuildContext context) {
    final message = errorMessage ?? successMessage;
    if (message == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: errorMessage == null
              ? KasudloColors.primaryDark
              : KasudloColors.critical,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/kasudlo_logo.png',
        width: 120,
        height: 120,
      ),
    );
  }
}

class _AccessNote extends StatelessWidget {
  const _AccessNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: KasudloColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
