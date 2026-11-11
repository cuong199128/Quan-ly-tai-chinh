import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../repositories/loan_repository.dart';
import '../repositories/advance_repository.dart';
import '../repositories/expense_repository.dart';

class HomeScreen extends StatefulWidget {
  /// Gọi khi người dùng bấm vào một thẻ, để MainNavigation chuyển sang
  /// tab tương ứng (0: Tổng quan, 1: Vay nợ, 2: Ứng trước, 3: Chi tiêu).
  final void Function(int tabIndex)? onNavigateToTab;

  /// Gọi khi người dùng bấm nút Cài đặt trên thanh AppBar.
  final VoidCallback? onOpenSettings;

  const HomeScreen({super.key, this.onNavigateToTab, this.onOpenSettings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _currencyFormat = NumberFormat.decimalPattern('vi_VN');

  late final LoanRepository _loanRepo;
  late final AdvanceRepository _advanceRepo;
  late final ExpenseRepository _expenseRepo;

  @override
  void initState() {
    super.initState();
    _loanRepo = LoanRepository(database);
    _advanceRepo = AdvanceRepository(database);
    _expenseRepo = ExpenseRepository(database);
  }

  String _formatMoney(double amount) => '${_currencyFormat.format(amount)} ₫';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Cài đặt',
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
      // Các thẻ tự làm mới theo dữ liệu (StreamBuilder) — không cần nút
      // làm mới thủ công nữa.
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<double>(
            stream: _loanRepo.watchTotalDebt(),
            builder: (context, snapshot) {
              return _buildCard(
                title: 'Tôi đang nợ',
                amount: snapshot.data ?? 0,
                color: Colors.red,
                icon: Icons.arrow_upward,
                onTap: () => widget.onNavigateToTab?.call(1),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<double>(
            stream: _loanRepo.watchTotalToCollect(),
            builder: (context, snapshot) {
              return _buildCard(
                title: 'Cần thu về (cho vay)',
                amount: snapshot.data ?? 0,
                color: Colors.green,
                icon: Icons.arrow_downward,
                onTap: () => widget.onNavigateToTab?.call(1),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<double>(
            stream: _advanceRepo.watchTotalRemaining(),
            builder: (context, snapshot) {
              return _buildCard(
                title: 'Chưa hoàn ứng (ứng trước)',
                amount: snapshot.data ?? 0,
                color: Colors.orange.shade700,
                icon: Icons.receipt_long,
                onTap: () => widget.onNavigateToTab?.call(2),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<double>(
            stream: _expenseRepo.watchTotalThisMonth(),
            builder: (context, snapshot) {
              return _buildCard(
                title: 'Chi tiêu tháng này',
                amount: snapshot.data ?? 0,
                color: Colors.blueGrey,
                icon: Icons.attach_money,
                onTap: () => widget.onNavigateToTab?.call(3),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(
          _formatMoney(amount),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      ),
    );
  }
}
