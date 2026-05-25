import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/app_controller.dart';
import '../theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);

    ref.listen(appControllerProvider, (previous, next) {
      if (next.isSignedIn) {
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
                    const SizedBox(height: 28),
                    Text(
                      'KASUDLO',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Community health data gathering',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: KasudloColors.muted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? 'Use at least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 18),
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
                    if (controller.errorMessage != null)
                      Text(
                        controller.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: KasudloColors.critical),
                      ),
                    if (!controller.isSupabaseConfigured)
                      const _AccessNote(
                        text:
                            'Local mode active. Add Supabase dart-defines for live login.',
                      )
                    else
                      const _AccessNote(
                        text:
                            'Authorized accounts are created by an admin. Collect data with consent.',
                      ),
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
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: KasudloColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.health_and_safety_outlined,
          color: Colors.white,
          size: 44,
        ),
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
