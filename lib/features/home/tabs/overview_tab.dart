import 'package:flutter/material.dart';

import '../../../models/saving_plan.dart';
import '../../../service/auth_service.dart';
import '../../../service/month_activity_service.dart';
import '../../../service/savings_repository.dart';
import '../../../shared/helpers/number_helper.dart';
import '../../../shared/ui/ui.dart';
import '../../tasks/widgets/today_tasks_card.dart';
import '../widgets/activity_tile.dart';

/// Home tab: total assets, this month's cash flow, shortcuts and the latest
/// transactions.
class OverviewTab extends StatefulWidget {
  const OverviewTab({
    super.key,
    required this.refreshTick,
    required this.onOpenReport,
    required this.onOpenTransactions,
  });

  /// Bumped by the shell whenever the data may have changed.
  final int refreshTick;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenTransactions;

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  SavingsOverview? _savings;
  MonthActivity? _activity;
  bool _loading = true;
  bool _amountsVisible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  Future<T?> _safe<T>(Future<T> future) async {
    try {
      return await future;
    } catch (error) {
      debugPrint('Overview load failed: $error');
      return null;
    }
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final results = await Future.wait([
      _safe(SavingsRepository.load(withGoldPrice: false)),
      _safe(MonthActivityService().load(now.month, now.year)),
    ]);
    if (!mounted) return;
    setState(() {
      _savings = results[0] as SavingsOverview? ?? _savings;
      _activity = results[1] as MonthActivity? ?? _activity;
      _loading = false;
    });
  }

  Future<void> _openModule(String route) async {
    await Navigator.pushNamed(context, route);
    _load();
  }

  String _money(double value, {bool compact = false}) {
    if (!_amountsVisible) return hiddenAmount;
    return compact
        ? NumberHelper.formatCompact(value)
        : NumberHelper.formatCurrency(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const _Greeting(),
              const SizedBox(height: 20),
              _buildHeroCard(context),
              const SizedBox(height: 20),
              _buildShortcuts(context),
              const SizedBox(height: 20),
              _buildCashFlowCard(context),
              const TodayTasksCard(),
              const SizedBox(height: 20),
              SectionHeader(
                title: 'Giao dịch gần đây',
                actionLabel: 'Xem tất cả',
                onAction: widget.onOpenTransactions,
              ),
              _buildRecent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final activity = _activity;
    final tileColor = scheme.onPrimary.withValues(alpha: 0.12);
    final mutedText = scheme.onPrimary.withValues(alpha: 0.8);

    Widget tile(IconData icon, String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: mutedText),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: mutedText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final month = DateTime.now().month;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng tài sản tiết kiệm',
                  style: textTheme.bodyMedium?.copyWith(color: mutedText),
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _amountsVisible = !_amountsVisible),
                tooltip: _amountsVisible ? 'Ẩn số tiền' : 'Hiện số tiền',
                style: IconButton.styleFrom(foregroundColor: scheme.onPrimary),
                icon: Icon(
                  _amountsVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ],
          ),
          Text(
            _loading && _savings == null
                ? '…'
                : _money(_savings?.currentTotal ?? 0),
            style: textTheme.headlineMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              tile(
                Icons.south_west,
                'Thu tháng $month',
                activity == null
                    ? '…'
                    : '+${_money(activity.totalIncome, compact: true)}',
              ),
              const SizedBox(width: 10),
              tile(
                Icons.north_east,
                'Chi tháng $month',
                activity == null
                    ? '…'
                    : '−${_money(activity.totalExpense, compact: true)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcuts(BuildContext context) {
    Widget shortcut(
      IconData icon,
      AppModule module,
      String label,
      VoidCallback onTap,
    ) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                IconBadge(
                  icon: icon,
                  tone: ModuleTone.of(context, module),
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        shortcut(
          Icons.savings_outlined,
          AppModule.savings,
          'Tiết kiệm',
          () => _openModule('/save'),
        ),
        shortcut(
          Icons.receipt_long_outlined,
          AppModule.spending,
          'Chi tiêu',
          () => _openModule('/spending'),
        ),
        shortcut(
          Icons.account_balance_wallet_outlined,
          AppModule.income,
          'Thu nhập',
          () => _openModule('/income'),
        ),
        shortcut(
          Icons.task_alt,
          AppModule.tasks,
          'Công việc',
          () => _openModule('/tasks'),
        ),
        shortcut(
          Icons.pie_chart_outline,
          AppModule.report,
          'Báo cáo',
          widget.onOpenReport,
        ),
      ],
    );
  }

  Widget _buildCashFlowCard(BuildContext context) {
    final theme = Theme.of(context);
    final activity = _activity;
    if (activity == null) return const SizedBox.shrink();

    final income = activity.totalIncome;
    final expense = activity.totalExpense;
    // Without income there is nothing to measure spending against, so the
    // bar stays empty instead of showing a full red "overspent" bar.
    final ratio = income <= 0 ? 0.0 : expense / income;
    final overspent = expense > income;
    final barColor = overspent
        ? theme.colorScheme.error
        : ratio > 0.8
        ? Colors.orange.shade700
        : ModuleTone.of(context, AppModule.savings).accent;

    final String caption;
    if (income <= 0 && expense <= 0) {
      caption = 'Chưa có giao dịch nào trong tháng này.';
    } else if (income <= 0) {
      caption = 'Chưa ghi nhận thu nhập tháng này.';
    } else if (overspent) {
      caption = 'Đã chi vượt thu nhập ${_money(expense - income)}.';
    } else {
      caption = 'Còn lại ${_money(activity.net)} sau chi tiêu.';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dòng tiền tháng này',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (income > 0)
                Text(
                  'Đã chi ${(ratio * 100).toStringAsFixed(0)}% thu nhập',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              color: barColor,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecent(BuildContext context) {
    final activity = _activity;
    if (activity == null) {
      return _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : const EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Không tải được giao dịch',
              message: 'Kéo xuống để thử lại.',
            );
    }

    final items = activity.items.take(5).toList();
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có giao dịch tháng này',
        message: 'Bấm nút + bên dưới để thêm khoản đầu tiên.',
      );
    }

    return Column(
      children: [
        for (final item in items)
          ActivityTile(
            item: item,
            amountsVisible: _amountsVisible,
            onChanged: _load,
          ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  String get _timeOfDay {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Chào buổi sáng';
    if (hour < 14) return 'Chào buổi trưa';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AppAuthService.supabaseSession?.user;
    final name =
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString() ??
        user?.email ??
        '';

    return Row(
      children: [
        UserAvatar(radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _timeOfDay,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The signed-in user's photo, or their initials when there is none.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.radius = 20});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = AppAuthService.supabaseSession?.user;
    final avatarUrl = user?.userMetadata?['avatar_url']?.toString();
    final name =
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString() ??
        user?.email ??
        '';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      backgroundImage: hasPhoto ? NetworkImage(avatarUrl) : null,
      child: hasPhoto
          ? null
          : Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.7,
              ),
            ),
    );
  }
}
