import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/advice_trigger_service.dart';
import '../../widget/app_motion.dart';

class AdvicePage extends ConsumerStatefulWidget {
  const AdvicePage({super.key});

  @override
  ConsumerState<AdvicePage> createState() => _AdvicePageState();
}

class _AdvicePageState extends ConsumerState<AdvicePage> {
  late Future<AdviceResult> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(adviceTriggerServiceProvider).getAdvice();
  }

  Future<void> _refresh({bool force = false}) async {
    setState(() {
      _future = ref.read(adviceTriggerServiceProvider).getAdvice(forceRefresh: force);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消费建议'),
        actions: [
          IconButton(
            onPressed: () => _refresh(force: true),
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: '重新分析',
          ),
        ],
      ),
      body: FutureBuilder<AdviceResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _AdviceLoadingState();
          }
          if (snapshot.hasError) {
            return AppStatePanel(
              icon: Icons.auto_awesome_outlined,
              title: '建议生成失败',
              message: snapshot.error.toString(),
              action: () => _refresh(force: true),
              actionLabel: '重新分析',
            );
          }

          final result = snapshot.data;
          if (result == null) {
            return AppStatePanel(
              icon: Icons.lightbulb_outline,
              title: '暂无建议',
              message: '当前还没有可展示的建议，稍后可以重新分析一次。',
              action: () => _refresh(force: true),
              actionLabel: '立即分析',
            );
          }

          return AppEntrance(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppEntrance(
                    delay: const Duration(milliseconds: 70),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: Icon(
                            result.usedCache ? Icons.bolt_outlined : Icons.auto_awesome,
                            size: 16,
                          ),
                          label: Text(result.usedCache ? '缓存建议（数据未变更）' : '最新建议'),
                        ),
                        Chip(label: Text('生成时间：${result.generatedAt.toLocal()}')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AppEntrance(
                      delay: const Duration(milliseconds: 120),
                      child: Card(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(14),
                          child: MarkdownBody(
                            data: result.content.isEmpty ? '暂无建议' : result.content,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                                .copyWith(
                              p: Theme.of(context).textTheme.bodyLarge,
                            ),
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
      ),
    );
  }
}

class _AdviceLoadingState extends StatelessWidget {
  const _AdviceLoadingState();

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPulsePlaceholder(
            child: Row(
              children: [
                _AdviceBlock(width: 128, height: 32, color: placeholderColor),
                const SizedBox(width: 8),
                _AdviceBlock(width: 176, height: 32, color: placeholderColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AppPulsePlaceholder(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AdviceBlock(width: 120, height: 18, color: placeholderColor),
                      const SizedBox(height: 12),
                      _AdviceBlock(width: double.infinity, height: 14, color: placeholderColor),
                      const SizedBox(height: 10),
                      _AdviceBlock(width: double.infinity, height: 14, color: placeholderColor),
                      const SizedBox(height: 10),
                      _AdviceBlock(width: MediaQuery.sizeOf(context).width * 0.55, height: 14, color: placeholderColor),
                      const SizedBox(height: 24),
                      _AdviceBlock(width: 160, height: 18, color: placeholderColor),
                      const SizedBox(height: 12),
                      _AdviceBlock(width: double.infinity, height: 14, color: placeholderColor),
                      const SizedBox(height: 10),
                      _AdviceBlock(width: double.infinity, height: 14, color: placeholderColor),
                      const SizedBox(height: 10),
                      _AdviceBlock(width: MediaQuery.sizeOf(context).width * 0.6, height: 14, color: placeholderColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceBlock extends StatelessWidget {
  const _AdviceBlock({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
