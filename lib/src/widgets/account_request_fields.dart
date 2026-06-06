import 'package:flutter/material.dart';

const accountCreateRequestedKey = 'account_create_requested';
const accountEmailKey = 'account_email';

class AccountRequestFields extends StatelessWidget {
  const AccountRequestFields({
    super.key,
    required this.createRequested,
    required this.onCreateRequestedChanged,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    this.requirePassword = false,
  });

  final bool createRequested;
  final ValueChanged<bool> onCreateRequestedChanged;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool requirePassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: createRequested,
          onChanged: (value) => onCreateRequestedChanged(value ?? false),
          title: const Text('Create account'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (createRequested) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Account email'),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return 'Enter an email';
              }
              return accountEmailLooksValid(email)
                  ? null
                  : 'Enter a valid email';
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: requirePassword ? 'Password' : 'New password',
            ),
            validator: (value) {
              final password = value ?? '';
              final confirmPassword = confirmPasswordController.text;
              if (!requirePassword &&
                  password.isEmpty &&
                  confirmPassword.isEmpty) {
                return null;
              }
              if (password.isEmpty) {
                return 'Enter a password';
              }
              if (password.length < 6) {
                return 'Use at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (value) {
              final password = passwordController.text;
              final confirmPassword = value ?? '';
              if (!requirePassword &&
                  password.isEmpty &&
                  confirmPassword.isEmpty) {
                return null;
              }
              if (confirmPassword.isEmpty) {
                return 'Confirm the password';
              }
              if (confirmPassword != password) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }
}

bool accountCreateRequestedFromData(Map<String, dynamic> data) {
  final value = data[accountCreateRequestedKey];
  if (value is bool) {
    return value;
  }
  return '$value'.trim().toLowerCase() == 'true';
}

String accountEmailFromData(Map<String, dynamic> data) =>
    '${data[accountEmailKey] ?? ''}'.trim();

bool accountEmailLooksValid(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
