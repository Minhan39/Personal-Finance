import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/expense/expense_bloc.dart';
import '../../blocs/expense/expense_event.dart';
import '../../blocs/expense/expense_state.dart';
import '../../models/expense.dart';
import '../../service/expense_export_service.dart';
import '../../shared/helpers/number_helper.dart';
import '../../shared/ui/ui.dart';
import '../home/widgets/activity_tile.dart';
import 'widgets/add_expense_sheet.dart';
import 'widgets/expense_category_style.dart';
import 'widgets/expense_export_sheet.dart';

class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key});

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  bool _amountsVisible = false;
  bool _isExporting = false;

  /// Swiped-away rows, hidden until the bloc reloads without them.
  final _removedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadMonth(includeYear: true);
  }

  void _loadMonth({bool includeYear = false}) {
    final bloc = context.read<ExpenseBloc>();
    bloc.add(LoadExpenseDataEvent(month: _month, year: _year));
    bloc.add(LoadExpensesByMonthEvent(month: _month, year: _year));
    if (includeYear) bloc.add(LoadMonthlyDataEvent(year: _year));
  }

  void _selectMonth(int month, int year) {
    final yearChanged = year != _year;
    setState(() {
      _month = month;
      _year = year;
    });
    _loadMonth(includeYear: yearChanged);
  }

  Future<void> _refresh() async {
    final bloc = context.read<ExpenseBloc>();
    final done = bloc.stream.firstWhere(
      (state) => state is ExpenseLoaded || state is ExpenseError,
    );
    _loadMonth(includeYear: true);
    await done;
  }

  Future<void> _export() async {
    final range = await ExpenseExportSheet.show(
      context,
      initialMonth: _month,
      initialYear: _year,
    );
    if (range == null || !mounted) return;

    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ExpenseExportService.exportToXlsx(
        startMonth: range.start,
        endMonth: range.end,
      );
      final String message;
      if (result.isSuccess) {
        message =
            'Đã xuất ${result.expenseCount} giao dịch trong ${result.months} tháng.';
      } else if (result.isDismissed) {
        message =
            'Đã tạo file ${result.fileName}, nhưng bạn đã đóng màn hình chia sẻ.';
      } else {
        message =
            'Đã tạo file ${result.fileName}, nhưng thiết bị chưa hỗ trợ chia sẻ.';
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on ExpenseExportException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không thể xuất file XLSX lúc này.')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _money(double value, {bool compact = false}) {
    if (!_amountsVisible) return hiddenAmount;
    return compact
        ? NumberHelper.formatCompact(value)
        : NumberHelper.formatCurrency(value);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseBloc, ExpenseState>(
      listener: (context, state) {
        if (state is ExpenseAddSuccess || state is ExpenseDeleteSuccess) {
          context.read<ExpenseBloc>().add(
            LoadExpensesByMonthEvent(month: _month, year: _year),
          );
        }
        if (state is ExpenseError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      buildWhen: (previous, current) =>
          current is ExpenseLoaded ||
          current is ExpenseLoadingData ||
          current is ExpenseLoading,
      builder: (context, state) {
        final loaded = switch (state) {
          ExpenseLoaded() => (
            state.categoryData,
            state.monthlyData,
            state.expenses,
          ),
          ExpenseLoadingData() => (
            state.categoryData,
            state.monthlyData,
            state.expenses,
          ),
          _ => null,
        };

        return ModuleScaffold(
          title: 'Chi tiêu',
          onRefresh: _refresh,
          actions: [
            IconButton(
              onPressed: () =>
                  setState(() => _amountsVisible = !_amountsVisible),
              tooltip: _amountsVisible ? 'Ẩn số tiền' : 'Hiện số tiền',
              icon: Icon(
                _amountsVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            IconButton(
              onPressed: _isExporting ? null : _export,
              tooltip: 'Xuất XLSX',
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => AddExpenseSheet.show(context),
            icon: const Icon(Icons.add),
            label: const Text('Thêm chi tiêu'),
          ),
          children: [
            MonthStrip(month: _month, year: _year, onChanged: _selectMonth),
            if (loaded == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildSummary(context, loaded.$1, loaded.$2),
              _buildCategories(context, loaded.$1),
              _buildList(context, loaded.$3),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummary(
    BuildContext context,
    Map<String, double> categoryData,
    List<double> monthlyData,
  ) {
    final tone = ModuleTone.of(context, AppModule.spending);
    final total = categoryData.values.fold<double>(0, (acc, v) => acc + v);
    final previous = _month > 1 && monthlyData.length >= _month - 1
        ? monthlyData[_month - 2]
        : null;

    Widget? caption;
    if (total > 0 && previous != null && previous > 0) {
      final change = (total - previous) / previous * 100;
      caption = TrendCaption(
        text: change <= 0
            ? 'Ít hơn tháng trước ${change.abs().toStringAsFixed(0)}%'
            : 'Nhiều hơn tháng trước ${change.toStringAsFixed(0)}%',
        positive: change <= 0,
      );
    }

    return SummaryCard(
      label: 'Đã chi tháng $_month/$_year',
      value: _money(total),
      caption: caption,
      child: monthlyData.length == 12
          ? MiniBarChart(
              values: monthlyData,
              color: tone.accent,
              highlightIndex: _month - 1,
              labels: const ['T1', 'T6', 'T12'],
              onBarTap: (index) => _selectMonth(index + 1, _year),
            )
          : null,
    );
  }

  Widget _buildCategories(
    BuildContext context,
    Map<String, double> categoryData,
  ) {
    final total = categoryData.values.fold<double>(0, (acc, v) => acc + v);
    final entries = categoryData.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Theo danh mục'),
          const SizedBox(height: 12),
          for (final entry in entries) ...[
            _categoryRow(entry.key, entry.value, total),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(String key, double amount, double total) {
    final index = ExpenseCategoryStyle.indexOf(key);
    final share = total <= 0 ? 0.0 : amount / total;
    return ProgressRow(
      icon: ExpenseCategoryStyle.iconAt(index),
      color: ExpenseCategoryStyle.colorAt(index),
      label: ExpenseCategory.fromKey(key).displayName,
      value:
          '${_money(amount, compact: true)} · '
          '${(share * 100).toStringAsFixed(0)}%',
      fraction: share,
    );
  }

  Widget _buildList(BuildContext context, List<Map<String, dynamic>> all) {
    final expenses = all
        .where((expense) => !_removedIds.contains(expense['id']))
        .toList();
    if (expenses.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có chi tiêu trong tháng này',
        message: 'Bấm "Thêm chi tiêu" để ghi khoản đầu tiên.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Giao dịch'),
        for (final (day, items) in groupByDay(expenses, _dateOf)) ...[
          DayHeader(dayLabel(day)),
          for (final expense in items) _buildExpenseTile(expense),
        ],
      ],
    );
  }

  static DateTime _dateOf(Map<String, dynamic> expense) =>
      (expense['date'] as Timestamp).toDate();

  Widget _buildExpenseTile(Map<String, dynamic> expense) {
    final id = expense['id'] as String;
    final category = expense['category'] as String;
    final description = expense['description'] as String? ?? '';
    final amount = (expense['amount'] as num).toDouble();
    final date = _dateOf(expense);
    final index = ExpenseCategoryStyle.indexOf(category);
    final name = ExpenseCategory.fromKey(category).displayName;

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: const SwipeDeleteBackground(),
      confirmDismiss: (_) =>
          confirmDelete(context, 'Bạn có chắc muốn xoá khoản chi này?'),
      onDismissed: (_) {
        setState(() => _removedIds.add(id));
        context.read<ExpenseBloc>().add(DeleteExpenseEvent(id: id, date: date));
      },
      child: TransactionTile(
        icon: ExpenseCategoryStyle.iconAt(index),
        tone: ModuleTone.fromColor(
          context,
          ExpenseCategoryStyle.colorAt(index),
        ),
        title: description.isEmpty ? name : description,
        subtitle: description.isEmpty ? null : name,
        amount: _money(amount),
      ),
    );
  }
}
