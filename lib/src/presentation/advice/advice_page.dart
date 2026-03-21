import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/advice_trigger_service.dart';

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
      appBar: AppBar(title: const Text('消费建议')),
      body: FutureBuilder<AdviceResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('建议生成失败：${snapshot.error}'));
          }

          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('暂无建议'));
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
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
                const SizedBox(height: 12),
                Expanded(
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
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _refresh(force: true),
        label: const Text('重新分析'),
        icon: const Icon(Icons.auto_awesome),
      ),
    );
  }
}
