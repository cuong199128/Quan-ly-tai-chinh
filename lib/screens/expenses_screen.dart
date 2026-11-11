import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../database/database.dart';
import '../repositories/expense_repository.dart';
import '../widgets/swipe_to_delete.dart';
import '../widgets/year_grouped_list.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final ExpenseRepository _repo;
  final _currencyFormat = NumberFormat.decimalPattern('vi_VN');

  @override
  void initState() {
    super.initState();
    _repo = ExpenseRepository(database);
  }

  String _formatMoney(double amount) => '${_currencyFormat.format(amount)} ₫';

  Future<void> _deleteExpense(Expense expense) async {
    await _repo.deleteExpense(expense.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiêu')),
      body: StreamBuilder<List<Expense>>(
        stream: _repo.watchAllExpenses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final expenses = snapshot.data!;
          if (expenses.isEmpty) {
            return const Center(
              child: Text('Chưa có khoản chi nào.\nBấm + để thêm mới.',
                  textAlign: TextAlign.center),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(8),
            child: YearGroupedList<Expense>(
              items: expenses,
              dateOf: (e) => e.expenseDate,
              emptyPlaceholder: const Text('Chưa có khoản chi nào.'),
              summaryBuilder: (itemsInYear) => _formatMoney(
                itemsInYear.fold<double>(0, (sum, e) => sum + e.amount),
              ),
              itemBuilder: (context, expense) {
                return SwipeToDelete(
                  itemKey: expense.id,
                  confirmMessage: 'Xóa khoản chi "${expense.category}"?',
                  onDelete: () => _deleteExpense(expense),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey.withOpacity(0.15),
                        child: const Icon(Icons.attach_money, color: Colors.blueGrey),
                      ),
                      title: Text(expense.category),
                      subtitle: Text(
                        '${expense.expenseDate.day}/${expense.expenseDate.month}/${expense.expenseDate.year}'
                        '${expense.note != null && expense.note!.isNotEmpty ? ' — ${expense.note}' : ''}',
                      ),
                      trailing: Text(
                        _formatMoney(expense.amount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddExpenseScreen(expense: expense),
                          ),
                        );
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
