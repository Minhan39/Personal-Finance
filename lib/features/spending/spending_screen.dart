import 'package:cloud_firestore/cloud_firestore.dart';
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

  List<ExpenseCategory> get _categories => ExpenseCategory.values;
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
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        for (
                                          int i = 0;
                                          i < _categoryName.length;
                                          i++
                                        )
                                          _buildLegendItem(
                                            _categoryName[i],
                                            _getColorForCategory(i),
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

  void _showExportBottomSheet() {
    final now = DateTime.now();
    final years = List<int>.generate(
      now.year - 2019,
      (index) => 2020 + index,
    ).reversed.toList();
    int startMonth = _selectedMonth;
    int startYear = _selectedYear;
    int endMonth = _selectedMonth;
    int endYear = _selectedYear;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final totalMonths = _getSelectedMonthCount(
            startYear: startYear,
            startMonth: startMonth,
            endYear: endYear,
            endMonth: endMonth,
          );

          return SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Xuất dữ liệu chi tiêu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Chọn khoảng thánh cần xuất. Tối đa 12 tháng.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildMonthYearPicker(
                      title: 'Từ tháng',
                      selectedMonth: startMonth,
                      selectedYear: startYear,
                      years: years,
                      onMonthChanged: (value) {
                        setModalState(() {
                          startMonth = value!;
                          errorText = null;
                        });
                      },
                      onYearChanged: (value) {
                        setModalState(() {
                          startYear = value!;
                          errorText = null;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    _buildMonthYearPicker(
                      title: 'Đến tháng',
                      selectedMonth: endMonth,
                      selectedYear: endYear,
                      years: years,
                      onMonthChanged: (value) {
                        setModalState(() {
                          endMonth = value!;
                          errorText = null;
                        });
                      },
                      onYearChanged: (value) {
                        setModalState(() {
                          endYear = value!;
                          errorText = null;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Số tháng đã chọn: $totalMonths',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            totalMonths > ExpenseExportService.maxExportMonths
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (errorText != null) ...[
                      SizedBox(height: 8),
                      Text(errorText!, style: TextStyle(color: Colors.red)),
                    ],
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(modalContext),
                            style: ElevatedButton.styleFrom(
                              shadowColor: Colors.transparent,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('Đóng'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final startDate = DateTime(startYear, startMonth);
                              final endDate = DateTime(endYear, endMonth);

                              if (startDate.isAfter(endDate)) {
                                setModalState(() {
                                  errorText =
                                      'Tháng bắt đầu phải nhỏ hơn hoặc bằng tháng kết thúc.';
                                });
                                return;
                              }

                              if (totalMonths >
                                  ExpenseExportService.maxExportMonths) {
                                setModalState(() {
                                  errorText =
                                      'Bạn chỉ có thể xuất tối đa 12 tháng mỗi lần.';
                                });
                                return;
                              }

                              Navigator.pop(modalContext);
                              await _exportExpenses(
                                startMonth: startDate,
                                endMonth: endDate,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('Xuất file'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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

  Widget _buildMonthYearPicker({
    required String title,
    required int selectedMonth,
    required int selectedYear,
    required List<int> years,
    required ValueChanged<int?> onMonthChanged,
    required ValueChanged<int?> onYearChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: InputDecoration(
                    labelText: 'Tháng',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text('Tháng $month'),
                    );
                  }),
                  onChanged: onMonthChanged,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: InputDecoration(
                    labelText: 'Năm',
                    border: OutlineInputBorder(),
                  ),
                  items: years.map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: onYearChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getSelectedMonthCount({
    required int startYear,
    required int startMonth,
    required int endYear,
    required int endMonth,
  }) {
    return (endYear - startYear) * 12 + endMonth - startMonth + 1;
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

  Color _getColorForCategory(int index) {
    final colors = [
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
      Color(0xFF84CC16),
      Color(0xFF6B7280),
    ];
    return colors[index % colors.length];
  }

  List<PieChartSectionData> _buildPieChartSections(
    Map<String, double> categoryData,
  ) {
    final colors = [
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
      Color(0xFF84CC16),
      Color(0xFF6B7280),
    ];

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
        color: colors[index % colors.length],
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
    context.read<ExpenseBloc>().add(
      LoadExpensesByMonthEvent(month: _selectedMonth, year: _selectedYear),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Chi tiết tháng $_selectedMonth/$_selectedYear',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BlocConsumer<ExpenseBloc, ExpenseState>(
                  listener: (context, state) {
                    if (state is ExpenseDeleteSuccess) {
                      Navigator.pop(modalContext);
                    }
                  },
                  builder: (context, state) {
                    final isLoading =
                        state is ExpenseLoading || state is ExpenseLoadingData;
                    List<Map<String, dynamic>> expenses = [];
                    if (state is ExpenseLoaded) {
                      expenses = state.expenses;
                    }

                    if (isLoading) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }

                    if (expenses.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Chưa có chi tiêu nào trong tháng này',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        final id = expense['id'] as String;
                        final category = expense['category'] as String;
                        final amount = (expense['amount'] as num).toDouble();
                        final description = expense['description'] as String;
                        final date = (expense['date'] as Timestamp).toDate();

                        final categoryIndex = _categoryKeys.indexOf(category);
                        final displayName = categoryIndex >= 0
                            ? _categoryName[categoryIndex]
                            : category;

                        return Dismissible(
                          key: Key(id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Xác nhận xóa'),
                                      content: Text(
                                        'Bạn có chắc chắn muốn xóa chi tiêu này?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: Text('Huỷ'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: Text('Xoá'),
                                        ),
                                      ],
                                    );
                                  },
                                ) ??
                                false;
                          },
                          onDismissed: (direction) {
                            context.read<ExpenseBloc>().add(
                              DeleteExpenseEvent(id: id, date: date),
                            );
                          },
                          child: Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getColorForCategory(
                                  categoryIndex >= 0 ? categoryIndex : _otherCategoryIndex,
                                ),
                                child: Icon(
                                  _getIconForCategory(categoryIndex),
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(displayName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (description.isNotEmpty) Text(description),
                                  Text(
                                    '${date.day}/${date.month}/${date.year}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                _isShow
                                    ? NumberHelper.formatCurrency(amount)
                                    : NumberHelper.hideMoney(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForCategory(int index) {
    final icons = [
      Icons.restaurant, // Food
      Icons.inventory_outlined, // Bills
      Icons.shopping_cart, // Shopping
      Icons.pedal_bike, // Transport
      Icons.family_restroom, // Family
      Icons.celebration_outlined, // Social
      Icons.person_outline, // Personal
      Icons.handshake_outlined, // Lend
      Icons.more_horiz, // Other
    ];
    return index >= 0 && index < icons.length ? icons[index] : Icons.more_horiz;
  }
  List<String> _getQuickSuggestions(String categoryKey) {
    return ExpenseCategory.fromKey(categoryKey).quickSuggestions;
  }
  String _displayCategoryName(String categoryKey) {
    return ExpenseCategory.fromKey(categoryKey).displayName;
  }
  int get _otherCategoryIndex => _categoryKeys.indexOf('Other');
  void _applyQuickSuggestion(
    TextEditingController controller,
    String suggestion,
  ) {
    controller
      ..text = suggestion
      ..selection = TextSelection.collapsed(offset: suggestion.length);
  }

  void _showAddExpenseForm() {
    final formKey = GlobalKey<FormState>();
    String selectedCategory = _categoryKeys.first;
    double amount = 0;
    String description = '';
    DateTime selectedDate = DateTime.now();
    final descriptionController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(modalContext).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                modalContext,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Th\u00eam chi ti\u00eau m\u1edbi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Danh mục',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category.key,
                                child: Text(category.displayName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() {
                                selectedCategory = value;
                              });
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Số tiền',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixText: 'VND',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Vui lòng nhập số tiền';
                              }
                              final parsedAmount = double.tryParse(value);
                              if (parsedAmount == null || parsedAmount <= 0) {
                                return 'Vui lòng nhập số tiền hợp lệ';
                              }
                              return null;
                            },
                            onSaved: (value) =>
                                amount = double.tryParse(value!) ?? 0,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Mô tả',
                              hintText:
                                  'Nhập chữ hoặc chọn gợi ý nhanh',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 3,
                            onSaved: (value) => description = value ?? '',
                          ),
                          if (_getQuickSuggestions(selectedCategory).isNotEmpty) ...[
                            SizedBox(height: 12),
                            Text(
                              'Gợi ý nhanh cho ${_displayCategoryName(selectedCategory)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  modalContext,
                                ).colorScheme.onSurface.withValues(alpha: 0.75),
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _getQuickSuggestions(selectedCategory)
                                  .map(
                                    (suggestion) => ActionChip(
                                      label: Text(suggestion),
                                      onPressed: () => _applyQuickSuggestion(
                                        descriptionController,
                                        suggestion,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          SizedBox(height: 16),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Ngày',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text:
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            ),
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null && picked != selectedDate) {
                                setModalState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                          ),
                          SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    descriptionController.dispose();
                                    Navigator.pop(modalContext);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    shadowColor: Colors.transparent,
                                    backgroundColor: Theme.of(
                                      modalContext,
                                    ).colorScheme.primary.withValues(alpha: 0.2),
                                    foregroundColor: Theme.of(
                                      modalContext,
                                    ).colorScheme.primary,
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Text('Hủy'),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: BlocConsumer<ExpenseBloc, ExpenseState>(
                                  listener: (context, state) {
                                    if (state is ExpenseAddSuccess) {
                                      descriptionController.dispose();
                                      Navigator.pop(modalContext);
                                    }
                                  },
                                  builder: (context, state) {
                                    final isLoading =
                                        state is ExpenseLoading ||
                                        state is ExpenseLoadingData;
                                    return ElevatedButton(
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              if (formKey.currentState!
                                                  .validate()) {
                                                formKey.currentState!.save();
                                                context.read<ExpenseBloc>().add(
                                                  AddExpenseEvent(
                                                    category: selectedCategory,
                                                    amount: amount,
                                                    description: description,
                                                    date: selectedDate,
                                                  ),
                                                );
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          modalContext,
                                        ).colorScheme.primary,
                                        foregroundColor: Theme.of(
                                          modalContext,
                                        ).colorScheme.onPrimary,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: isLoading
                                          ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                      Theme.of(
                                                        modalContext,
                                                      ).colorScheme.onPrimary,
                                                    ),
                                              ),
                                            )
                                          : Text('Lưu'),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
