import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../infrastructure/db/app_database.dart';
import '../../infrastructure/db/db_provider.dart';
import '../../infrastructure/settings/secure_settings_store.dart';
import '../../infrastructure/settings/settings_provider.dart';
import '../../widget/widget_bridge.dart';
import '../monthly/monthly_detail_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  double? _monthBudget;

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final raw = await ref.read(settingsStoreProvider).read(SecureSettingsStore.monthlyBudgetKey);
    if (!mounted) return;
    setState(() {
      _monthBudget = double.tryParse(raw);
    });
  }

  Future<void> _editBudget() async {
    final controller = TextEditingController(
      text: _monthBudget == null ? '' : _monthBudget!.toStringAsFixed(2),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置本月总预算'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '例如 5000',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(0),
              child: const Text('清空预算'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || parsed < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入有效预算金额')),
                  );
                  return;
                }
                Navigator.of(context).pop(parsed);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (value == null) return;
    final settings = ref.read(settingsStoreProvider);
    if (value <= 0) {
      await settings.save(SecureSettingsStore.monthlyBudgetKey, '');
      if (!mounted) return;
      setState(() => _monthBudget = null);
      return;
    }
    await settings.save(SecureSettingsStore.monthlyBudgetKey, value.toString());
    if (!mounted) return;
    setState(() => _monthBudget = value);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final today = ref.watch(_todayTotalProvider(db));
    final month = ref.watch(_monthTotalProvider(db));
    final year = ref.watch(_yearTotalProvider(db));
    final trend = ref.watch(_recent12MonthTrendProvider(db));

    final todayValue = today.value ?? 0;
    final monthValue = month.value ?? 0;
    final budget = _monthBudget;
    final budgetProgress = (budget == null || budget <= 0)
        ? null
        : (monthValue / budget).clamp(0.0, 1.0);
    final isOverBudget = budget != null && budget > 0 && monthValue > budget;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetBridge.updateTotals(today: todayValue, month: monthValue);
    });

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            backgroundImage: const AssetImage('assets/images/avatar_logo.jpg'),
            onBackgroundImageError: (_, __) {},
          ),
        ),
        title: const Align(
          alignment: Alignment.centerRight,
          child: Text('花费总览'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _HeroOverview(amount: month.value ?? 0),
          const SizedBox(height: 12),
          _BudgetProgressCard(
            budget: budget,
            spent: monthValue,
            progress: budgetProgress,
            isOverBudget: isOverBudget,
            onEditBudget: _editBudget,
          ),
          const SizedBox(height: 16),
          _TotalCard(
            title: '本日花费',
            subtitle: '今天已经花了',
            icon: Icons.today_outlined,
            color: const Color(0xFF0EA5A4),
            amount: todayValue,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MonthlyDetailPage(period: ExpensePeriodType.today),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _TotalCard(
            title: '本月花费',
            subtitle: '本月累计支出',
            icon: Icons.calendar_month_outlined,
            color: const Color(0xFF3B82F6),
            amount: monthValue,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MonthlyDetailPage(period: ExpensePeriodType.month),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _TotalCard(
            title: '本年花费',
            subtitle: '本年累计支出',
            icon: Icons.insights_outlined,
            color: const Color(0xFFF97316),
            amount: year.value ?? 0,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MonthlyDetailPage(period: ExpensePeriodType.year),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('近 12 个月花费', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: _TrendLineChart(points: trend.value ?? const []),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroOverview extends StatelessWidget {
  const _HeroOverview({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF115E59), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E7490).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本月收支总览',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '支出 ¥${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),

        ],
      ),
    );
  }
}

class _BudgetProgressCard extends StatelessWidget {
  const _BudgetProgressCard({
    required this.budget,
    required this.spent,
    required this.progress,
    required this.isOverBudget,
    required this.onEditBudget,
  });

  final double? budget;
  final double spent;
  final double? progress;
  final bool isOverBudget;
  final VoidCallback onEditBudget;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '本月预算',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onEditBudget,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(budget == null ? '设置预算' : '修改预算'),
                ),
              ],
            ),
            if (budget == null) ...[
              const Text('未设置总预算，点击右上角手动输入即可开启预算进度。'),
            ] else ...[
              Text('预算 ¥${budget!.toStringAsFixed(2)} · 已花 ¥${spent.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOverBudget
                    ? '超预算提醒：已超出 ¥${(spent - budget!).toStringAsFixed(2)}'
                    : '预算进度：${((progress ?? 0) * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: isOverBudget
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isOverBudget ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final _todayTotalProvider = StreamProvider.family<double, AppDatabase>((ref, db) {
  return db.watchTodayTotal();
});

final _monthTotalProvider = StreamProvider.family<double, AppDatabase>((ref, db) {
  return db.watchMonthTotal();
});

final _yearTotalProvider = StreamProvider.family<double, AppDatabase>((ref, db) {
  return db.watchYearTotal();
});

final _recent12MonthTrendProvider =
    StreamProvider.family<List<MonthlySpendPoint>, AppDatabase>((ref, db) {
  return db.watchRecent12MonthTotals();
});

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            )),
                  ],
                ),
              ),
              Text(
                '¥${amount.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendLineChart extends StatefulWidget {
  const _TrendLineChart({required this.points});

  final List<MonthlySpendPoint> points;

  @override
  State<_TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<_TrendLineChart> {
  int? _selectedIndex;
  bool _tooltipLocked = false;

  List<Offset> _buildChartPoints(Size size, List<double> values) {
    const topPad = 12.0;
    const bottomPad = 24.0;
    const leftPad = 8.0;
    const rightPad = 8.0;
    final chartHeight = size.height - topPad - bottomPad;
    final chartWidth = size.width - leftPad - rightPad;
    if (chartHeight <= 0 || chartWidth <= 0 || values.isEmpty) return const [];

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = leftPad + chartWidth * (values.length == 1 ? 0 : i / (values.length - 1));
      final y = topPad + chartHeight * (1 - (values[i] / safeMax));
      points.add(Offset(x, y));
    }
    return points;
  }

  int _nearestPointIndex(List<Offset> points, Offset position) {
    if (points.isEmpty) return -1;
    var minDistance = double.infinity;
    var hit = -1;
    for (var i = 0; i < points.length; i++) {
      final d = (points[i] - position).distance;
      if (d < minDistance) {
        minDistance = d;
        hit = i;
      }
    }
    return hit;
  }

  int _nearestPointByX(List<Offset> points, double x) {
    if (points.isEmpty) return -1;
    var minDistance = double.infinity;
    var hit = -1;
    for (var i = 0; i < points.length; i++) {
      final d = (points[i].dx - x).abs();
      if (d < minDistance) {
        minDistance = d;
        hit = i;
      }
    }
    return hit;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final values = points.map((e) => e.total).toList();
        final chartPoints = _buildChartPoints(
          Size(constraints.maxWidth, constraints.maxHeight),
          values,
        );

        final selected = (_selectedIndex != null && _selectedIndex! < points.length)
            ? points[_selectedIndex!]
            : null;
        final selectedOffset = (_selectedIndex != null && _selectedIndex! < chartPoints.length)
            ? chartPoints[_selectedIndex!]
            : null;

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _TrendPainter(
            values: values,
            lineColor: Theme.of(context).colorScheme.primary,
            fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.10),
            gridColor: Theme.of(context).colorScheme.outlineVariant,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (_tooltipLocked || chartPoints.isEmpty) return;
              final hit = _nearestPointIndex(chartPoints, details.localPosition);
              if (hit >= 0) {
                setState(() {
                  _selectedIndex = hit;
                });
              }
            },
            onLongPressStart: (details) {
              if (chartPoints.isEmpty) return;
              final hit = _nearestPointIndex(chartPoints, details.localPosition);
              if (hit >= 0) {
                setState(() {
                  _selectedIndex = hit;
                  _tooltipLocked = true;
                });
              }
            },
            onLongPressMoveUpdate: (details) {
              if (!_tooltipLocked || chartPoints.isEmpty) return;
              final hit = _nearestPointIndex(chartPoints, details.localPosition);
              if (hit >= 0 && hit != _selectedIndex) {
                setState(() {
                  _selectedIndex = hit;
                });
              }
            },
            onHorizontalDragUpdate: (details) {
              if (!_tooltipLocked || chartPoints.isEmpty) return;
              final localX = details.localPosition.dx;
              final hit = _nearestPointByX(chartPoints, localX);
              if (hit >= 0 && hit != _selectedIndex) {
                setState(() {
                  _selectedIndex = hit;
                });
              }
            },
            onDoubleTap: () {
              if (!_tooltipLocked) return;
              setState(() {
                _tooltipLocked = false;
                _selectedIndex = null;
              });
            },
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('yy/MM').format(points.first.monthStart)),
                          Text(DateFormat('yy/MM').format(points.last.monthStart)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selected != null && selectedOffset != null)
                  Positioned(
                    left: math.max(4, math.min(selectedOffset.dx - 62, constraints.maxWidth - 124)),
                    top: math.max(4, selectedOffset.dy - 54),
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: DefaultTextStyle(
                          style: Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('x: ${DateFormat('yyyy-MM').format(selected.monthStart)}'),
                              Text('y: ¥${selected.total.toStringAsFixed(2)}'),
                              if (_tooltipLocked)
                                const Text('已锁定，左右滑动切换；双击取消'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const topPad = 12.0;
    const bottomPad = 24.0;
    const leftPad = 8.0;
    const rightPad = 8.0;
    final chartHeight = size.height - topPad - bottomPad;
    final chartWidth = size.width - leftPad - rightPad;
    if (chartHeight <= 0 || chartWidth <= 0) return;

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.35)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topPad + chartHeight * (i / 3);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
    }

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = leftPad + chartWidth * (values.length == 1 ? 0 : i / (values.length - 1));
      final y = topPad + chartHeight * (1 - (values[i] / safeMax));
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height - bottomPad)
      ..lineTo(points.first.dx, size.height - bottomPad)
      ..close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );

    for (final p in points) {
      canvas.drawCircle(p, 3.2, Paint()..color = lineColor);
      canvas.drawCircle(p, 1.6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    if (values.length != oldDelegate.values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (values[i] != oldDelegate.values[i]) return true;
    }
    return lineColor != oldDelegate.lineColor ||
        fillColor != oldDelegate.fillColor ||
        gridColor != oldDelegate.gridColor;
  }
}
