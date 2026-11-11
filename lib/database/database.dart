import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ==================== TÀI KHOẢN / VÍ ====================
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get balance => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ==================== KHOẢN VAY ====================
class Loans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get personName => text()();
  TextColumn get type => text()(); // 'vay' hoặc 'cho_vay'
  TextColumn get note => text().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
}

class LoanPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get loanId => integer().references(Loans, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get paymentDate => dateTime()();
  TextColumn get note => text().nullable()();
}

// Mỗi lần vay/cho vay cụ thể của một người (người = 1 dòng trong bảng Loans).
// Một người có thể có nhiều khoản vay khác nhau theo thời gian.
class LoanTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get loanId => integer().references(Loans, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get note => text().nullable()();
}

// ==================== ỨNG TRƯỚC ====================
@DataClassName('AdvanceBatch')
class AdvanceBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get purpose => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
}

class AdvanceExpenseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get batchId => integer().references(AdvanceBatches, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get description => text()();
}

class AdvanceReimbursements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get batchId => integer().references(AdvanceBatches, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get receivedDate => dateTime()();
  TextColumn get source => text().nullable()();
}

// ==================== CHI TIÊU ====================
// Chi tiêu hằng ngày, độc lập với Vay nợ / Ứng trước — mỗi dòng là một
// khoản chi cụ thể (không cần qua bước "đợt" như Ứng trước).
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get note => text().nullable()();
}

// ==================== DATABASE CHÍNH ====================
@DriftDatabase(tables: [
  Accounts,
  Loans,
  LoanPayments,
  LoanTransactions,
  AdvanceBatches,
  AdvanceExpenseItems,
  AdvanceReimbursements,
  Expenses,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;   // ← tăng từ 5 lên 6 (thêm bảng Expenses)

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(loanPayments, loanPayments.note);
        }
        if (from < 3) {
          await m.addColumn(advanceReimbursements, advanceReimbursements.source);
        }
        if (from < 4) {
          await m.createTable(loanTransactions);
          // Dữ liệu cũ: mỗi khoản vay (Loans) từng có sẵn 1 số tiền gốc +
          // 1 ngày vay ngay trên dòng người vay đó (cột principal_amount /
          // loan_date — đã bị xóa khỏi schema hiện tại ở bước from < 5 bên
          // dưới, nên phải đọc bằng SQL thô ở đây thay vì query có kiểu).
          // Chuyển số tiền gốc này thành khoản vay đầu tiên trong bảng
          // LoanTransactions để tổng "còn lại" không bị mất dữ liệu.
          final rows = await customSelect(
            'SELECT id, principal_amount, loan_date FROM loans',
          ).get();
          for (final row in rows) {
            final principal = row.read<double>('principal_amount');
            if (principal != 0) {
              await into(loanTransactions).insert(
                LoanTransactionsCompanion.insert(
                  loanId: row.read<int>('id'),
                  amount: principal,
                  transactionDate: row.read<DateTime>('loan_date'),
                ),
              );
            }
          }
        }
        if (from < 5) {
          // Dọn schema: 2 cột principal_amount/loan_date trên bảng loans
          // không còn dùng nữa (dữ liệu đã được chuyển sang loan_transactions
          // ở bước from < 4). SQLite không cho ALTER TABLE ... DROP COLUMN
          // trực tiếp ở mọi phiên bản, nên tạo lại bảng loans theo schema
          // mới rồi copy dữ liệu qua.
          await customStatement('PRAGMA foreign_keys = OFF');
          await customStatement('ALTER TABLE loans RENAME TO loans_v4');
          await m.createTable(loans);
          await customStatement(
            'INSERT INTO loans (id, person_name, type, note, is_settled) '
            'SELECT id, person_name, type, note, is_settled FROM loans_v4',
          );
          await customStatement('DROP TABLE loans_v4');
          await customStatement('PRAGMA foreign_keys = ON');
        }
        if (from < 6) {
          await m.createTable(expenses);
        }
      },
    );
  }
}

Future<File> getDatabaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  return File(p.join(dbFolder.path, 'quanlytaichinh.sqlite'));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await getDatabaseFile();
    return NativeDatabase.createInBackground(file);
  });
}
