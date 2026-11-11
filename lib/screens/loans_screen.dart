import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../database/database.dart';
import '../repositories/loan_repository.dart';
import '../widgets/swipe_to_delete.dart';
import 'add_loan_screen.dart';
import 'loan_detail_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  late final LoanRepository _repo;
  final _currencyFormat = NumberFormat.decimalPattern('vi_VN');

  @override
  void initState() {
    super.initState();
    _repo = LoanRepository(database);
    // Tự động gộp các mục người vay/cho vay bị trùng tên đã lỡ tạo từ
    // trước (nếu có) — an toàn, không ảnh hưởng gì nếu không có gì trùng.
    _repo.mergeDuplicates();
  }

  String _formatMoney(double amount) => '${_currencyFormat.format(amount)} ₫';

  Future<void> _deleteLoan(Loan loan) async {
    await _repo.deleteLoan(loan.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vay nợ')),
      body: StreamBuilder<List<Loan>>(
        stream: _repo.watchAllLoans(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final loans = snapshot.data!;
          if (loans.isEmpty) {
            return const Center(
              child: Text('Chưa có khoản vay nào.\nBấm + để thêm mới.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: loans.length,
            itemBuilder: (context, index) {
              final loan = loans[index];
              final isDebt = loan.type == 'vay';
              return FutureBuilder<double>(
                future: _repo.getRemainingAmount(loan),
                builder: (context, remainingSnapshot) {
                  final remaining = remainingSnapshot.data ?? 0;
                  return SwipeToDelete(
                    itemKey: loan.id,
                    confirmMessage: 'Xóa khoản vay của "${loan.personName}"?',
                    onDelete: () => _deleteLoan(loan),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              (isDebt ? Colors.red : Colors.green).withOpacity(0.15),
                          child: Icon(
                            isDebt ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isDebt ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(loan.personName),
                        subtitle: Text(
                          isDebt ? 'Tôi nợ' : 'Cho vay',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatMoney(remaining),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: loan.isSettled
                                    ? Colors.grey
                                    : (isDebt ? Colors.red : Colors.green),
                              ),
                            ),
                            if (loan.isSettled)
                              const Text('Đã tất toán',
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoanDetailScreen(loan: loan),
                            ),
                          );
                          setState(() {}); // làm mới lại danh sách sau khi quay về
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddLoanScreen()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
