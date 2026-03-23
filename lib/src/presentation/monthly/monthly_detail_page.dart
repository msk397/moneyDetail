import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../infrastructure/db/app_database.dart';
import '../../infrastructure/db/db_provider.dart';
import '../../widget/app_motion.dart';

enum ExpensePeriodType { today, month, year }

enum ExpenseSortType {
  amountDesc,
  amountAsc,
  timeDesc,
  timeAsc,
  categoryAsc,
}

class MonthlyDetailPage extends ConsumerWidget {
  const MonthlyDetailPage({super.key, this.period = ExpensePeriodType.month});

  final ExpensePeriodType period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (period == ExpensePeriodType.year) {
      return const _YearExpenseOverviewPage();
    }

    final range = _buildRange(period);
    return _RangeExpenseDetailPage(
      title: _titleForPeriod(period),
      start: range.start,
      end: range.end,
    );
  }

  DateTimeRange _buildRange(ExpensePeriodType period) {
    final now = DateTime.now();
    switch (period) {
      case ExpensePeriodType.today:
        final start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
      case ExpensePeriodType.month:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case ExpensePeriodType.year:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );
    }
  }

  String _titleForPeriod(ExpensePeriodType period) {
    switch (period) {
      case ExpensePeriodType.today:
        return '本日明细';
      case ExpensePeriodType.month:
        return '本月明细';
      case ExpensePeriodType.year:
        return '本年明细';
    }
  }
}

class _YearExpenseOverviewPage extends ConsumerWidget {
  const _YearExpenseOverviewPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year + 1, 1, 1);

    return Scaffold(
      appBar: AppBar(title: const Text('本年明细')),
      body: StreamBuilder<List<Expense>>(
        stream: db.watchExpensesInRange(start, end),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }

          final expenses = snapshot.data ?? const <Expense>[];
          if (expenses.isEmpty) {
            return const Center(child: Text('本年还没有记录'));
          }

          final monthMap = <DateTime, List<Expense>>{};
          for (final item in expenses) {
            final monthStart = DateTime(item.spentAt.year, item.spentAt.month, 1);
            monthMap.putIfAbsent(monthStart, () => []).add(item);
          }

          final months = monthMap.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          final yearTotal = expenses.fold<double>(0, (sum, e) => sum + e.amount);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            children: [
              AppEntrance(
                child: Card(
                  child: ListTile(
                    title: const Text('全年总花费'),
                    subtitle: Text('${expenses.length} 笔'),
                    trailing: Text(
                      '¥${yearTotal.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...months.asMap().entries.map((entry) {
                final index = entry.key;
                final monthStart = entry.value;
                final items = monthMap[monthStart]!;
                final total = items.fold<double>(0, (sum, e) => sum + e.amount);
                final percent = yearTotal <= 0 ? 0 : (total / yearTotal * 100);
                final categoryTotals = <String, double>{};
                for (final item in items) {
                  categoryTotals[item.category] =
                      (categoryTotals[item.category] ?? 0) + item.amount;
                }
                final topCategory = categoryTotals.entries.isEmpty
                    ? '无'
                    : (categoryTotals.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .first
                        .key;

                return AppEntrance(
                  delay: Duration(milliseconds: 70 + index * 35),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(DateFormat('yyyy年M月').format(monthStart)),
                      subtitle: Text('${items.length} 笔 · 主要分类: $topCategory · ${percent.toStringAsFixed(1)}%'),
                      trailing: Text('¥${total.toStringAsFixed(2)}'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _RangeExpenseDetailPage(
                              title: DateFormat('yyyy年M月明细').format(monthStart),
                              start: monthStart,
                              end: DateTime(monthStart.year, monthStart.month + 1, 1),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _RangeExpenseDetailPage extends ConsumerStatefulWidget {
  const _RangeExpenseDetailPage({
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;
  final DateTime start;
  final DateTime end;

  @override
  ConsumerState<_RangeExpenseDetailPage> createState() =>
      _RangeExpenseDetailPageState();
}

class _RangeExpenseDetailPageState extends ConsumerState<_RangeExpenseDetailPage> {
  String _categoryFilter = '全部';
  ExpenseSortType _sortType = ExpenseSortType.timeDesc;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<List<Expense>>(
        stream: db.watchExpensesInRange(widget.start, widget.end),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }

          final expenses = snapshot.data ?? const <Expense>[];
          if (expenses.isEmpty) {
            return const Center(child: Text('暂无记录'));
          }

          final categories = <String>{'全部', ...expenses.map((e) => e.category)}.toList();
          final filtered = expenses
              .where((e) => _categoryFilter == '全部' || e.category == _categoryFilter)
              .toList();
          _sortExpenses(filtered, _sortType);

          final categoryTotals = <String, double>{};
          for (final item in filtered) {
            categoryTotals[item.category] =
                (categoryTotals[item.category] ?? 0) + item.amount;
          }
          final sortedCategory = categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final total = filtered.fold<double>(0, (sum, e) => sum + e.amount);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              AppEntrance(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: categories.contains(_categoryFilter)
                                    ? _categoryFilter
                                    : '全部',
                                decoration: const InputDecoration(
                                  labelText: '分类筛选',
                                  border: OutlineInputBorder(),
                                ),
                                items: categories
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  HapticFeedback.selectionClick();
                                  setState(() => _categoryFilter = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<ExpenseSortType>(
                                value: _sortType,
                                decoration: const InputDecoration(
                                  labelText: '排序',
                                  border: OutlineInputBorder(),
                                ),
                                items: ExpenseSortType.values
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(_sortLabel(s)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  HapticFeedback.selectionClick();
                                  setState(() => _sortType = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('共 ${filtered.length} 笔 · ¥${total.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: sortedCategory
                              .map(
                                (e) => Chip(
                                  label: Text('${e.key} ¥${e.value.toStringAsFixed(2)}'),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...filtered.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return AppEntrance(
                  delay: Duration(milliseconds: 70 + index * 25),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.category} · ${DateFormat('MM-dd HH:mm').format(item.spentAt)}',
                      ),
                      trailing: Text('¥${item.amount.toStringAsFixed(2)}'),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

void _sortExpenses(List<Expense> items, ExpenseSortType sortType) {
  switch (sortType) {
    case ExpenseSortType.amountDesc:
      items.sort((a, b) => b.amount.compareTo(a.amount));
      return;
    case ExpenseSortType.amountAsc:
      items.sort((a, b) => a.amount.compareTo(b.amount));
      return;
    case ExpenseSortType.timeDesc:
      items.sort((a, b) => b.spentAt.compareTo(a.spentAt));
      return;
    case ExpenseSortType.timeAsc:
      items.sort((a, b) => a.spentAt.compareTo(b.spentAt));
      return;
    case ExpenseSortType.categoryAsc:
      items.sort((a, b) {
        final categoryCmp = a.category.compareTo(b.category);
        if (categoryCmp != 0) {
          return categoryCmp;
        }
        return b.amount.compareTo(a.amount);
      });
      return;
  }
}

String _sortLabel(ExpenseSortType sortType) {
  switch (sortType) {
    case ExpenseSortType.amountDesc:
      return '金额从高到低';
    case ExpenseSortType.amountAsc:
      return '金额从低到高';
    case ExpenseSortType.timeDesc:
      return '时间最新优先';
    case ExpenseSortType.timeAsc:
      return '时间最早优先';
    case ExpenseSortType.categoryAsc:
      return '按分类';
  }
}
