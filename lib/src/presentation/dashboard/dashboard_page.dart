import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../infrastructure/db/app_database.dart';
import '../../infrastructure/db/db_provider.dart';
import '../../infrastructure/settings/secure_settings_store.dart';
import '../../infrastructure/settings/settings_provider.dart';
import '../../widget/app_motion.dart';
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
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入有效预算金额')),
                  );
                  return;
                }
                HapticFeedback.selectionClick();
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
      HapticFeedback.mediumImpact();
      setState(() => _monthBudget = null);
      return;
    }
    await settings.save(SecureSettingsStore.monthlyBudgetKey, value.toString());
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _monthBudget = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            backgroundColor: scheme.surface,
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
          AppEntrance(
            child: _HeroOverview(
              amount: month.value ?? 0,
              startColor: Color.lerp(scheme.primary, scheme.tertiary, 0.25)!,
              endColor: Color.lerp(scheme.primary, scheme.secondary, 0.15)!,
              shadowColor: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          AppEntrance(
            delay: const Duration(milliseconds: 60),
            child: _BudgetProgressCard(
              budget: budget,
              spent: monthValue,
              progress: budgetProgress,
              isOverBudget: isOverBudget,
              onEditBudget: _editBudget,
            ),
          ),
          const SizedBox(height: 16),
          AppEntrance(
            delay: const Duration(milliseconds: 110),
            child: _TotalCard(
              title: '本日花费',
              subtitle: '今天已经花了',
              icon: Icons.today_outlined,
              color: scheme.tertiary,
              amount: todayValue,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MonthlyDetailPage(period: ExpensePeriodType.today),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppEntrance(
            delay: const Duration(milliseconds: 150),
            child: _TotalCard(
              title: '本月花费',
              subtitle: '本月累计支出',
              icon: Icons.calendar_month_outlined,
              color: scheme.primary,
              amount: monthValue,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MonthlyDetailPage(period: ExpensePeriodType.month),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppEntrance(
            delay: const Duration(milliseconds: 190),
            child: _TotalCard(
              title: '本年花费',
              subtitle: '本年累计支出',
              icon: Icons.insights_outlined,
              color: scheme.secondary,
              amount: year.value ?? 0,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MonthlyDetailPage(period: ExpensePeriodType.year),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppEntrance(
            delay: const Duration(milliseconds: 240),
            child: Card(
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
          ),
        ],
      ),
    );
  }
}

class _HeroOverview extends StatelessWidget {
  const _HeroOverview({
    required this.amount,
    required this.startColor,
    required this.endColor,
    required this.shadowColor,
  });

  final double amount;
  final Color startColor;
  final Color endColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本月收支总览',
            style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 14),
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
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.enterCurve,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (isOverBudget)
            BoxShadow(
              color: scheme.error.withOpacity(0.14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Card(
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
              AnimatedSwitcher(
                duration: AppMotion.medium,
                child: budget == null
                    ? const Text(
                        '未设置总预算，点击右上角手动输入即可开启预算进度。',
                        key: ValueKey('budget-empty'),
                      )
                    : Column(
                        key: const ValueKey('budget-content'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('预算 ¥${budget!.toStringAsFixed(2)} · 已花 ¥${spent.toStringAsFixed(2)}'),
                          const SizedBox(height: 8),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress ?? 0),
                            duration: AppMotion.slow,
                            curve: AppMotion.enterCurve,
                            builder: (context, animatedValue, child) {
                              return LinearProgressIndicator(
                                value: animatedValue,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(999),
                                backgroundColor: scheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isOverBudget ? scheme.error : scheme.primary,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isOverBudget
                                ? '超预算提醒：已超出 ¥${(spent - budget!).toStringAsFixed(2)}'
                                : '预算进度：${((progress ?? 0) * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: isOverBudget ? scheme.error : scheme.onSurfaceVariant,
                              fontWeight: isOverBudget ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
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
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
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

class _TrendLineChartState extends State<_TrendLineChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _revealCtrl;
  late Animation<double> _revealAnim;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _revealAnim = CurvedAnimation(
      parent: _revealCtrl,
      curve: Curves.easeOutCubic,
    );
    _revealCtrl.forward();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  List<Offset> _buildChartPoints(Size size, List<double> values) {
    const topPad = 20.0;
    const bottomPad = 28.0;
    const leftPad = 10.0;
    const rightPad = 10.0;
    final chartHeight = size.height - topPad - bottomPad;
    final chartWidth = size.width - leftPad - rightPad;
    if (chartHeight <= 0 || chartWidth <= 0 || values.isEmpty) return const [];

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = leftPad + chartWidth * (values.length == 1 ? 0.5 : i / (values.length - 1));
      final y = topPad + chartHeight * (1 - (values[i] / safeMax));
      points.add(Offset(x, y));
    }
    return points;
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
      return const AppStatePanel(
        icon: Icons.show_chart,
        title: '暂无趋势数据',
        message: '继续记账后，这里会展示最近 12 个月的支出走势。',
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final values = points.map((e) => e.total).toList();
        final chartPoints = _buildChartPoints(size, values);

        final selected = (_selectedIndex != null && _selectedIndex! < points.length)
            ? points[_selectedIndex!]
            : null;
        final selectedOffset = (_selectedIndex != null && _selectedIndex! < chartPoints.length)
            ? chartPoints[_selectedIndex!]
            : null;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (chartPoints.isEmpty) return;
            final hit = _nearestPointByX(chartPoints, details.localPosition.dx);
            setState(() {
              _selectedIndex = (hit == _selectedIndex) ? null : hit;
            });
            HapticFeedback.selectionClick();
          },
          onHorizontalDragUpdate: (details) {
            if (chartPoints.isEmpty) return;
            final hit = _nearestPointByX(chartPoints, details.localPosition.dx);
            if (hit >= 0 && hit != _selectedIndex) {
              setState(() => _selectedIndex = hit);
              HapticFeedback.selectionClick();
            }
          },
          child: AnimatedBuilder(
            animation: _revealAnim,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _TrendPainter(
                  values: values,
                  points: chartPoints,
                  selectedIndex: _selectedIndex,
                  primaryColor: scheme.primary,
                  surfaceColor: scheme.surface,
                  gridColor: scheme.outlineVariant,
                  progress: _revealAnim.value,
                ),
                child: child,
              );
            },
            child: Stack(
              children: [
                // 月份刻度
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yy/MM').format(points.first.monthStart),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        DateFormat('yy/MM').format(points.last.monthStart),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                // 悬浮 Tooltip
                if (selected != null && selectedOffset != null)
                  _buildTooltip(context, selected, selectedOffset, constraints, scheme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    MonthlySpendPoint point,
    Offset offset,
    BoxConstraints constraints,
    ColorScheme scheme,
  ) {
    const cardW = 110.0;
    const cardH = 52.0;
    // 优先显示在点上方，空间不足则显示在下方
    double top = offset.dy - cardH - 10;
    if (top < 4) top = offset.dy + 14;
    final left = (offset.dx - cardW / 2).clamp(4.0, constraints.maxWidth - cardW - 4);

    return Positioned(
      left: left,
      top: top,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Material(
          key: ValueKey(point.monthStart),
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: cardW,
                height: cardH,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceVariant.withOpacity(0.90),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('yyyy 年 MM 月').format(point.monthStart),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '¥ ${point.total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
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
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.points,
    required this.selectedIndex,
    required this.primaryColor,
    required this.surfaceColor,
    required this.gridColor,
    required this.progress,
  });

  final List<double> values;
  final List<Offset> points;
  final int? selectedIndex;
  final Color primaryColor;
  final Color surfaceColor;
  final Color gridColor;
  final double progress;

  static const topPad = 20.0;
  static const bottomPad = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || points.isEmpty) return;

    // ---- 网格线（虚线风格） ----
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.28)
      ..strokeWidth = 0.8;
    for (var i = 1; i <= 2; i++) {
      final y = topPad + (size.height - topPad - bottomPad) * (i / 3);
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ---- 构建曲线路径 ----
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    // ---- 渐变填充 ----
    final baseY = size.height - bottomPad;
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, baseY)
      ..lineTo(points.first.dx, baseY)
      ..close();

    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, topPad),
        Offset(0, baseY),
        [
          primaryColor.withOpacity(0.22 * progress),
          primaryColor.withOpacity(0.0),
        ],
      );
    canvas.drawPath(fillPath, gradientPaint);

    // ---- 绘制折线（带进度） ----
    final pathMetric = linePath.computeMetrics().firstOrNull;
    final visiblePath = pathMetric == null
        ? linePath
        : pathMetric.extractPath(0, pathMetric.length * progress.clamp(0.0, 1.0));

    canvas.drawPath(
      visiblePath,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ---- 数据点 ----
    final visibleCount = math.max(1, (points.length * progress).ceil());
    for (var i = 0; i < visibleCount && i < points.length; i++) {
      final p = points[i];
      final isSelected = i == selectedIndex;
      final dotRadius = isSelected ? 5.5 : 3.5;
      // 外圈白色
      canvas.drawCircle(
          p, dotRadius + 1.5, Paint()..color = surfaceColor.withOpacity(progress));
      // 实心圆
      canvas.drawCircle(
          p,
          dotRadius,
          Paint()..color = isSelected ? primaryColor : primaryColor.withOpacity(0.7 * progress));
      // 选中时还画一个半透明光晕
      if (isSelected) {
        canvas.drawCircle(
          p,
          dotRadius + 5,
          Paint()..color = primaryColor.withOpacity(0.18),
        );
      }
    }

    // ---- 选中垂直指示线 ----
    if (selectedIndex != null && selectedIndex! < points.length) {
      final sel = points[selectedIndex!];
      canvas.drawLine(
        Offset(sel.dx, topPad),
        Offset(sel.dx, baseY),
        Paint()
          ..color = primaryColor.withOpacity(0.25)
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 4.0;
    const gapLen = 4.0;
    final total = (end - start).distance;
    final dir = (end - start) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segEnd = math.min(drawn + dashLen, total);
      canvas.drawLine(start + dir * drawn, start + dir * segEnd, paint);
      drawn += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) {
    return progress != old.progress ||
        selectedIndex != old.selectedIndex ||
        primaryColor != old.primaryColor ||
        gridColor != old.gridColor ||
        values.length != old.values.length;
  }
}
