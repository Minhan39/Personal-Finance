import 'package:flutter/material.dart';

import '../../models/saving_plan.dart';
import '../../service/expense_service.dart';
import '../../service/savings_repository.dart';
import '../../shared/helpers/number_helper.dart';
import '../../shared/ui/ui.dart';
import '../home/widgets/activity_tile.dart';

enum _PlanFilter { all, banks, gold }

class SaveScreen extends StatefulWidget {
  const SaveScreen({super.key});

  @override
  State<SaveScreen> createState() => _SaveScreenState();
}

class _SaveScreenState extends State<SaveScreen> {
  /// Emergency-fund target, in months of average spending.
  static const _emergencyTargetMonths = 6;

  SavingsOverview? _overview;
  double? _averageMonthlyExpense;
  String? _error;
  bool _loading = true;
  bool _amountsVisible = false;
  _PlanFilter _filter = _PlanFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        SavingsRepository.load(),
        _loadAverageExpense(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as SavingsOverview;
        _averageMonthlyExpense = results[1] as double?;
      });
    } catch (error) {
      debugPrint('Savings load failed: $error');
      if (!mounted) return;
      setState(() => _error = 'Không tải được dữ liệu tiết kiệm.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Average spending over the last 6 full months, or `null` if unknown.
  Future<double?> _loadAverageExpense() async {
    try {
      final now = DateTime.now();
      final expenses = await ExpenseService.getExpensesByRange(
        startMonth: DateTime(now.year, now.month - 6),
        endMonth: DateTime(now.year, now.month - 1),
      );
      final total = expenses.fold<double>(0, (acc, e) => acc + e.amount);
      return total <= 0 ? null : total / 6;
    } catch (error) {
      debugPrint('Average expense unavailable: $error');
      return null;
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
    final overview = _overview;

    return ModuleScaffold(
      title: 'Tiết kiệm',
      onRefresh: _load,
      actions: [
        IconButton(
          onPressed: () => setState(() => _amountsVisible = !_amountsVisible),
          tooltip: _amountsVisible ? 'Ẩn số tiền' : 'Hiện số tiền',
          icon: Icon(
            _amountsVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ],
      children: [
        if (overview == null && _loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (overview == null)
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: _error ?? 'Không có dữ liệu',
            message: 'Kéo xuống để thử lại.',
          )
        else ...[
          _buildSummary(context, overview),
          if (_averageMonthlyExpense != null)
            _buildEmergencyFund(
              context,
              overview.currentTotal,
              _averageMonthlyExpense!,
            ),
          PillRow(
            children: [
              PillChip(
                label: 'Tất cả',
                selected: _filter == _PlanFilter.all,
                onTap: () => setState(() => _filter = _PlanFilter.all),
              ),
              PillChip(
                label: 'Ngân hàng & ví',
                selected: _filter == _PlanFilter.banks,
                onTap: () => setState(() => _filter = _PlanFilter.banks),
              ),
              PillChip(
                label: 'Vàng',
                selected: _filter == _PlanFilter.gold,
                onTap: () => setState(() => _filter = _PlanFilter.gold),
              ),
            ],
          ),
          ..._buildPlans(context, overview.plans),
        ],
      ],
    );
  }

  Widget _buildSummary(BuildContext context, SavingsOverview overview) {
    return SummaryCard(
      label: 'Tổng quỹ hiện có',
      value: _money(overview.currentTotal),
      child: Row(
        children: [
          Expanded(
            child: StatColumn(
              label: 'Vốn',
              value: _money(overview.totalCapital, compact: true),
            ),
          ),
          Expanded(
            child: StatColumn(
              label: 'Lãi',
              value: _amountsVisible
                  ? '+${NumberHelper.formatCompact(overview.totalProfit)}'
                  : hiddenAmount,
              valueColor: Colors.green.shade600,
            ),
          ),
          Expanded(
            child: StatColumn(
              label: 'Tương lai',
              value: _money(overview.futureTotal, compact: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyFund(
    BuildContext context,
    double currentTotal,
    double averageExpense,
  ) {
    final theme = Theme.of(context);
    final tone = ModuleTone.of(context, AppModule.savings);
    final months = currentTotal / averageExpense;
    final reached = months >= _emergencyTargetMonths;
    final missing = (_emergencyTargetMonths - months) * averageExpense;

    return AppCard(
      child: Row(
        children: [
          IconBadge(
            icon: reached
                ? Icons.verified_user_outlined
                : Icons.shield_outlined,
            tone: tone,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quỹ dự phòng',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${months.toStringAsFixed(1).replaceAll('.', ',')} / '
                      '$_emergencyTargetMonths tháng',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (months / _emergencyTargetMonths).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: tone.accent,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reached
                      ? 'Đã đủ $_emergencyTargetMonths tháng chi tiêu trung bình.'
                      : 'Cần thêm ${_money(missing, compact: true)} để đủ '
                            '$_emergencyTargetMonths tháng.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlans(BuildContext context, List<SavingPlan> all) {
    final plans = all.where((plan) {
      return switch (_filter) {
        _PlanFilter.all => true,
        _PlanFilter.gold => plan.kind == SavingProviderKind.gold,
        _PlanFilter.banks => plan.kind != SavingProviderKind.gold,
      };
    }).toList();

    if (plans.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.savings_outlined,
          title: 'Không có khoản tiết kiệm nào',
        ),
      ];
    }

    return [for (final plan in plans) _PlanCard(plan: plan, money: _money)];
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.money});

  final SavingPlan plan;
  final String Function(double value, {bool compact}) money;

  String? _remainingLabel() {
    final end = plan.endDate;
    if (end == null) return null;
    final now = DateTime.now();
    if (!end.isAfter(now)) return 'Đã đáo hạn';
    final months = (end.year - now.year) * 12 + end.month - now.month;
    if (months <= 0) return 'Còn ${end.difference(now).inDays} ngày';
    return 'Còn $months tháng';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGold = plan.kind == SavingProviderKind.gold;
    final tone = isGold
        ? ModuleTone.of(context, AppModule.report)
        : ModuleTone.of(context, AppModule.savings);
    // Gold has no maturity; the sheet repeats the purchase date as its end.
    final hasTerm =
        !isGold && plan.endLabel.isNotEmpty && plan.endLabel != plan.startLabel;
    final progress = hasTerm ? plan.termProgress : null;
    final profitColor = plan.profit < 0
        ? theme.colorScheme.error
        : Colors.green.shade600;
    final String footer;
    if (hasTerm) {
      final dates = [
        plan.startLabel,
        plan.endLabel,
      ].where((label) => label.isNotEmpty).join(' → ');
      footer = [if (dates.isNotEmpty) dates, ?_remainingLabel()].join(' · ');
    } else {
      footer = plan.startLabel.isEmpty
          ? ''
          : '${isGold ? 'Mua ngày' : 'Từ'} ${plan.startLabel}';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: plan.icon, tone: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.providerName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (plan.percentLabel.isNotEmpty)
                      Text(
                        isGold
                            ? 'Lãi theo giá BTMC · ${plan.percentLabel}'
                            : 'Lãi suất ${plan.percentLabel}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (plan.status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tone.container,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tone.onContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatColumn(label: 'Vốn', value: money(plan.capital)),
              ),
              StatColumn(
                label: 'Lãi',
                value: money(plan.profit),
                valueColor: profitColor,
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: tone.accent,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              footer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
