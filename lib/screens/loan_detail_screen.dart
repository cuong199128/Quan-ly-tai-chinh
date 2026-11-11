import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../database/database.dart';
import '../repositories/loan_repository.dart';
import '../utils/currency_input_formatter.dart';
import '../widgets/swipe_to_delete.dart';
import '../widgets/year_grouped_list.dart';
import 'add_loan_screen.dart';

class LoanDetailScreen extends StatefulWidget {
  final Loan loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  late final LoanRepository _repo;
  final _currencyFormat = NumberFormat.decimalPattern('vi_VN');
  late Loan _loan;
  double _remaining = 0;
  double _totalBorrowed = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loan = widget.loan;
    _repo = LoanRepository(database);
    _loadData();
  }

  Future<void> _loadData() async {
    final borrowed = await _repo.getTotalBorrowed(_loan.id);
    final paid = await _repo.getTotalPaid(_loan.id);
    setState(() {
      _totalBorrowed = borrowed;
      _remaining = borrowed - paid;
      _loading = false;
    });
  }

  String _formatMoney(double amount) => '${_currencyFormat.format(amount)} ₫';

  Future<void> _editLoan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddLoanScreen(loan: _loan)),
    );
    final updated = await _repo.getLoanById(_loan.id);
    setState(() => _loan = updated);
    _loadData();
  }

  Future<void> _refreshAfterPaymentChange() async {
    await _repo.syncSettledStatus(_loan.id);
    final updated = await _repo.getLoanById(_loan.id);
    setState(() => _loan = updated);
    _loadData();
  }

  Future<void> _showAddTransactionDialog() async {
    final result = await showDialog<_TransactionInput>(
      context: context,
      builder: (context) => const _TransactionDialog(),
    );

    if (result != null) {
      await _repo.addTransaction(
        loanId: _loan.id,
        amount: result.amount,
        transactionDate: result.date,
        note: result.note,
      );
      await _refreshAfterPaymentChange();
    }
  }

  Future<void> _showEditTransactionDialog(LoanTransaction transaction) async {
    final result = await showDialog<_TransactionInput>(
      context: context,
      builder: (context) => _TransactionDialog(transaction: transaction),
    );

    if (result != null) {
      await _repo.updateTransaction(
        id: transaction.id,
        amount: result.amount,
        transactionDate: result.date,
        note: result.note,
      );
      await _refreshAfterPaymentChange();
    }
  }

  Future<void> _deleteTransaction(LoanTransaction transaction) async {
    await _repo.deleteTransaction(transaction.id);
    await _refreshAfterPaymentChange();
  }

  Future<void> _showAddPaymentDialog() async {
    final result = await showDialog<_PaymentInput>(
      context: context,
      builder: (context) => const _PaymentDialog(),
    );

    if (result != null) {
      await _repo.addPayment(
        loanId: _loan.id,
        amount: result.amount,
        paymentDate: result.date,
        note: result.note,
      );
      await _refreshAfterPaymentChange();
    }
  }

  Future<void> _showEditPaymentDialog(LoanPayment payment) async {
    final result = await showDialog<_PaymentInput>(
      context: context,
      builder: (context) => _PaymentDialog(payment: payment),
    );

    if (result != null) {
      await _repo.updatePayment(
        id: payment.id,
        amount: result.amount,
        paymentDate: result.date,
        note: result.note,
      );
      await _refreshAfterPaymentChange();
    }
  }

  Future<void> _deletePayment(LoanPayment payment) async {
    await _repo.deletePayment(payment.id);
    await _refreshAfterPaymentChange();
  }

  @override
  Widget build(BuildContext context) {
    final loan = _loan;
    final isDebt = loan.type == 'vay';

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.personName),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editLoan),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: (isDebt ? Colors.red : Colors.green).withOpacity(0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isDebt ? 'Tôi nợ' : 'Cho vay',
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Tổng đã vay: ${_formatMoney(_totalBorrowed)}'),
                        const SizedBox(height: 4),
                        Text(
                          'Còn lại: ${_formatMoney(_remaining)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDebt ? Colors.red : Colors.green,
                          ),
                        ),
                        if (loan.note != null && loan.note!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Ghi chú: ${loan.note}'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showAddTransactionDialog,
                        icon: const Icon(Icons.add_card),
                        label: const Text('Thêm khoản vay'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _showAddPaymentDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Ghi nhận trả nợ'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Các khoản vay',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Bấm vào để sửa. Vuốt (hoặc bấm icon thùng rác) để xóa.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                StreamBuilder<List<LoanTransaction>>(
                  stream: _repo.watchTransactions(loan.id),
                  builder: (context, snapshot) {
                    final transactions = snapshot.data ?? [];
                    return YearGroupedList<LoanTransaction>(
                      items: transactions,
                      dateOf: (t) => t.transactionDate,
                      emptyPlaceholder: const Text('Chưa có khoản vay nào.'),
                      summaryBuilder: (itemsInYear) => _formatMoney(
                        itemsInYear.fold<double>(0, (sum, t) => sum + t.amount),
                      ),
                      itemBuilder: (context, t) {
                        return SwipeToDelete(
                          itemKey: t.id,
                          confirmMessage:
                              'Xóa khoản vay ${_formatMoney(t.amount)} ngày ${t.transactionDate.day}/${t.transactionDate.month}/${t.transactionDate.year}?',
                          onDelete: () => _deleteTransaction(t),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.add_card_outlined),
                            title: Text(_formatMoney(t.amount)),
                            subtitle: Text(
                              '${t.transactionDate.day}/${t.transactionDate.month}/${t.transactionDate.year}'
                              '${t.note != null && t.note!.isNotEmpty ? ' — ${t.note}' : ''}',
                            ),
                            trailing: const Icon(Icons.edit, size: 20),
                            onTap: () => _showEditTransactionDialog(t),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text('Lịch sử trả',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Bấm vào để sửa. Vuốt (hoặc bấm icon thùng rác) để xóa.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                StreamBuilder<List<LoanPayment>>(
                  stream: (database.select(database.loanPayments)
                        ..where((p) => p.loanId.equals(loan.id)))
                      .watch(),
                  builder: (context, snapshot) {
                    final payments = snapshot.data ?? [];
                    return YearGroupedList<LoanPayment>(
                      items: payments,
                      dateOf: (p) => p.paymentDate,
                      emptyPlaceholder: const Text('Chưa có lần trả nào.'),
                      summaryBuilder: (itemsInYear) => _formatMoney(
                        itemsInYear.fold<double>(0, (sum, p) => sum + p.amount),
                      ),
                      itemBuilder: (context, p) {
                        return SwipeToDelete(
                          itemKey: p.id,
                          confirmMessage:
                              'Xóa lần trả ${_formatMoney(p.amount)} ngày ${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}?',
                          onDelete: () => _deletePayment(p),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text(_formatMoney(p.amount)),
                            subtitle: Text(
                              '${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}'
                              '${p.note != null && p.note!.isNotEmpty ? ' — ${p.note}' : ''}',
                            ),
                            trailing: const Icon(Icons.edit, size: 20),
                            onTap: () => _showEditPaymentDialog(p),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _TransactionInput {
  final double amount;
  final DateTime date;
  final String? note;
  _TransactionInput({required this.amount, required this.date, this.note});
}

class _TransactionDialog extends StatefulWidget {
  /// Khi khác null, dialog mở ở chế độ sửa với dữ liệu có sẵn.
  final LoanTransaction? transaction;
  const _TransactionDialog({this.transaction});

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _date;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _amountController = TextEditingController(
      text: t == null ? '' : NumberFormat.decimalPattern('vi_VN').format(t.amount.round()),
    );
    _noteController = TextEditingController(text: t?.note ?? '');
    _date = t?.transactionDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Sửa khoản vay' : 'Thêm khoản vay'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Số tiền vay',
              suffixText: '₫',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ngày vay'),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final amount = CurrencyInputFormatter.parse(_amountController.text);
            if (amount > 0) {
              Navigator.pop(
                context,
                _TransactionInput(
                  amount: amount,
                  date: _date,
                  note: _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim(),
                ),
              );
            }
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _PaymentInput {
  final double amount;
  final DateTime date;
  final String? note;
  _PaymentInput({required this.amount, required this.date, this.note});
}

class _PaymentDialog extends StatefulWidget {
  /// Khi khác null, dialog mở ở chế độ sửa với dữ liệu có sẵn.
  final LoanPayment? payment;
  const _PaymentDialog({this.payment});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _date;

  bool get _isEditing => widget.payment != null;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    _amountController = TextEditingController(
      text: p == null ? '' : NumberFormat.decimalPattern('vi_VN').format(p.amount.round()),
    );
    _noteController = TextEditingController(text: p?.note ?? '');
    _date = p?.paymentDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Sửa lần trả nợ' : 'Ghi nhận trả nợ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Số tiền trả',
              suffixText: '₫',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ngày trả'),
            subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final amount = CurrencyInputFormatter.parse(_amountController.text);
            if (amount > 0) {
              Navigator.pop(
                context,
                _PaymentInput(
                  amount: amount,
                  date: _date,
                  note: _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim(),
                ),
              );
            }
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
