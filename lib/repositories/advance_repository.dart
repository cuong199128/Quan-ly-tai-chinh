import 'dart:async';
import 'package:drift/drift.dart';
import '../database/database.dart';
import '../services/auto_backup_service.dart';

class AdvanceRepository {
  final AppDatabase db;
  AdvanceRepository(this.db);

  void _notifyChanged() => AutoBackupService.instance.notifyChanged();

  Stream<List<AdvanceBatch>> watchAllBatches() =>
      db.select(db.advanceBatches).watch();

  Future<AdvanceBatch> getBatchById(int id) =>
      (db.select(db.advanceBatches)..where((b) => b.id.equals(id))).getSingle();

  Future<int> addBatch({required String purpose, String? note}) async {
    final id = await db.into(db.advanceBatches).insert(AdvanceBatchesCompanion.insert(
          purpose: purpose,
          note: Value(note),
        ));
    _notifyChanged();
    return id;
  }

  Future<void> updateBatch({
    required int id,
    required String purpose,
    String? note,
  }) async {
    await (db.update(db.advanceBatches)..where((b) => b.id.equals(id))).write(
      AdvanceBatchesCompanion(purpose: Value(purpose), note: Value(note)),
    );
    _notifyChanged();
  }

  Future<int> deleteBatch(int id) async {
    final result = await (db.delete(db.advanceBatches)..where((b) => b.id.equals(id))).go();
    _notifyChanged();
    return result;
  }

  Future<int> addExpenseItem({
    required int batchId,
    required double amount,
    required DateTime expenseDate,
    required String description,
  }) async {
    final id = await db.into(db.advanceExpenseItems).insert(
        AdvanceExpenseItemsCompanion.insert(
          batchId: batchId,
          amount: amount,
          expenseDate: expenseDate,
          description: description,
        ));
    _notifyChanged();
    return id;
  }

  Future<void> updateExpenseItem({
    required int id,
    required double amount,
    required DateTime expenseDate,
    required String description,
  }) async {
    await (db.update(db.advanceExpenseItems)..where((e) => e.id.equals(id))).write(
      AdvanceExpenseItemsCompanion(
        amount: Value(amount),
        expenseDate: Value(expenseDate),
        description: Value(description),
      ),
    );
    _notifyChanged();
  }

  Future<int> deleteExpenseItem(int id) async {
    final result = await (db.delete(db.advanceExpenseItems)..where((e) => e.id.equals(id))).go();
    _notifyChanged();
    return result;
  }

  Stream<List<AdvanceExpenseItem>> watchExpenseItems(int batchId) {
    return (db.select(db.advanceExpenseItems)
          ..where((e) => e.batchId.equals(batchId)))
        .watch();
  }

  Future<double> getTotalSpent(int batchId) async {
    final query = db.selectOnly(db.advanceExpenseItems)
      ..addColumns([db.advanceExpenseItems.amount.sum()])
      ..where(db.advanceExpenseItems.batchId.equals(batchId));
    final result = await query.getSingle();
    return result.read(db.advanceExpenseItems.amount.sum()) ?? 0;
  }

  Future<int> addReimbursement({
    required int batchId,
    required double amount,
    required DateTime receivedDate,
    String? source,
  }) async {
    final id = await db.into(db.advanceReimbursements).insert(
        AdvanceReimbursementsCompanion.insert(
          batchId: batchId,
          amount: amount,
          receivedDate: receivedDate,
          source: Value(source),
        ));
    _notifyChanged();
    return id;
  }

  Future<void> updateReimbursement({
    required int id,
    required double amount,
    required DateTime receivedDate,
    String? source,
  }) async {
    await (db.update(db.advanceReimbursements)..where((r) => r.id.equals(id))).write(
      AdvanceReimbursementsCompanion(
        amount: Value(amount),
        receivedDate: Value(receivedDate),
        source: Value(source),
      ),
    );
    _notifyChanged();
  }

  Future<int> deleteReimbursement(int id) async {
    final result = await (db.delete(db.advanceReimbursements)..where((r) => r.id.equals(id))).go();
    _notifyChanged();
    return result;
  }

  Stream<List<AdvanceReimbursement>> watchReimbursements(int batchId) {
    return (db.select(db.advanceReimbursements)
          ..where((r) => r.batchId.equals(batchId)))
        .watch();
  }

  Future<double> getTotalReimbursed(int batchId) async {
    final query = db.selectOnly(db.advanceReimbursements)
      ..addColumns([db.advanceReimbursements.amount.sum()])
      ..where(db.advanceReimbursements.batchId.equals(batchId));
    final result = await query.getSingle();
    return result.read(db.advanceReimbursements.amount.sum()) ?? 0;
  }

  Future<double> getRemainingToReceive(int batchId) async {
    final spent = await getTotalSpent(batchId);
    final reimbursed = await getTotalReimbursed(batchId);
    return spent - reimbursed;
  }

  Future<void> syncSettledStatus(int batchId) async {
    final remaining = await getRemainingToReceive(batchId);
    await (db.update(db.advanceBatches)..where((b) => b.id.equals(batchId))).write(
      AdvanceBatchesCompanion(isSettled: Value(remaining <= 0)),
    );
  }

  Future<double> getTotalRemaining() async {
    final batches = await (db.select(db.advanceBatches)
          ..where((b) => b.isSettled.equals(false)))
        .get();
    double total = 0;
    for (final batch in batches) {
      total += await getRemainingToReceive(batch.id);
    }
    return total;
  }

  /// Bản "watch" của [getTotalRemaining] — tự phát ra giá trị mới mỗi khi
  /// có thay đổi ở bảng AdvanceBatches / AdvanceExpenseItems /
  /// AdvanceReimbursements, để trang Tổng quan tự làm mới mà không cần
  /// nút bấm.
  Stream<double> watchTotalRemaining() async* {
    yield await getTotalRemaining();
    await for (final _ in _watchRelevantTableChanges()) {
      yield await getTotalRemaining();
    }
  }

  Stream<void> _watchRelevantTableChanges() {
    late final StreamController<void> controller;
    final subs = <StreamSubscription>[];
    controller = StreamController<void>.broadcast(
      onListen: () {
        subs.add(db.select(db.advanceBatches).watch().listen((_) => controller.add(null)));
        subs.add(db.select(db.advanceExpenseItems).watch().listen((_) => controller.add(null)));
        subs.add(db.select(db.advanceReimbursements).watch().listen((_) => controller.add(null)));
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
      },
    );
    return controller.stream;
  }

  // ==================== CHỐNG TRÙNG ====================

  /// Tìm một đợt ứng trước đã có sẵn, cùng mục đích/tên (không phân biệt
  /// hoa thường, đã bỏ khoảng trắng thừa). Dùng để cảnh báo trước khi tạo
  /// trùng một đợt mới.
  Future<AdvanceBatch?> findDuplicate({
    required String purpose,
    int? excludeId,
  }) async {
    final normalized = purpose.trim().toLowerCase();
    final all = await db.select(db.advanceBatches).get();
    for (final batch in all) {
      if (excludeId != null && batch.id == excludeId) continue;
      if (batch.purpose.trim().toLowerCase() == normalized) {
        return batch;
      }
    }
    return null;
  }

  /// Gộp các đợt ứng trước bị trùng (cùng mục đích/tên, không phân biệt
  /// hoa thường) đã lỡ tạo từ trước thành 1 đợt duy nhất: giữ lại đợt tạo
  /// trước (id nhỏ nhất), dồn toàn bộ khoản chi và lần hoàn ứng của các
  /// đợt trùng còn lại về đợt được giữ, rồi xóa các đợt trùng đó. An toàn
  /// khi gọi lại nhiều lần — nếu không có gì trùng thì không làm gì cả.
  Future<void> mergeDuplicates() async {
    final all = await db.select(db.advanceBatches).get();
    final Map<String, List<AdvanceBatch>> groups = {};
    for (final batch in all) {
      final key = batch.purpose.trim().toLowerCase();
      groups.putIfAbsent(key, () => []).add(batch);
    }

    var changed = false;
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort((a, b) => a.id.compareTo(b.id));
      final keep = group.first;
      for (final dup in group.skip(1)) {
        await (db.update(db.advanceExpenseItems)..where((e) => e.batchId.equals(dup.id)))
            .write(AdvanceExpenseItemsCompanion(batchId: Value(keep.id)));
        await (db.update(db.advanceReimbursements)..where((r) => r.batchId.equals(dup.id)))
            .write(AdvanceReimbursementsCompanion(batchId: Value(keep.id)));
        await (db.delete(db.advanceBatches)..where((b) => b.id.equals(dup.id))).go();
        changed = true;
      }
      await syncSettledStatus(keep.id);
    }
    if (changed) _notifyChanged();
  }
}
