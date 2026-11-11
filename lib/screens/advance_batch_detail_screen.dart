import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../database/database.dart';
import '../repositories/advance_repository.dart';
import '../utils/currency_input_formatter.dart';
import '../widgets/swipe_to_delete.dart';
import '../widgets/year_grouped_list.dart';
import 'add_advance_batch_screen.dart';
import 'package:drift/drift.dart' hide Column;

class AdvanceBatchDetailScreen extends StatefulWidget {
  final AdvanceBatch batch;
  const AdvanceBatchDetailScreen({super.key, required this.batch});

  @override
  State<AdvanceBatchDetailScreen> createState() => _AdvanceBatchDetailScreenState();
}

class _AdvanceBatchDetailScreenState extends State<AdvanceBatchDetailScreen> {
  late final AdvanceRepository _repo;
  final _currencyFormat = NumberFormat.decimalPattern('vi_VN');
  late AdvanceBatch _batch;
  double _spent = 0;
  double _reimbursed = 0;
  double _remaining = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
    _repo = AdvanceRepository(database);
    _loadData();
  }

  Future<void> _loadData() async {
    final spent = await _repo.getTotalSpent(_batch.id);
    final reimbursed = await _repo.getTotalReimbursed(_batch.id);
    final updated = await _repo.getBatchById(_batch.id);
    setState(() {
      _spent = spent;
      _reimbursed = reimbursed;
      _remaining = spent - reimbursed;
      _batch = updated;
      _loading = false;
    });
  }

  String _formatMoney(double amount) => '${_currencyFormat.format(amount)} ₫';

  Future<void> _editBatch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddAdvanceBatchScreen(batch: _batch)),
    );
    _loadData();
  }

  // ---------- Khoản chi: thêm / sửa / xóa ----------

  Future<void> _showExpenseDialog({AdvanceExpenseItem? existing}) async {
    final result = await showDialog<_ExpenseInput>(
      context: context,
      builder: (context) => _ExpenseDialog(existing: existing),
    );
    if (result == null) return;

    if (existing == null) {
      await _repo.addExpenseItem(
        batchId: _batch.id,
        amount: result.amount,
        expenseDate: result.date,
        description: result.description,
      );
    } else {
      await _repo.updateExpenseItem(
        id: existing.id,
        amount: result.amount,
        expenseDate: result.date,
        description: result.description,
      );
    }
    await _repo.syncSettledStatus(_batch.id);
    _loadData();
  }

  Future<void> _deleteExpense(AdvanceExpenseItem item) async {
    await _repo.deleteExpenseItem(item.id);
    await _repo.syncSettledStatus(_batch.id);
    _loadData();
  }

  // ---------- Hoàn ứng: thêm / sửa / xóa ----------

  Future<void> _showReimbursementDialog({AdvanceReimbursement? existing}) async {
    final result = await showDialog<_ReimbursementInput>(
      context: context,
      builder: (context) => _ReimbursementDialog(existing: existing),
    );
    if (result == null) return;

    if (existing == null) {
      await _repo.addReimbursement(
        batchId: _batch.id,
        amount: result.amount,
        receivedDate: result.date,
        source: result.source,
      );
    } else {
      await _repo.updateReimbursement(
        id: existing.id,
        amount: result.amount,
        receivedDate: result.date,
        source: result.source,
      );
    }
    await _repo.syncSettledStatus(_batch.id);
    _loadData();
  }

  Future<void> _deleteReimbursement(AdvanceReimbursement item) async {
    await _repo.deleteReimbursement(item.id);
    await _repo.syncSettledStatus(_batch.id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_batch.purpose),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editBatch),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.orange.shade700.withOpacity(0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Đã chi: ${_formatMoney(_spent)}'),
                        const SizedBox(height: 4),
                        Text('Đã hoàn ứng: ${_formatMoney(_reimbursed)}'),
                        const SizedBox(height: 4),
                        Text(
                          'Chưa lấy: ${_formatMoney(_remaining)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        if (_batch.note != null && _batch.note!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Ghi chú: ${_batch.note}'),
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
                        onPressed: () => _showExpenseDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm khoản chi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showReimbursementDialog(),
                        icon: const Icon(Icons.check),
                        label: const Text('Đã hoàn ứng'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Các khoản đã chi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Bấm vào để sửa. Vuốt (hoặc bấm icon thùng rác) để xóa.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                StreamBuilder<List<AdvanceExpenseItem>>(
                  stream: _repo.watchExpenseItems(_batch.id),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    return YearGroupedList<AdvanceExpenseItem>(
                      items: items,
                      dateOf: (e) => e.expenseDate,
                      emptyPlaceholder: const Text('Chưa có khoản chi nào.'),
                      summaryBuilder: (itemsInYear) => _formatMoney(
                        itemsInYear.fold<double>(0, (sum, e) => sum + e.amount),
                      ),
                      itemBuilder: (context, e) {
                        return SwipeToDelete(
                          itemKey: e.id,
                          confirmMessage: 'Xóa khoản chi "${e.description}"?',
                          onDelete: () => _deleteExpense(e),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            title: Text(e.description),
                            subtitle: Text(
                                '${e.expenseDate.day}/${e.expenseDate.month}/${e.expenseDate.year}'),
                            trailing: Text(_formatMoney(e.amount)),
                            onTap: () => _showExpenseDialog(existing: e),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text('Lịch sử hoàn ứng',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Bấm vào để sửa. Vuốt (hoặc bấm icon thùng rác) để xóa.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                StreamBuilder<List<AdvanceReimbursement>>(
                  stream: _repo.watchReimbursements(_batch.id),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    return YearGroupedList<AdvanceReimbursement>(
                      items: items,
                      dateOf: (r) => r.receivedDate,
                      emptyPlaceholder: const Text('Chưa hoàn ứng lần nào.'),
                      summaryBuilder: (itemsInYear) => _formatMoney(
                        itemsInYear.fold<double>(0, (sum, r) => sum + r.amount),
                      ),
                      itemBuilder: (context, r) {
                        return SwipeToDelete(
                          itemKey: r.id,
                          confirmMessage: 'Xóa lần hoàn ứng ${_formatMoney(r.amount)}?',
                          onDelete: () => _deleteReimbursement(r),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                            title: Text(_formatMoney(r.amount)),
                            subtitle: Text(
                              '${r.receivedDate.day}/${r.receivedDate.month}/${r.receivedDate.year}'
                              '${r.source != null && r.source!.isNotEmpty ? ' — Từ: ${r.source}' : ''}',
                            ),
                            onTap: () => _showReimbursementDialog(existing: r),
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

// ==================== Dialog: Khoản chi ====================

class _ExpenseInput {
  final double amount;
  final DateTime date;
  final String description;
  _ExpenseInput({required this.amount, required this.date, required this.description});
}

class _ExpenseDialog extends StatefulWidget {
  final AdvanceExpenseItem? existing;
  const _ExpenseDialog({this.existing});

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _descController;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountController = TextEditingController(
      text: e == null ? '' : NumberFormat.decimalPattern('vi_VN').format(e.amount.round()),
    );
    _descController = TextEditingController(text: e?.description ?? '');
    _date = e?.expenseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Thêm khoản chi' : 'Sửa khoản chi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Chi cho việc gì'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(labelText: 'Số tiền', suffixText: '₫'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ngày chi'),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            final amount = CurrencyInputFormatter.parse(_amountController.text);
            if (amount > 0 && _descController.text.trim().isNotEmpty) {
              Navigator.pop(
                context,
                _ExpenseInput(amount: amount, date: _date, description: _descController.text.trim()),
              );
            }
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

// ==================== Dialog: Hoàn ứng ====================

class _ReimbursementInput {
  final double amount;
  final DateTime date;
  final String? source;
  _ReimbursementInput({required this.amount, required this.date, this.source});
}

class _ReimbursementDialog extends StatefulWidget {
  final AdvanceReimbursement? existing;
  const _ReimbursementDialog({this.existing});

  @override
  State<_ReimbursementDialog> createState() => _ReimbursementDialogState();
}

class _ReimbursementDialogState extends State<_ReimbursementDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _sourceController;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _amountController = TextEditingController(
      text: r == null ? '' : NumberFormat.decimalPattern('vi_VN').format(r.amount.round()),
    );
    _sourceController = TextEditingController(text: r?.source ?? '');
    _date = r?.receivedDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Ghi nhận hoàn ứng' : 'Sửa lần hoàn ứng'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(labelText: 'Số tiền hoàn ứng', suffixText: '₫'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceController,
            decoration: const InputDecoration(
              labelText: 'Hoàn ứng từ đâu (tùy chọn)',
              hintText: 'VD: Kế toán công ty, Anh Tuấn...',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ngày nhận'),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            final amount = CurrencyInputFormatter.parse(_amountController.text);
            if (amount > 0) {
              Navigator.pop(
                context,
                _ReimbursementInput(
                  amount: amount,
                  date: _date,
                  source: _sourceController.text.trim().isEmpty ? null : _sourceController.text.trim(),
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