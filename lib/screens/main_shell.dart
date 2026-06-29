import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'alerts/alerts_screen.dart';
import 'budget/budget_screen.dart';
import 'chatbot/chatbot_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'diary/diary_screen.dart';
import 'entry/add_entry_screen.dart';
import 'report/report_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.user});

  final User user;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    DashboardScreen(user: widget.user),
    DiaryScreen(user: widget.user),
    AddEntryScreen(user: widget.user),
    BudgetScreen(user: widget.user),
    ReportScreen(user: widget.user),
    ChatbotScreen(user: widget.user),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.instance.saveTokenForUser(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketStory'),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Thông báo & cảnh báo')),
                    body: AlertsScreen(user: widget.user),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.notifications_rounded),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => context.read<AuthService>().signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        onTap: (value) => setState(() => _index = value),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Tổng quan'),
          BottomNavigationBarItem(icon: Icon(Icons.photo_library_rounded), label: 'Nhật ký'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_rounded), label: 'Thêm'),
          BottomNavigationBarItem(icon: Icon(Icons.savings_rounded), label: 'Ngân sách'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Báo cáo'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_rounded), label: 'AI'),
        ],
      ),
    );
  }
}
