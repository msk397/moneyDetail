import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/deepseek/deepseek_client.dart';
import '../../infrastructure/settings/secure_settings_store.dart';
import '../../infrastructure/settings/settings_provider.dart';
import '../../sync/sync_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
    }
  }

  Future<void> _testNotion() async {
    try {
      final preview = await ref.read(syncServiceProvider).debugPreviewNotionResponse();
      if (!mounted) return;
      _showDebugDialog('Notion 返回数据预览', preview);
    } catch (e) {
      if (!mounted) return;
      _showDebugDialog('Notion 请求失败', e.toString());
    }
  }

  Future<void> _testDeepSeek() async {
    final apiKey = _deepSeekKeyController.text.trim();
    final model = _deepSeekModelController.text.trim();
    final baseUrl = _deepSeekBaseUrlController.text.trim();
    if (apiKey.isEmpty || model.isEmpty) {
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
      _showDebugDialog('DeepSeek 返回数据预览', content.isEmpty ? '返回为空字符串' : content);
    } catch (e) {
      if (!mounted) return;
      _showDebugDialog('DeepSeek 请求失败', e.toString());
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '安全提示：密钥仅保存在系统安全存储（Android Keystore / iOS Keychain），应用代码中不再保存明文默认值。',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notion', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _buildField('Notion Token', _notionTokenController, obscure: true),
                  const SizedBox(height: 10),
                  _buildField('Notion Database ID', _databaseIdController),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DeepSeek', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
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
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存配置'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final summary = await ref.read(syncServiceProvider).syncAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('同步完成：推送 ${summary.pushed} 条，拉取 ${summary.pulled} 条'),
                ),
              );
            },
            icon: const Icon(Icons.sync),
            label: const Text('立即同步'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testNotion,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('测试 Notion 并查看返回'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testDeepSeek,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('测试 DeepSeek 并查看返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
