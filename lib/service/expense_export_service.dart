import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';
import 'expense_service.dart';

class ExpenseExportService {
  static const int maxExportMonths = 12;

  static Future<ExpenseExportResult> exportToXlsx({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    final normalizedStart = DateTime(startMonth.year, startMonth.month);
    final normalizedEnd = DateTime(endMonth.year, endMonth.month);
    final totalMonths = _getMonthCount(normalizedStart, normalizedEnd);

    if (normalizedStart.isAfter(normalizedEnd)) {
      throw const ExpenseExportException(
        'Thang bat dau phai nho hon hoac bang thang ket thuc.',
      );
    }

    if (totalMonths > maxExportMonths) {
      throw const ExpenseExportException(
        'Ban chi co the xuat toi da 12 thang moi lan.',
      );
    }

    final expenses = await ExpenseService.getExpensesByRange(
      startMonth: normalizedStart,
      endMonth: normalizedEnd,
    );

    final excel = Excel.createExcel();
    final detailSheet = excel['Expenses'];
    final summarySheet = excel['Summary'];

    detailSheet.appendRow(_headerRow());

    for (final expense in expenses) {
      detailSheet.appendRow([
        TextCellValue(DateFormat('dd/MM/yyyy').format(expense.date)),
        TextCellValue(DateFormat('MM/yyyy').format(expense.date)),
        TextCellValue(expense.category),
        TextCellValue(ExpenseCategory.fromKey(expense.category).displayName),
        DoubleCellValue(expense.amount),
        TextCellValue(expense.description),
      ]);
    }

    summarySheet.appendRow([
      TextCellValue('Tu thang'),
      TextCellValue(DateFormat('MM/yyyy').format(normalizedStart)),
    ]);
    summarySheet.appendRow([
      TextCellValue('Den thang'),
      TextCellValue(DateFormat('MM/yyyy').format(normalizedEnd)),
    ]);
    summarySheet.appendRow([
      TextCellValue('So thang'),
      IntCellValue(totalMonths),
    ]);
    summarySheet.appendRow([
      TextCellValue('So giao dich'),
      IntCellValue(expenses.length),
    ]);
    summarySheet.appendRow([
      TextCellValue('Tong chi tieu'),
      DoubleCellValue(
        expenses.fold<double>(0, (sum, expense) => sum + expense.amount),
      ),
    ]);

    final sheetName = excel.getDefaultSheet();
    if (sheetName != null && sheetName != 'Expenses') {
      excel.delete(sheetName);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw const ExpenseExportException('Khong the tao file XLSX.');
    }

    final fileName =
        'expenses_${DateFormat('yyyyMM').format(normalizedStart)}_${DateFormat('yyyyMM').format(normalizedEnd)}.xlsx';

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: fileName,
          ),
        ],
        text:
            'Du lieu chi tieu tu ${DateFormat('MM/yyyy').format(normalizedStart)} den ${DateFormat('MM/yyyy').format(normalizedEnd)}',
        fileNameOverrides: [fileName],
      ),
    );

    return ExpenseExportResult(
      fileName: fileName,
      months: totalMonths,
      expenseCount: expenses.length,
      status: result.status,
    );
  }

  static List<CellValue> _headerRow() {
    return [
      TextCellValue('Ngay'),
      TextCellValue('Thang'),
      TextCellValue('Category Key'),
      TextCellValue('Danh muc'),
      TextCellValue('So tien'),
      TextCellValue('Mo ta'),
    ];
  }

  static int _getMonthCount(DateTime startMonth, DateTime endMonth) {
    return (endMonth.year - startMonth.year) * 12 +
        endMonth.month -
        startMonth.month +
        1;
  }
}

class ExpenseExportResult {
  const ExpenseExportResult({
    required this.fileName,
    required this.months,
    required this.expenseCount,
    required this.status,
  });

  final String fileName;
  final int months;
  final int expenseCount;
  final ShareResultStatus status;

  bool get isSuccess => status == ShareResultStatus.success;

  bool get isDismissed => status == ShareResultStatus.dismissed;
}

class ExpenseExportException implements Exception {
  const ExpenseExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
