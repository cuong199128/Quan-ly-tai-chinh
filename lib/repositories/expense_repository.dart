import 'package:drift/drift.dart';
import '../database/database.dart';
import '../services/auto_backup_service.dart';

class ExpenseRepository {
  final AppDatabase db;
  ExpenseRepository(this.db);

  void _notifyChanged() => AutoBackupService.instance.notifyChanged();

  Stream<List<Expense>> watchAllExpenses() {
    return (db.select(db.expenses)
          ..orderBy([(e) => OrderingTerm(expression: e.expenseDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<Expense> getExpenseById(int id) =>
      (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingle();

  Future<int> addExpense({
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? note,
  }) async {
    final id = await db.into(db.expenses).insert(ExpensesCompanion.insert(
          amount: amount,
          category: category,
          expenseDate: expenseDate,
          note: Value(note),
        ));
    _notifyChanged();
    return id;
  }

  Future<void> updateExpense({
    required int id,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? note,
  }) async {
    await (db.update(db.expenses)..where((e) => e.id.equals(id))).write(
      ExpensesCompanion(
        amount: Value(amount),
        category: Value(category),
        expenseDate: Value(expenseDate),
        note: Value(note),
      ),
    );
    _notifyChanged();
  }

  Future<int> deleteExpense(int id) async {
    final result = await (db.delete(db.expenses)..where((e) => e.id.equals(id))).go();
    _notifyChanged();
    return result;
  }

  /// Tổng chi tiêu trong tháng hiện tại — tự cập nhật khi có thay đổi
  /// (thêm/sửa/xóa khoản chi), dùng cho thẻ tổng quan ở trang chủ.
  ///
  /// Lọc và cộng trực tiếp trên danh sách đã lấy từ [watchAllExpenses]
  /// (thay vì lọc bằng điều kiện khoảng ngày trong câu SQL) để chắc chắn
  /// chỉ tính đúng các khoản có cùng tháng/năm với hiện tại.
  Stream<double> watchTotalThisMonth() {
    final now = DateTime.now();
    return watchAllExpenses().map((expenses) {
      return expenses
          .where((e) => e.expenseDate.year == now.year && e.expenseDate.month == now.month)
          .fold<double>(0, (sum, e) => sum + e.amount);
    });
  }
}
