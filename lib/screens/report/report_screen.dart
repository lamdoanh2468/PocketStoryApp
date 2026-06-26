import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/money_entry.dart';
import '../../services/analysis_service.dart';
import '../../services/finance_repository.dart';
import '../../utils/date_utils.dart';
import '../../utils/money_formatter.dart';
import '../../widgets/amount_card.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<FinanceRepository>();
    final now = DateTime.now();
    final currentStart = AppDateUtils.startOfMonth(now);
    final currentEnd = AppDateUtils.endOfMonth(now);
    final previousStart = AppDateUtils.startOfPreviousMonth(now);
    final previousEnd = AppDateUtils.endOfPreviousMonth(now);

    return StreamBuilder<List<MoneyEntry>>(
      stream: repo.watchEntries(user.uid),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <MoneyEntry>[];
        final currentEntries = AnalysisService.between(entries, currentStart, currentEnd);
        final summary = AnalysisService.summarize(currentEntries);
        final comparison = AnalysisService.compare(
          entries: entries,
          currentStart: currentStart,
          currentEnd: currentEnd,
          previousStart: previousStart,
          previousEnd: previousEnd,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Báo cáo chi tiêu', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            AmountCard(title: 'Thu tháng này', amount: MoneyFormatter.vnd(summary.totalIncome), icon: Icons.trending_up_rounded),
            AmountCard(title: 'Chi tháng này', amount: MoneyFormatter.vnd(summary.totalExpense), icon: Icons.trending_down_rounded),
            AmountCard(title: 'Số dư tháng này', amount: MoneyFormatter.vnd(summary.balance), icon: Icons.wallet_rounded),
            const SizedBox(height: 16),
            Text('Chi tiêu theo danh mục', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 260,
                  child: summary.expenseByCategory.isEmpty
                      ? const Center(child: Text('Chưa có dữ liệu chi tiêu tháng này.'))
                      : _CategoryBarChart(data: summary.expenseByCategory),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('So sánh xu hướng', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tháng này: ${MoneyFormatter.vnd(comparison.currentExpense)}'),
                    const SizedBox(height: 6),
                    Text('Tháng trước: ${MoneyFormatter.vnd(comparison.previousExpense)}'),
                    const Divider(height: 24),
                    Text(
                      _comparisonText(comparison.percentChange),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_advice(comparison.percentChange)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _comparisonText(double percent) {
    if (percent > 0) return 'Chi tiêu tăng ${percent.toStringAsFixed(1)}% so với tháng trước.';
    if (percent < 0) return 'Chi tiêu giảm ${percent.abs().toStringAsFixed(1)}% so với tháng trước.';
    return 'Chi tiêu không thay đổi đáng kể so với tháng trước.';
  }

  String _advice(double percent) {
    if (percent >= 15) {
      return 'Bạn nên kiểm tra các danh mục tăng mạnh, đặc biệt là ăn uống, cafe, mua sắm hoặc di chuyển.';
    }
    if (percent <= -10) {
      return 'Xu hướng đang tốt. Hãy duy trì thói quen ghi nhận chi tiêu đều đặn để kiểm soát ngân sách.';
    }
    return 'Mức thay đổi vẫn ổn định. Tiếp tục theo dõi để phát hiện khoản chi bất thường sớm hơn.';
  }
}

class _CategoryBarChart extends StatelessWidget {
  const _CategoryBarChart({required this.data});

  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.map((entry) => entry.value).fold<double>(0, max);

    return BarChart(
      BarChartData(
        maxY: maxValue == 0 ? 1 : maxValue * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    entries[index].key,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  width: 18,
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
