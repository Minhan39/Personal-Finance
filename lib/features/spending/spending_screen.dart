import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:personal_finance/shared/helpers/number_helper.dart';

import '../../blocs/expense/expense_bloc.dart';
import '../../blocs/expense/expense_event.dart';
import '../../blocs/expense/expense_state.dart';
import '../../models/expense.dart';
import '../../service/expense_export_service.dart';
import '../../shared/widgets/linear_header.dart';
import 'widgets/add_expense_sheet.dart';
import 'widgets/expense_category_style.dart';
import 'widgets/expense_export_sheet.dart';
import 'widgets/monthly_expense_details_sheet.dart';

class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key});

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  bool _isShow = false;
  bool _isExporting = false;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  List<String> get _categoryKeys => ExpenseCategory.allKeys;

  List<String> get _categoryName => ExpenseCategory.allDisplayNames;

  final List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<ExpenseBloc>().add(
      LoadExpenseDataEvent(month: _selectedMonth, year: _selectedYear),
    );
    context.read<ExpenseBloc>().add(LoadMonthlyDataEvent(year: _selectedYear));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state is ExpenseAddSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is ExpenseDeleteSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is ExpenseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearHeader(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text(
                                'CHI TIÊU',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          // Year selector
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedYear,
                                dropdownColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                style: TextStyle(fontSize: 14),
                                items: List.generate(5, (index) {
                                  int year = DateTime.now().year - index;
                                  return DropdownMenuItem(
                                    value: year,
                                    child: Text(
                                      year.toString(),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedYear = value!;
                                  });
                                  _loadData();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Expanded(
                        child: BlocBuilder<ExpenseBloc, ExpenseState>(
                          builder: (context, state) {
                            if (state is ExpenseLoading) {
                              return Center(child: CircularProgressIndicator());
                            }

                            Map<String, double> categoryData = {};
                            if (state is ExpenseLoaded) {
                              categoryData = state.categoryData;
                            } else if (state is ExpenseLoadingData) {
                              categoryData = state.categoryData;
                            }

                            return Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: PieChart(
                                    PieChartData(
                                      sections: _buildPieChartSections(
                                        categoryData,
                                      ),
                                      centerSpaceRadius: 40,
                                      sectionsSpace: 2,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (
                                          int i = 0;
                                          i < _categoryName.length;
                                          i++
                                        )
                                          _buildLegendItem(
                                            _categoryName[i],
                                            ExpenseCategoryStyle.colorAt(i),
                                            i,
                                            categoryData,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthlyTrendChart(),
                      SizedBox(height: 24),
                      _buildActionButtons(),
                      SizedBox(height: 24),
                      _buildSummaryCard(),
                      SizedBox(height: 24),
                      SizedBox(
                        height: 40,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isExporting
                              ? null
                              : _showExportBottomSheet,
                          icon: _isExporting
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                )
                              : Icon(Icons.file_download_outlined),
                          label: Text(
                            _isExporting ? 'Đang xuất...' : 'Xuất XLSX',
                          ),
                          style: ElevatedButton.styleFrom(
                            shadowColor: Colors.transparent,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xu hướng theo tháng',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<ExpenseBloc, ExpenseState>(
              builder: (context, state) {
                if (state is ExpenseLoading && state is! ExpenseLoadingData) {
                  return Center(child: CircularProgressIndicator());
                }

                List<double> monthlyData = List.filled(12, 0.0);
                if (state is ExpenseLoaded) {
                  monthlyData = state.monthlyData;
                } else if (state is ExpenseLoadingData) {
                  monthlyData = state.monthlyData;
                }

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 &&
                                value.toInt() < _months.length) {
                              return Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  _months[value.toInt()],
                                  style: TextStyle(fontSize: 10),
                                ),
                              );
                            }
                            return Text('');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: monthlyData.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value);
                        }).toList(),
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: index == _selectedMonth - 1 ? 6 : 4,
                              color: index == _selectedMonth - 1
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.7),
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchCallback:
                          (
                            FlTouchEvent event,
                            LineTouchResponse? touchResponse,
                          ) {
                            if (touchResponse != null &&
                                touchResponse.lineBarSpots != null) {
                              final spot = touchResponse.lineBarSpots!.first;
                              final newMonth = spot.x.toInt() + 1;
                              if (newMonth != _selectedMonth) {
                                setState(() {
                                  _selectedMonth = newMonth;
                                });
                                context.read<ExpenseBloc>().add(
                                  LoadExpenseDataEvent(
                                    month: _selectedMonth,
                                    year: _selectedYear,
                                  ),
                                );
                              }
                            }
                          },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showMonthlyDetails(),
            icon: Icon(Icons.list_alt),
            label: Text('Chi tiết tháng $_selectedMonth'),
            style: ElevatedButton.styleFrom(
              shadowColor: Colors.transparent,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showAddExpenseForm(),
            icon: Icon(Icons.add),
            label: Text('Thêm chi tiêu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showExportBottomSheet() async {
    final range = await ExpenseExportSheet.show(
      context,
      initialMonth: _selectedMonth,
      initialYear: _selectedYear,
    );
    if (range == null || !mounted) return;
    await _exportExpenses(startMonth: range.start, endMonth: range.end);
  }

  Future<void> _exportExpenses({
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final result = await ExpenseExportService.exportToXlsx(
        startMonth: startMonth,
        endMonth: endMonth,
      );

      if (!mounted) return;

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ExpenseExportException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xuất file XLSX lúc này.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Widget _buildSummaryCard() {
    return BlocBuilder<ExpenseBloc, ExpenseState>(
      builder: (context, state) {
        List<double> monthlyData = List.filled(12, 0.0);
        if (state is ExpenseLoaded) {
          monthlyData = state.monthlyData;
        } else if (state is ExpenseLoadingData) {
          monthlyData = state.monthlyData;
        }

        double currentMonthTotal = 0.0;
        if (_selectedMonth > 0 && _selectedMonth <= monthlyData.length) {
          currentMonthTotal = monthlyData[_selectedMonth - 1];
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng chi tiêu tháng $_selectedMonth',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isShow
                        ? NumberHelper.formatCurrency(currentMonthTotal)
                        : NumberHelper.hideMoney(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isShow = !_isShow;
                      });
                    },
                    icon: Icon(
                      _isShow ? Icons.visibility : Icons.visibility_off,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    Map<String, double> categoryData,
  ) {
    double total = categoryData.values.fold(
      0.0,
      (accumulator, value) => accumulator + value,
    );

    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.withValues(alpha: 0.3),
          value: 1,
          title: 'Không có dữ liệu',
          radius: 50,
          titleStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ];
    }

    return categoryData.entries.where((entry) => entry.value > 0).map((entry) {
      int index = _categoryKeys.indexOf(entry.key);
      double percentage = (entry.value / total) * 100;

      return PieChartSectionData(
        color: ExpenseCategoryStyle.colorAt(index),
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegendItem(
    String label,
    Color color,
    int index,
    Map<String, double> categoryData,
  ) {
    double total = categoryData.values.fold(
      0.0,
      (accumulator, value) => accumulator + value,
    );
    double value = categoryData[_categoryKeys[index]] ?? 0.0;
    double percentage = total > 0 ? (value / total) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthlyDetails() {
    MonthlyExpenseDetailsSheet.show(
      context,
      month: _selectedMonth,
      year: _selectedYear,
      showAmounts: _isShow,
    );
  }

  void _showAddExpenseForm() {
    AddExpenseSheet.show(context);
  }
}
