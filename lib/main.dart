import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'database/database.dart';
import 'screens/home_screen.dart';
import 'screens/loans_screen.dart';
import 'screens/advances_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';
import 'services/auto_backup_service.dart';
import 'widgets/esc_to_back.dart';
import 'dart:io';

late AppDatabase database;

void main() {
  database = AppDatabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Quản lý tài chính',
      // Đặt ngôn ngữ tiếng Việt cho toàn app — nhờ đó showDatePicker và
      // các widget Material khác (như hộp thoại chọn ngày) sẽ tự động
      // hiển thị bằng tiếng Việt (tên tháng, "Hôm nay", "Hủy"...).
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      builder: (context, child) {
        final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
        Widget content = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(isDesktop ? 1.15 : 1.0),
          ),
          child: child!,
        );
        // Chỉ bật phím tắt Esc-để-quay-lại trên desktop, nơi có bàn phím vật lý.
        if (isDesktop) {
          content = EscToBack(child: content);
        }
        return content;
      },
      home: const MainNavigation(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkRemoteBackupOnStartup();
  }

  /// Nếu người dùng đã đăng nhập từ trước (silent sign-in), kiểm tra ngầm
  /// xem Drive có bản backup mới hơn không (ví dụ từ thiết bị khác) và
  /// tự động khôi phục nếu có — không chặn UI khởi động app.
  Future<void> _checkRemoteBackupOnStartup() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      AutoBackupService.instance.checkForRemoteUpdates();
    }
  }

  void _goToTab(int index) => setState(() => _currentIndex = index);

  /// Cài đặt không còn là một tab riêng — mở dưới dạng màn hình con từ
  /// nút bấm trên AppBar của tab Tổng quan.
  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Xây danh sách màn hình mỗi lần build để HomeScreen có thể nhận
    // callback chuyển tab (bấm vào thẻ trên Tổng quan -> nhảy sang tab)
    // và callback mở Cài đặt.
    final screens = [
      HomeScreen(onNavigateToTab: _goToTab, onOpenSettings: _openSettings),
      const LoansScreen(),
      const AdvancesScreen(),
      const ExpensesScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.handshake), label: 'Vay nợ'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Ứng trước'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Chi tiêu'),
        ],
      ),
    );
  }
}
