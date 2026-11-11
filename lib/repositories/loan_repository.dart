import 'dart:async';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../services/auto_backup_service.dart';

class LoanRepository {
  final AppDatabase db;
  LoanRepository(this.db);

  void _notifyChanged() => AutoBackupService.instance.notifyChanged();

  Future<List<Loan>> getAllLoans() => db.select(db.loans).get();

  Stream<List<Loan>> watchAllLoans() => db.select(db.loans).watch();

  Future<Loan> getLoanById(int id) =>
      (db.select(db.loans)..where((l) => l.id.equals(id))).getSingle();

  Future<int> addLoan({
    required String personName,
    required String type,
    String? note,
  }) async {
    final id = await db.into(db.loans).insert(LoansCompanion.insert(
          personName: personName,
          type: type,
          note: Value(note),
        ));
    _notifyChanged();
    return id;
  }

  Future<void> updateLoan({
    required int id,
    required String personName,
    required String type,
    String? note,
  }) async {
    await (db.update(db.loans)..where((l) => l.id.equals(id))).write(
      LoansCompanion(
        personName: Value(personName),
        type: Value(type),
        note: Value(note),
      ),
    );
    _notifyChanged();
  }

  Future<int> deleteLoan(int loanId) async {
    final result = await (db.delete(db.loans)..where((l) => l.id.equals(loanId))).go();
    _notifyChanged();
    return result;
  }

  Future<int> addPayment({
    required int loanId,
    required double amount,
    required DateTime paymentDate,
    String? note,
  }) async {
    final id = await db.into(db.loanPayments).insert(LoanPaymentsCompanion.insert(
          loanId: loanId,
          amount: amount,
          paymentDate: paymentDate,
          note: Value(note),
        ));
    _notifyChanged();
    return id;
  }

  Future<void> updatePayment({
    required int id,
    required double amount,
    required DateTime paymentDate,
    String? note,
  }) async {
    await (db.update(db.loanPayments)..where((p) => p.id.equals(id))).write(
      LoanPaymentsCompanion(
        amount: Value(amount),
        paymentDate: Value(paymentDate),
        note: Value(note),
      ),
    );
    _notifyChanged();
  }

  Future<int> deletePayment(int id) async {
    final result = await (db.delete(db.loanPayments)..where((p) => p.id.equals(id))).go();
    _notifyChanged();
    return result;
  }

  Future<double> getTotalPaid(int loanId) async {
    final query = db.selectOnly(db.loanPayments)
      ..addColumns([db.loanPayments.amount.sum()])
      ..where(db.loanPayments.loanId.equals(loanId));
    final result = await query.getSingle();
    return result.read(db.loanPayments.amount.sum()) ?? 0;
  }

  // ==================== KHOẢN VAY CỦA TỪNG NGƯỜI ====================
  // Một người (1 dòng Loans) có thể có nhiều khoản vay riêng lẻ theo thời gian.

  Future<int> addTransaction({
    required int loanId,
    required double amount,
    required DateTime transactionDate,
    String? note,
  }) async {
    final id = await db.into(db.loanTransactions).insert(LoanTransactionsCompanion.insert(
          loanId: loanId,
          amount: amount,
          transactionDate: transactionDate,
          note: Value(note),
        ));
    _notifyChanged();
    return id;
  }

  Future<void> updateTransaction({
    required int id,
    required double amount,
    required DateTime transactionDate,
    String? note,
  }) async {
    await (db.update(db.loanTransactions)..where((t) => t.id.equals(id))).write(
      LoanTransactionsCompanion(
        amount: Value(amount),
        transactionDate: Value(transactionDate),
        note: Value(note),
      ),
    );
    _notifyChanged();
  }

  Future<int> deleteTransaction(int id) async {
    final result = await (db.delete(db.loanTransactions)..where((t) => t.id.equals(id))).go();
    _notifyChanged();
    return result;
  }

  Stream<List<LoanTransaction>> watchTransactions(int loanId) {
    return (db.select(db.loanTransactions)
          ..where((t) => t.loanId.equals(loanId))
          ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<double> getTotalBorrowed(int loanId) async {
    final query = db.selectOnly(db.loanTransactions)
      ..addColumns([db.loanTransactions.amount.sum()])
      ..where(db.loanTransactions.loanId.equals(loanId));
    final result = await query.getSingle();
    return result.read(db.loanTransactions.amount.sum()) ?? 0;
  }

  Future<double> getRemainingAmount(Loan loan) async {
    final borrowed = await getTotalBorrowed(loan.id);
    final paid = await getTotalPaid(loan.id);
    return borrowed - paid;
  }

  Future<double> getTotalDebt() async {
    final loans = await (db.select(db.loans)
          ..where((l) => l.type.equals('vay') & l.isSettled.equals(false)))
        .get();
    double total = 0;
    for (final loan in loans) {
      total += await getRemainingAmount(loan);
    }
    return total;
  }

  Future<double> getTotalToCollect() async {
    final loans = await (db.select(db.loans)
          ..where((l) => l.type.equals('cho_vay') & l.isSettled.equals(false)))
        .get();
    double total = 0;
    for (final loan in loans) {
      total += await getRemainingAmount(loan);
    }
    return total;
  }

  /// Bản "watch" của [getTotalDebt] — tự phát ra giá trị mới mỗi khi có
  /// thay đổi ở bảng Loans / LoanTransactions / LoanPayments, để trang
  /// Tổng quan tự làm mới mà không cần nút bấm.
  Stream<double> watchTotalDebt() => _watchTotalByType('vay');

  /// Bản "watch" của [getTotalToCollect].
  Stream<double> watchTotalToCollect() => _watchTotalByType('cho_vay');

  Stream<double> _watchTotalByType(String type) async* {
    yield await (type == 'vay' ? getTotalDebt() : getTotalToCollect());
    await for (final _ in _watchRelevantTableChanges()) {
      yield await (type == 'vay' ? getTotalDebt() : getTotalToCollect());
    }
  }

  /// Phát ra một sự kiện mỗi khi Loans, LoanTransactions hoặc LoanPayments
  /// thay đổi — dùng làm "tín hiệu" để tính lại tổng.
  Stream<void> _watchRelevantTableChanges() {
    late final StreamController<void> controller;
    final subs = <StreamSubscription>[];
    controller = StreamController<void>.broadcast(
      onListen: () {
        subs.add(db.select(db.loans).watch().listen((_) => controller.add(null)));
        subs.add(db.select(db.loanTransactions).watch().listen((_) => controller.add(null)));
        subs.add(db.select(db.loanPayments).watch().listen((_) => controller.add(null)));
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<void> syncSettledStatus(int loanId) async {
    final loan = await getLoanById(loanId);
    final remaining = await getRemainingAmount(loan);
    await (db.update(db.loans)..where((l) => l.id.equals(loanId))).write(
      LoansCompanion(isSettled: Value(remaining <= 0)),
    );
    _notifyChanged();
  }

  // ==================== CHỐNG TRÙNG ====================

  /// Tìm một người vay/cho vay đã có sẵn, cùng tên (không phân biệt hoa
  /// thường, đã bỏ khoảng trắng thừa) và cùng loại (vay/cho vay).
  /// Dùng để cảnh báo trước khi tạo trùng một mục mới.
  Future<Loan?> findDuplicate({
    required String personName,
    required String type,
    int? excludeId,
  }) async {
    final normalized = personName.trim().toLowerCase();
    final all = await db.select(db.loans).get();
    for (final loan in all) {
      if (excludeId != null && loan.id == excludeId) continue;
      if (loan.type == type && loan.personName.trim().toLowerCase() == normalized) {
        return loan;
      }
    }
    return null;
  }

  /// Gộp các mục người vay/cho vay bị trùng (cùng tên, không phân biệt hoa
  /// thường, và cùng loại vay/cho vay) đã lỡ tạo từ trước thành 1 mục duy
  /// nhất: giữ lại mục tạo trước (id nhỏ nhất), dồn toàn bộ khoản vay và
  /// lần trả nợ của các mục trùng còn lại về mục được giữ, rồi xóa các
  /// mục trùng đó. An toàn khi gọi lại nhiều lần — nếu không có gì trùng
  /// thì không làm gì cả.
  Future<void> mergeDuplicates() async {
    final all = await db.select(db.loans).get();
    final Map<String, List<Loan>> groups = {};
    for (final loan in all) {
      final key = '${loan.type}|${loan.personName.trim().toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(loan);
    }

    var changed = false;
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort((a, b) => a.id.compareTo(b.id));
      final keep = group.first;
      for (final dup in group.skip(1)) {
        await (db.update(db.loanTransactions)..where((t) => t.loanId.equals(dup.id)))
            .write(LoanTransactionsCompanion(loanId: Value(keep.id)));
        await (db.update(db.loanPayments)..where((p) => p.loanId.equals(dup.id)))
            .write(LoanPaymentsCompanion(loanId: Value(keep.id)));
        await (db.delete(db.loans)..where((l) => l.id.equals(dup.id))).go();
        changed = true;
      }
      await syncSettledStatus(keep.id);
    }
    if (changed) _notifyChanged();
  }
}
