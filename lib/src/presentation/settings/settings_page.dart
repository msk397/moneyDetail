import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/deepseek/deepseek_client.dart';
import '../../infrastructure/settings/secure_settings_store.dart';
import '../../infrastructure/settings/settings_provider.dart';
import '../../sync/sync_service.dart';
import '../../widget/app_motion.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _notionTokenController = TextEditingController();
  final _databaseIdController = TextEditingController();
  final _deepSeekKeyController = TextEditingController();
  final _deepSeekBaseUrlController =
      TextEditingController(text: 'https://api.deepseek.com');
  final _deepSeekModelController = TextEditingController(text: 'deepseek-chat');

  bool _loading = true;
  bool _syncing = false;
  double? _syncProgress;
  String _syncMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = ref.read(settingsStoreProvider);
    _notionTokenController.text =
        await store.read(SecureSettingsStore.notionTokenKey);
    _databaseIdController.text =
        await store.read(SecureSettingsStore.notionDatabaseIdKey);
    _deepSeekKeyController.text =
        await store.read(SecureSettingsStore.deepSeekApiKeyKey);
    final baseUrl = await store.read(SecureSettingsStore.deepSeekBaseUrlKey);
    if (baseUrl.isNotEmpty) {
      _deepSeekBaseUrlController.text = baseUrl;
    }

    final model = await store.read(SecureSettingsStore.deepSeekModelKey);
    if (model.isNotEmpty) {
      _deepSeekModelController.text = model;
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final store = ref.read(settingsStoreProvider);
    await store.save(
      SecureSettingsStore.notionTokenKey,
      _notionTokenController.text,
    );
    await store.save(
      SecureSettingsStore.notionDatabaseIdKey,
      _databaseIdController.text,
    );
    await store.save(
      SecureSettingsStore.deepSeekApiKeyKey,
      _deepSeekKeyController.text,
    );
    await store.save(
      SecureSettingsStore.deepSeekBaseUrlKey,
      _deepSeekBaseUrlController.text,
    );
    await store.save(
      SecureSettingsStore.deepSeekModelKey,
      _deepSeekModelController.text,
    );

    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
    }
  }

  Future<void> _testNotion() async {
    try {
      final preview = await ref.read(syncServiceProvider).debugPreviewNotionResponse();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      _showDebugDialog('Notion 返回数据预览', preview);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showDebugDialog('Notion 请求失败', e.toString());
    }
  }

  Future<void> _testDeepSeek() async {
    final apiKey = _deepSeekKeyController.text.trim();
    final model = _deepSeekModelController.text.trim();
    final baseUrl = _deepSeekBaseUrlController.text.trim();
    if (apiKey.isEmpty || model.isEmpty) {
      HapticFeedback.heavyImpact();
      _showDebugDialog('DeepSeek 请求失败', '请先填写 DeepSeek API Key 和 Model');
      return;
    }

    try {
      final content = await ref.read(deepSeekClientProvider).createChatCompletion(
            apiKey: apiKey,
            model: model,
            baseUrl: baseUrl,
            prompt: '只回复: OK',
          );

      if (!mounted) return;
      HapticFeedback.selectionClick();
      _showDebugDialog('DeepSeek 返回数据预览', content.isEmpty ? '返回为空字符串' : content);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showDebugDialog('DeepSeek 请求失败', e.toString());
    }
  }

  Future<void> _startSync() async {
    if (_syncing) return;
    HapticFeedback.selectionClick();
    setState(() {
      _syncing = true;
      _syncProgress = 0;
      _syncMessage = '准备开始同步...';
    });
    try {
      final summary = await ref.read(syncServiceProvider).syncAll(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _syncProgress = progress.value;
            _syncMessage = progress.message;
          });
        },
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同步完成：推送 ${summary.pushed} 条，拉取 ${summary.pulled} 条'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
          _syncProgress = null;
        });
      }
    }
  }

  void _showDebugDialog(String title, String content) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(content),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _notionTokenController.dispose();
    _databaseIdController.dispose();
    _deepSeekKeyController.dispose();
    _deepSeekBaseUrlController.dispose();
    _deepSeekModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: const _SettingsLoadingState(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          AppEntrance(
            child: Card(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '安全提示：密钥仅保存在系统安全存储（Android Keystore / iOS Keychain），应用代码中不再保存明文默认值。',
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppEntrance(
            delay: const Duration(milliseconds: 60),
            child: _SettingsSection(
              title: 'Notion',
              child: Column(
                children: [
                  _buildField('Notion Token', _notionTokenController, obscure: true),
                  const SizedBox(height: 10),
                  _buildField('Notion Database ID', _databaseIdController),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppEntrance(
            delay: const Duration(milliseconds: 100),
            child: _SettingsSection(
              title: 'DeepSeek',
              child: Column(
                children: [
                  _buildField('DeepSeek API Key', _deepSeekKeyController, obscure: true),
                  const SizedBox(height: 10),
                  _buildField('DeepSeek Base URL', _deepSeekBaseUrlController),
                  const SizedBox(height: 10),
                  _buildField('DeepSeek Model', _deepSeekModelController),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppEntrance(
            delay: const Duration(milliseconds: 140),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存配置'),
            ),
          ),
          const SizedBox(height: 8),
          AppEntrance(
            delay: const Duration(milliseconds: 170),
            child: OutlinedButton.icon(
              onPressed: _syncing ? null : _startSync,
              icon: Icon(_syncing ? Icons.sync : Icons.sync),
              label: Text(_syncing ? '同步中...' : '立即同步'),
            ),
          ),
          if (_syncing || _syncMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: AppMotion.medium,
              child: Card(
                key: ValueKey('${_syncing}_${_syncMessage}_$_syncProgress'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _syncing ? Icons.cloud_sync_outlined : Icons.check_circle_outline,
                            size: 18,
                            color: _syncing
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _syncMessage.isEmpty ? '同步进行中...' : _syncMessage,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _syncProgress),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          AppEntrance(
            delay: const Duration(milliseconds: 210),
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _testNotion();
              },
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('测试 Notion 并查看返回'),
            ),
          ),
          const SizedBox(height: 8),
          AppEntrance(
            delay: const Duration(milliseconds: 240),
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _testDeepSeek();
              },
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('测试 DeepSeek 并查看返回'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool obscure = false}) {
    return _AnimatedSettingsField(
      label: label,
      controller: controller,
      obscure: obscure,
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _AnimatedSettingsField extends StatefulWidget {
  const _AnimatedSettingsField({
    required this.label,
    required this.controller,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;

  @override
  State<_AnimatedSettingsField> createState() => _AnimatedSettingsFieldState();
}

class _AnimatedSettingsFieldState extends State<_AnimatedSettingsField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.enterCurve,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (focused)
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscure,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _SettingsLoadingState extends StatelessWidget {
  const _SettingsLoadingState();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: AppPulsePlaceholder(
        child: Column(
          children: [
            _SettingsLoadingBlock(height: 64, color: color),
            const SizedBox(height: 10),
            _SettingsLoadingBlock(height: 170, color: color),
            const SizedBox(height: 10),
            _SettingsLoadingBlock(height: 220, color: color),
            const SizedBox(height: 16),
            _SettingsLoadingBlock(height: 48, color: color),
            const SizedBox(height: 8),
            _SettingsLoadingBlock(height: 48, color: color),
          ],
        ),
      ),
    );
  }
}

class _SettingsLoadingBlock extends StatelessWidget {
  const _SettingsLoadingBlock({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
