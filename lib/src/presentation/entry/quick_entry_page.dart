import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/expense_service.dart';
import '../../domain/expense_category.dart';
import '../../infrastructure/db/db_provider.dart';
import '../../sync/sync_service.dart';
import '../../widget/app_motion.dart';
import '../../widget/widget_bridge.dart';

class QuickEntryPage extends ConsumerStatefulWidget {
  const QuickEntryPage({super.key});

  @override
  ConsumerState<QuickEntryPage> createState() => _QuickEntryPageState();
}

class _QuickEntryPageState extends ConsumerState<QuickEntryPage> {
  static const _phrasePrefsKey = 'quick_entry_custom_phrases';
  final _controller = TextEditingController();
  final _inputFocusNode = FocusNode();
  List<String> _quickPhrases = const [
    '早餐豆浆油条 12 元',
    '地铁+打车一共 24',
    '买课程花了 299',
  ];
  bool _loading = false;
  bool _inputFocused = false;

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_handleInputFocusChange);
    _loadQuickPhrases();
    _consumeWidgetQuickInput();
  }

  void _handleInputFocusChange() {
    if (!mounted) return;
    setState(() {
      _inputFocused = _inputFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _inputFocusNode
      ..removeListener(_handleInputFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawInput = _controller.text.trim();
    if (rawInput.isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      final service = ref.read(expenseServiceProvider);
      final parseResult = await service.parseExpenseFromText(rawInput);

      if (parseResult.deepSeekFailed) {
        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DeepSeek 暂时不可用，已切换本地规则解析')),
          );
        }
      }

      var draft = parseResult.draft;

      if (draft.confidence < ExpenseService.confidenceThreshold || draft.amount <= 0) {
        final confirmed = await _openConfirmDialog(draft);
        if (confirmed == null) {
          return;
        }
        draft = confirmed;
      }

      await service.saveExpenseDraft(draft, rawInput);
      final db = ref.read(appDatabaseProvider);
      final today = await db.getTodayTotal();
      final month = await db.getMonthTotal();
      await WidgetBridge.updateTotals(today: today, month: month);
      unawaited(_syncPendingCreatesInBackground());
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记账成功，云同步后台处理中')),
        );
        _controller.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _syncPendingCreatesInBackground() async {
    try {
      await ref.read(syncServiceProvider).syncPendingCreates();
    } catch (_) {
      // Keep user flow smooth; sync can be retried later.
    }
  }

  Future<void> _loadQuickPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_phrasePrefsKey) ?? const [];
    if (!mounted || list.isEmpty) return;
    setState(() {
      _quickPhrases = list;
    });
  }

  Future<void> _saveQuickPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_phrasePrefsKey, _quickPhrases);
  }

  Future<void> _addQuickPhrase() async {
    final controller = TextEditingController();
    final phrase = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加常用短句'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '例如：午饭牛肉面 22',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (phrase == null || phrase.isEmpty) return;
    if (_quickPhrases.contains(phrase)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _quickPhrases = [..._quickPhrases, phrase];
    });
    await _saveQuickPhrases();
  }

  Future<void> _consumeWidgetQuickInput() async {
    final pending = await WidgetBridge.consumePendingQuickInput();
    if (!mounted || pending.isEmpty) return;
    _controller.text = pending;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_loading) {
        _submit();
      }
    });
  }

  Future<ExpenseDraft?> _openConfirmDialog(ExpenseDraft draft) {
    final titleController = TextEditingController(text: draft.title);
    final amountController = TextEditingController(
      text: draft.amount <= 0 ? '' : draft.amount.toStringAsFixed(2),
    );
    ExpenseCategory category = draft.category;
    DateTime spentAt = draft.spentAt;

    return showDialog<ExpenseDraft>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('请确认账单信息'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('识别置信度：${(draft.confidence * 100).toStringAsFixed(0)}%'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '金额',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ExpenseCategory>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: '分类',
                        border: OutlineInputBorder(),
                      ),
                      items: ExpenseCategory.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => category = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final pickedDate = await showDatePicker(
                          context: context,
                          firstDate: DateTime(now.year - 2),
                          lastDate: DateTime(now.year + 2),
                          initialDate: spentAt,
                        );
                        if (pickedDate == null || !context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(spentAt),
                        );
                        if (pickedTime == null) return;
                        setState(() {
                          spentAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '时间',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('yyyy-MM-dd HH:mm').format(spentAt)),
                            const Icon(Icons.edit_calendar_outlined),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(amountController.text.trim()) ?? 0;
                    if (titleController.text.trim().isEmpty || amount <= 0) {
                      HapticFeedback.heavyImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请填写有效标题和金额')),
                      );
                      return;
                    }
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop(
                      draft.copyWith(
                        title: titleController.text.trim(),
                        amount: amount,
                        category: category,
                        spentAt: spentAt,
                      ),
                    );
                  },
                  child: const Text('确认保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记账'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          const AppEntrance(
            child: _EntryHeroCard(),
          ),
          const SizedBox(height: 14),
          AppEntrance(
            delay: const Duration(milliseconds: 80),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.medium,
                      curve: AppMotion.enterCurve,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (_inputFocused)
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _inputFocusNode,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '输入自然语言账单内容',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '常用短句',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _addQuickPhrase();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('自定义'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickPhrases
                          .asMap()
                          .entries
                          .map(
                            (entry) => AppEntrance(
                              delay: Duration(milliseconds: 100 + entry.key * 35),
                              child: _ExampleChip(
                                text: entry.value,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _controller.text = entry.value;
                                  _inputFocusNode.requestFocus();
                                },
                                onDelete: () async {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _quickPhrases = _quickPhrases
                                        .where((it) => it != entry.value)
                                        .toList();
                                  });
                                  await _saveQuickPhrases();
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppEntrance(
            delay: const Duration(milliseconds: 150),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        _submit();
                      },
                icon: const Icon(Icons.send_outlined),
                label: Text(_loading ? '处理中...' : '记一笔'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryHeroCard extends StatelessWidget {
  const _EntryHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '记账',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '输入一句话，自动识别金额与分类',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({
    required this.text,
    required this.onTap,
    required this.onDelete,
  });

  final String text;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.bolt, size: 16),
      label: Text(text),
      onPressed: onTap,
      onDeleted: onDelete,
    );
  }
}
