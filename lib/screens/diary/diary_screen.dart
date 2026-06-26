import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/money_entry.dart';
import '../../services/finance_repository.dart';
import '../../utils/money_formatter.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<FinanceRepository>();

    return StreamBuilder<List<MoneyEntry>>(
      stream: repo.watchEntries(user.uid),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <MoneyEntry>[];
        final expenses = entries.where((entry) => entry.isExpense).toList();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (expenses.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Chưa có nhật ký chi tiêu. Hãy thêm khoản chi đầu tiên kèm hình ảnh nhé.'),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final entry = expenses[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: entry.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.category,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              MoneyFormatter.vnd(entry.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(entry.happenedAt)),
                        if (entry.note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(entry.note),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
