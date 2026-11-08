import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/income/income_bloc.dart';
import '../../blocs/income/income_event.dart';
import '../../blocs/income/income_state.dart';
import '../../models/income_model.dart';
import '../../shared/helpers/number_helper.dart';
import '../../shared/ui/ui.dart';
import 'widgets/income_tile.dart';

/// All incomes of one month, filterable by source; swipe left to delete.
class IncomeListScreen extends StatefulWidget {
  const IncomeListScreen({super.key, required this.month, required this.year});

  final int month;
  final int year;

  @override
  State<IncomeListScreen> createState() => _IncomeListScreenState();
}

class _IncomeListScreenState extends State<IncomeListScreen> {
  IncomeType? _filter;

  /// Swiped-away rows, hidden until the stream drops them.
  final _removedIds = <String>{};

  @override
  void initState() {
    super.initState();
    context.read<IncomeBloc>().add(
      IncomeMonthChanged(widget.month, widget.year),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IncomeBloc, IncomeState>(
      builder: (context, state) {
        return ModuleScaffold(
          title: 'Thu nhập T${widget.month}/${widget.year}',
          children: [
            PillRow(
              children: [
                PillChip(
                  label: 'Tất cả',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final type in IncomeType.values)
                  PillChip(
                    label: type.label,
                    selected: _filter == type,
                    onTap: () => setState(() => _filter = type),
                  ),
              ],
            ),
            ..._buildBody(context, state),
          ],
        );
      },
    );
  }

  List<Widget> _buildBody(BuildContext context, IncomeState state) {
    if (state is IncomeError) {
      return [
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Không tải được thu nhập',
          message: state.message,
        ),
        Center(
          child: FilledButton(
            onPressed: () => context.read<IncomeBloc>().add(
              IncomeMonthChanged(widget.month, widget.year),
            ),
            child: const Text('Thử lại'),
          ),
        ),
      ];
    }

    if (state is! IncomeLoaded) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final incomes = state.incomes
        .where((income) => !_removedIds.contains(income.id))
        .where((income) => _filter == null || income.type == _filter)
        .toList();

    if (incomes.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Không có khoản thu nào',
        ),
      ];
    }

    final total = incomes.fold<double>(0, (acc, income) => acc + income.amount);
    return [
      AppCard(
        child: StatColumn(
          label: '${incomes.length} khoản thu',
          value: NumberHelper.formatCurrency(total),
          valueColor: Colors.green.shade600,
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (day, items) in groupByDay(
            incomes,
            (IncomeModel income) => income.date,
          )) ...[
            DayHeader(dayLabel(day)),
            for (final income in items)
              Dismissible(
                key: ValueKey(income.id),
                direction: DismissDirection.endToStart,
                background: const SwipeDeleteBackground(),
                confirmDismiss: (_) => confirmDelete(
                  context,
                  'Bạn có chắc muốn xoá khoản thu này?',
                ),
                onDismissed: (_) {
                  setState(() => _removedIds.add(income.id));
                  context.read<IncomeBloc>().add(IncomeDeleted(income.id));
                },
                child: IncomeTile(income: income),
              ),
          ],
        ],
      ),
    ];
  }
}
