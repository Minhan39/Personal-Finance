import 'package:flutter/material.dart';

import '../../../service/expense_export_service.dart';
import 'sheet_header.dart';

/// Lets the user pick a month range to export. Pops the chosen range, or
/// `null` when closed.
class ExpenseExportSheet extends StatefulWidget {
  const ExpenseExportSheet({
    super.key,
    required this.initialMonth,
    required this.initialYear,
  });

  final int initialMonth;
  final int initialYear;

  static Future<DateTimeRange?> show(
    BuildContext context, {
    required int initialMonth,
    required int initialYear,
  }) {
    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseExportSheet(
        initialMonth: initialMonth,
        initialYear: initialYear,
      ),
    );
  }

  @override
  State<ExpenseExportSheet> createState() => _ExpenseExportSheetState();
}

class _ExpenseExportSheetState extends State<ExpenseExportSheet> {
  late final List<int> _years;
  late int _startMonth = widget.initialMonth;
  late int _startYear = widget.initialYear;
  late int _endMonth = widget.initialMonth;
  late int _endYear = widget.initialYear;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _years = List<int>.generate(
      now.year - 2019,
      (index) => 2020 + index,
    ).reversed.toList();
  }

  int get _totalMonths =>
      (_endYear - _startYear) * 12 + _endMonth - _startMonth + 1;

  void _submit() {
    final startDate = DateTime(_startYear, _startMonth);
    final endDate = DateTime(_endYear, _endMonth);

    if (startDate.isAfter(endDate)) {
      setState(() {
        _errorText = 'Tháng bắt đầu phải nhỏ hơn hoặc bằng tháng kết thúc.';
      });
      return;
    }

    if (_totalMonths > ExpenseExportService.maxExportMonths) {
      setState(() {
        _errorText = 'Bạn chỉ có thể xuất tối đa 12 tháng mỗi lần.';
      });
      return;
    }

    Navigator.pop(context, DateTimeRange(start: startDate, end: endDate));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHeader(title: 'Xuất dữ liệu chi tiêu')),
              const SizedBox(height: 8),
              Text(
                'Chọn khoảng tháng cần xuất. Tối đa 12 tháng.',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              _MonthYearPicker(
                title: 'Từ tháng',
                selectedMonth: _startMonth,
                selectedYear: _startYear,
                years: _years,
                onMonthChanged: (value) => setState(() {
                  _startMonth = value;
                  _errorText = null;
                }),
                onYearChanged: (value) => setState(() {
                  _startYear = value;
                  _errorText = null;
                }),
              ),
              const SizedBox(height: 12),
              _MonthYearPicker(
                title: 'Đến tháng',
                selectedMonth: _endMonth,
                selectedYear: _endYear,
                years: _years,
                onMonthChanged: (value) => setState(() {
                  _endMonth = value;
                  _errorText = null;
                }),
                onYearChanged: (value) => setState(() {
                  _endYear = value;
                  _errorText = null;
                }),
              ),
              const SizedBox(height: 12),
              Text(
                'Số tháng đã chọn: $_totalMonths',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _totalMonths > ExpenseExportService.maxExportMonths
                      ? Colors.red
                      : colorScheme.primary,
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(_errorText!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        shadowColor: Colors.transparent,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Xuất file'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthYearPicker extends StatelessWidget {
  const _MonthYearPicker({
    required this.title,
    required this.selectedMonth,
    required this.selectedYear,
    required this.years,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  final String title;
  final int selectedMonth;
  final int selectedYear;
  final List<int> years;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(labelText: 'Tháng'),
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text('Tháng $month'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) onMonthChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(labelText: 'Năm'),
                  items: years
                      .map(
                        (year) => DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onYearChanged(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
