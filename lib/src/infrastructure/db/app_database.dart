import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get notionPageId => text().nullable()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  DateTimeColumn get spentAt => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get syncState =>
      text().withDefault(const Constant('PENDING_CREATE'))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Stream<double> watchTodayTotal() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _watchRangeTotal(start, end);
  }

  Future<double> getTodayTotal() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _getRangeTotal(start, end);
  }

  Stream<double> watchMonthTotal() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return _watchRangeTotal(start, end);
  }

  Future<double> getMonthTotal() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return _getRangeTotal(start, end);
  }

  Stream<double> watchYearTotal() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year + 1, 1, 1);
    return _watchRangeTotal(start, end);
  }

  Stream<double> _watchRangeTotal(DateTime start, DateTime end) {
    const sql = '''
      SELECT COALESCE(SUM(amount), 0.0) AS total
      FROM expenses
      WHERE spent_at >= ? AND spent_at < ? AND amount > 0
    ''';
    return customSelect(
      sql,
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {expenses},
    ).watchSingle().map((row) => row.read<double>('total'));
  }

  Future<double> _getRangeTotal(DateTime start, DateTime end) async {
    const sql = '''
      SELECT COALESCE(SUM(amount), 0.0) AS total
      FROM expenses
      WHERE spent_at >= ? AND spent_at < ? AND amount > 0
    ''';
    final row = await customSelect(
      sql,
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
    ).getSingle();
    return row.read<double>('total');
  }

  Stream<List<Expense>> watchCurrentMonthExpenses() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final query = select(expenses)
      ..where((tbl) => tbl.spentAt.isBiggerOrEqualValue(start))
      ..where((tbl) => tbl.spentAt.isSmallerThanValue(end))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.spentAt)]);

    return query.watch();
  }

  Stream<List<Expense>> watchExpensesInRange(DateTime start, DateTime end) {
    final query = select(expenses)
      ..where((tbl) => tbl.spentAt.isBiggerOrEqualValue(start))
      ..where((tbl) => tbl.spentAt.isSmallerThanValue(end))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.spentAt)]);

    return query.watch();
  }

  Stream<List<MonthlySpendPoint>> watchRecent12MonthTotals() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 11, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final query = select(expenses)
      ..where((tbl) => tbl.spentAt.isBiggerOrEqualValue(start))
      ..where((tbl) => tbl.spentAt.isSmallerThanValue(end));

    return query.watch().map((rows) {
      final monthMap = <String, double>{};
      for (final row in rows) {
        if (row.amount <= 0) {
          continue;
        }
        final monthStart = DateTime(row.spentAt.year, row.spentAt.month, 1);
        final key = '${monthStart.year.toString().padLeft(4, '0')}-${monthStart.month.toString().padLeft(2, '0')}';
        monthMap[key] = (monthMap[key] ?? 0) + row.amount;
      }

      final points = <MonthlySpendPoint>[];
      for (var i = 0; i < 12; i++) {
        final monthStart = DateTime(start.year, start.month + i, 1);
        final key = '${monthStart.year.toString().padLeft(4, '0')}-${monthStart.month.toString().padLeft(2, '0')}';
        points.add(
          MonthlySpendPoint(
            monthStart: monthStart,
            total: monthMap[key] ?? 0,
          ),
        );
      }
      return points;
    });
  }

  Stream<double> watchMonthIncomeTotal() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    const sql = '''
      SELECT COALESCE(SUM(-amount), 0.0) AS total
      FROM expenses
      WHERE spent_at >= ? AND spent_at < ? AND amount < 0
    ''';
    return customSelect(
      sql,
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {expenses},
    ).watchSingle().map((row) => row.read<double>('total'));
  }

  Stream<double> watchMonthNetTotal() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    const sql = '''
      SELECT COALESCE(SUM(CASE WHEN amount < 0 THEN -amount ELSE 0 END), 0.0)
      - COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0.0) AS total
      FROM expenses
      WHERE spent_at >= ? AND spent_at < ?
    ''';
    return customSelect(
      sql,
      variables: [Variable<DateTime>(start), Variable<DateTime>(end)],
      readsFrom: {expenses},
    ).watchSingle().map((row) => row.read<double>('total'));
  }

  Future<void> insertExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    required DateTime spentAt,
    String? notionPageId,
    String syncState = 'PENDING_CREATE',
    String? note,
  }) {
    final now = DateTime.now();
    return into(expenses).insert(
      ExpensesCompanion.insert(
        id: id,
        notionPageId: Value(notionPageId),
        title: title,
        amount: amount,
        category: category,
        spentAt: spentAt,
        note: Value(note),
        syncState: Value(syncState),
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> upsertExpenseFromNotion({
    required String notionPageId,
    required String title,
    required double amount,
    required String category,
    required DateTime spentAt,
    String? note,
  }) async {
    final existing = await (select(expenses)
          ..where((tbl) => tbl.notionPageId.equals(notionPageId))
          ..limit(1))
        .getSingleOrNull();

    final now = DateTime.now();
    if (existing == null) {
      final localDuplicate = await (select(expenses)
            ..where(
              (tbl) =>
                  tbl.notionPageId.isNull() &
                  tbl.title.equals(title) &
                  tbl.amount.equals(amount) &
                  tbl.spentAt.isBiggerOrEqualValue(
                    spentAt.subtract(const Duration(minutes: 5)),
                  ) &
                  tbl.spentAt.isSmallerOrEqualValue(
                    spentAt.add(const Duration(minutes: 5)),
                  ),
            )
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

      if (localDuplicate != null) {
        await (update(expenses)..where((tbl) => tbl.id.equals(localDuplicate.id))).write(
          ExpensesCompanion(
            notionPageId: Value(notionPageId),
            title: Value(title),
            amount: Value(amount),
            category: Value(category),
            spentAt: Value(spentAt),
            note: Value(note),
            syncState: const Value('SYNCED'),
            updatedAt: Value(now),
          ),
        );
        return;
      }

      await into(expenses).insert(
        ExpensesCompanion.insert(
          id: now.microsecondsSinceEpoch.toString(),
          notionPageId: Value(notionPageId),
          title: title,
          amount: amount,
          category: category,
          spentAt: spentAt,
          note: Value(note),
          syncState: const Value('SYNCED'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }

    await (update(expenses)..where((tbl) => tbl.id.equals(existing.id))).write(
      ExpensesCompanion(
        title: Value(title),
        amount: Value(amount),
        category: Value(category),
        spentAt: Value(spentAt),
        note: Value(note),
        syncState: const Value('SYNCED'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<Expense?> getExpenseById(String id) {
    return (select(expenses)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<List<Expense>> getPendingCreateExpenses() {
    return (select(expenses)..where((tbl) => tbl.syncState.equals('PENDING_CREATE'))).get();
  }
}

class MonthlySpendPoint {
  MonthlySpendPoint({required this.monthStart, required this.total});

  final DateTime monthStart;
  final double total;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'money_detail.sqlite'));
    return NativeDatabase(file);
  });
}
