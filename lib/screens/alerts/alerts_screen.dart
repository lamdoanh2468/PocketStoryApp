import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_alert.dart';
import '../../services/finance_repository.dart';
import '../../utils/money_formatter.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<FinanceRepository>();

    return StreamBuilder<List<AppAlert>>(
      stream: repo.watchAlerts(user.uid),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <AppAlert>[];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (alerts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Chưa có cảnh báo nào. Khi bạn sắp chạm hoặc vượt ngân sách, thông báo sẽ xuất hiện tại đây.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: alerts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return _AlertCard(alert: alert, user: user);
          },
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.user});

  final AppAlert alert;
  final User user;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<FinanceRepository>();
    final isDanger = alert.level == 'danger';
    final isWarning = alert.level == 'warning';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alert.read ? null : () => repo.markAlertAsRead(user.uid, alert.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isDanger
                        ? Icons.warning_amber_rounded
                        : isWarning
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_rounded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: alert.read ? FontWeight.w600 : FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(alert.body),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'read') {
                        repo.markAlertAsRead(user.uid, alert.id);
                      }
                      if (value == 'delete') {
                        repo.deleteAlert(user.uid, alert.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'read', child: Text('Đánh dấu đã đọc')),
                      PopupMenuItem(value: 'delete', child: Text('Xóa thông báo')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(alert.category)),
                  if (alert.limitAmount > 0)
                    Chip(label: Text('${MoneyFormatter.vnd(alert.totalSpent)} / ${MoneyFormatter.vnd(alert.limitAmount)}')),
                  if (alert.ratio > 0) Chip(label: Text('${(alert.ratio * 100).toStringAsFixed(0)}%')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(alert.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!alert.read) ...[
                const SizedBox(height: 8),
                const Text('Mới', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
