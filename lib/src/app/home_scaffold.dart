import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../presentation/advice/advice_page.dart';
import '../presentation/dashboard/dashboard_page.dart';
import '../presentation/entry/quick_entry_page.dart';
import '../presentation/settings/settings_page.dart';
import '../widget/app_motion.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  late int _index;
  late final PageController _pageController;

  static const _pages = [
    DashboardPage(),
    QuickEntryPage(),
    AdvicePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.clamp(0, _pages.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectTab(int value) async {
    if (value == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = value);
    await _pageController.animateToPage(
      value,
      duration: AppMotion.slow,
      curve: AppMotion.emphasizedCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF151D24) : Colors.white;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (value) {
          if (value != _index) {
            setState(() => _index = value);
          }
        },
        children: const [
          DashboardPage(),
          QuickEntryPage(),
          AdvicePage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: NavigationBar(
            backgroundColor: navBg,
            indicatorColor: scheme.primaryContainer,
            selectedIndex: _index,
            animationDuration: AppMotion.medium,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '总览'),
              NavigationDestination(icon: Icon(Icons.edit_note_outlined), label: '记账'),
              NavigationDestination(icon: Icon(Icons.auto_graph_outlined), label: '建议'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
            ],
          ),
        ),
      ),
    );
  }
}
