import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/config/app_config.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _emailController = TextEditingController();
  bool _notificationsEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final merchantId = ref.read(merchantIdProvider);
      final branchId = ref.read(branchIdProvider);
      final settingsDoc = await FirebaseFirestore.instance
          .doc('merchants/$merchantId/branches/$branchId/config/settings')
          .get();

      if (settingsDoc.exists) {
        final emailNotifications = settingsDoc.data()?['emailNotifications'];
        if (emailNotifications != null) {
          setState(() {
            _notificationsEnabled = emailNotifications['enabled'] ?? false;
            _emailController.text = emailNotifications['email'] ?? '';
            _isLoading = false;
          });
          return;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_notificationsEnabled && _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final merchantId = ref.read(merchantIdProvider);
      final branchId = ref.read(branchIdProvider);

      await FirebaseFirestore.instance
          .doc('merchants/$merchantId/branches/$branchId/config/settings')
          .set({
        'emailNotifications': {
          'enabled': _notificationsEnabled,
          'email': _emailController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.notifications_outlined, color: theme.colorScheme.primary),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Email Notifications',
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Receive email alerts when new orders are placed',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                value: _notificationsEnabled,
                                onChanged: (value) => setState(() => _notificationsEnabled = value),
                                title: const Text('Enable Notifications'),
                                subtitle: Text(_notificationsEnabled ? 'You will receive email alerts' : 'No email alerts'),
                                contentPadding: EdgeInsets.zero,
                              ),
                              if (_notificationsEnabled) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    hintText: 'your@email.com',
                                    prefixIcon: Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(),
                                    helperText: 'Order notifications will be sent to this email',
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'How it works',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _InfoItem(text: 'Instant alerts when orders are placed'),
                              _InfoItem(text: 'Beautiful email with order details'),
                              _InfoItem(text: 'Includes items, table, and total'),
                              _InfoItem(text: 'Link to view order in dashboard'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String text;
  const _InfoItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
