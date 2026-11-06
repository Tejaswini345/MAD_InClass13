import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePassword() async {
    final newPw = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordPrompt(
        title: 'Change password',
        label: 'New password',
        enforceMin: true,
      ),
    );
    if (newPw == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await authService.updatePassword(newPw);
      if (mounted) _snack('Password updated.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _reauthAndRetry(newPw);
      } else if (mounted) {
        _snack(AuthService.friendlyError(e));
      }
    } catch (_) {
      if (mounted) _snack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Recovery for requires-recent-login: ask for current password,
  /// re-authenticate, then retry the update once.
  Future<void> _reauthAndRetry(String newPw) async {
    if (!mounted) return;
    final current = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordPrompt(
        title: 'Confirm your identity',
        label: 'Current password',
        enforceMin: false,
      ),
    );
    if (current == null || !mounted) return;

    try {
      await authService.reauthenticate(current);
      await authService.updatePassword(newPw);
      if (mounted) _snack('Password updated.');
    } on FirebaseAuthException catch (e) {
      if (mounted) _snack(AuthService.friendlyError(e));
    } catch (_) {
      if (mounted) _snack('Something went wrong. Please try again.');
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await authService.signOut(); // AuthGate routes back to sign-in
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = authService.currentUser?.email ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_circle, size: 80),
                const SizedBox(height: 16),
                const Text('Signed in as',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _busy ? null : _changePassword,
                  icon: const Icon(Icons.password),
                  label: const Text('Change password'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small dialog that asks for a password and returns it (or null if cancelled).
class _PasswordPrompt extends StatefulWidget {
  const _PasswordPrompt({
    required this.title,
    required this.label,
    required this.enforceMin,
  });

  final String title;
  final String label;
  final bool enforceMin;

  @override
  State<_PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<_PasswordPrompt> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_ctrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label),
          validator: (v) {
            final value = v ?? '';
            if (value.isEmpty) return 'Please enter a password.';
            if (widget.enforceMin && value.length < 6) {
              return 'Password must be at least 6 characters.';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
