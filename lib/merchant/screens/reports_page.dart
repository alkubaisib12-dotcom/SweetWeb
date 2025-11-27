import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/services/email_service.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final _emailController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  bool _isGenerating = false;
  String? _errorMessage;
  String? _successMessage;

  final List<_QuickRange> _quickRanges = [
    _QuickRange(label: 'Today', start: DateTime.now(), end: DateTime.now()),
    _QuickRange(
      label: 'Yesterday',
      start: DateTime.now().subtract(const Duration(days: 1)),
      end: DateTime.now().subtract(const Duration(days: 1)),
    ),
    _QuickRange(
      label: 'Last 7 Days',
      start: DateTime.now().subtract(const Duration(days: 6)),
      end: DateTime.now(),
    ),
    _QuickRange(
      label: 'Last 30 Days',
      start: DateTime.now().subtract(const Duration(days: 29)),
      end: DateTime.now(),
    ),
  ];

  int _selectedQuickRange = 0;

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: _quickRanges[0].start,
      end: _quickRanges[0].end,
    );
    _loadUserEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      setState(() => _emailController.text = user!.email!);
    } else {
      final merchantId = ref.read(merchantIdProvider);
      final branchId = ref.read(branchIdProvider);
      final settingsDoc = await FirebaseFirestore.instance
          .doc('merchants/$merchantId/branches/$branchId/config/settings')
          .get();
      final email = settingsDoc.data()?['emailNotifications']?['email'];
      if (email != null) {
        setState(() => _emailController.text = email);
      }
    }
  }

  void _selectQuickRange(int index) {
    setState(() {
      _selectedQuickRange = index;
      _selectedDateRange = DateTimeRange(
        start: _quickRanges[index].start,
        end: _quickRanges[index].end,
      );
    });
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedQuickRange = -1;
      });
    }
  }

  Future<void> _generateReport() async {
    if (_selectedDateRange == null) {
      setState(() => _errorMessage = 'Please select a date range');
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter an email address');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final merchantId = ref.read(merchantIdProvider);
      final branchId = ref.read(branchIdProvider);

      final start = DateTime(
        _selectedDateRange!.start.year,
        _selectedDateRange!.start.month,
        _selectedDateRange!.start.day,
      );
      final end = DateTime(
        _selectedDateRange!.end.year,
        _selectedDateRange!.end.month,
        _selectedDateRange!.end.day,
        23, 59, 59,
      );

      final ordersSnap = await FirebaseFirestore.instance
          .collection('merchants/$merchantId/branches/$branchId/orders')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThanOrEqualTo: end)
          .get();

      double totalRevenue = 0;
      int servedOrders = 0;
      int cancelledOrders = 0;
      final ordersByStatus = <String, int>{};
      final itemCounts = <String, _ItemStats>{};

      for (final doc in ordersSnap.docs) {
        final order = doc.data();
        final status = order['status'] as String? ?? 'unknown';
        ordersByStatus[status] = (ordersByStatus[status] ?? 0) + 1;

        if (status == 'served') {
          servedOrders++;
          totalRevenue += (order['subtotal'] as num?)?.toDouble() ?? 0.0;
          final items = order['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            final name = item['name'] as String? ?? 'Unknown';
            final qty = (item['qty'] as num?)?.toInt() ?? 0;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            if (!itemCounts.containsKey(name)) {
              itemCounts[name] = _ItemStats(name: name);
            }
            itemCounts[name] = itemCounts[name]!.add(qty, price);
          }
        } else if (status == 'cancelled') {
          cancelledOrders++;
        }
      }

      final brandingDoc = await FirebaseFirestore.instance
          .doc('merchants/$merchantId/branches/$branchId/config/branding')
          .get();
      final merchantName = brandingDoc.data()?['title'] as String? ?? 'Your Store';

      final dateRange = '${DateFormat('MM/dd/yyyy').format(start)} - ${DateFormat('MM/dd/yyyy').format(end)}';
      final topItems = itemCounts.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      final statusList = ordersByStatus.entries
          .map((e) => StatusCount(status: e.key, count: e.value))
          .toList();

      final result = await EmailService.sendReport(
        merchantName: merchantName,
        dateRange: dateRange,
        totalOrders: ordersSnap.docs.length,
        totalRevenue: totalRevenue,
        servedOrders: servedOrders,
        cancelledOrders: cancelledOrders,
        averageOrder: servedOrders > 0 ? totalRevenue / servedOrders : 0,
        topItems: topItems.map((item) => TopItem(
          name: item.name,
          count: item.count,
          revenue: item.revenue,
        )).toList(),
        ordersByStatus: statusList,
        toEmail: _emailController.text.trim(),
      );

      if (mounted) {
        if (result.success) {
          setState(() {
            _successMessage = 'Report sent to ${_emailController.text.trim()}!\n${ordersSnap.docs.length} orders found.';
            _isGenerating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_successMessage!),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Failed to send report: ${result.error}';
            _isGenerating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to generate report: ${e.toString()}';
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
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
                        Text('Date Range', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_quickRanges.length, (i) {
                            return ChoiceChip(
                              label: Text(_quickRanges[i].label),
                              selected: _selectedQuickRange == i,
                              onSelected: (_) => _selectQuickRange(i),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _selectCustomRange,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _selectedQuickRange == -1 && _selectedDateRange != null
                                ? '${dateFormat.format(_selectedDateRange!.start)} - ${dateFormat.format(_selectedDateRange!.end)}'
                                : 'Custom Range',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email Address', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Send report to',
                            hintText: 'your@email.com',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: theme.colorScheme.error),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error))),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_successMessage!, style: const TextStyle(color: Colors.green))),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isGenerating ? null : _generateReport,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate & Send Report'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemStats {
  final String name;
  final int count;
  final double revenue;

  _ItemStats({required this.name, this.count = 0, this.revenue = 0.0});

  _ItemStats add(int qty, double price) {
    return _ItemStats(
      name: name,
      count: count + qty,
      revenue: revenue + (qty * price),
    );
  }
}

class _QuickRange {
  final String label;
  final DateTime start;
  final DateTime end;

  _QuickRange({required this.label, required this.start, required this.end});
}
