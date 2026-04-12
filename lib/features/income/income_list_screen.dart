import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/income/income_bloc.dart';
import '../../blocs/income/income_event.dart';
import '../../blocs/income/income_state.dart';
import '../../models/income_model.dart';
import '../../shared/helpers/income_formatter.dart';

class IncomeListScreen extends StatefulWidget {
  const IncomeListScreen({
    super.key,
    required this.month,
    required this.year,
  });

  final int month;
  final int year;

  @override
  State<IncomeListScreen> createState() => _IncomeListScreenState();
}

class _IncomeListScreenState extends State<IncomeListScreen> {
  IncomeType? _filter;

  @override
  void initState() {
    super.initState();
    context.read<IncomeBloc>().add(
      IncomeMonthChanged(widget.month, widget.year),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Thu nhập T${widget.month}/${widget.year}')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  selected: _filter == null,
                  label: const Text('Tất cả'),
                  onSelected: (_) => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                ...IncomeType.values.map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _filter == type,
                      label: Text(type.label),
                      onSelected: (_) => setState(() => _filter = type),
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<IncomeBloc, IncomeState>(
              builder: (context, state) {
                if (state is IncomeLoading || state is IncomeInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is IncomeError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 40, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              context.read<IncomeBloc>().add(
                                IncomeMonthChanged(widget.month, widget.year),
                              );
                            },
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (state is! IncomeLoaded) {
                  return const SizedBox.shrink();
                }

                final filteredIncomes = state.incomes.where((income) {
                  return _filter == null || income.type == _filter;
                }).toList();

                if (filteredIncomes.isEmpty) {
                  return Center(
                    child: Text(
                      'Chưa có giao dịch thu nhập',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }

                final grouped = <String, List<IncomeModel>>{};
                for (final income in filteredIncomes) {
                  final key =
                      '${income.date.day}/${income.date.month}/${income.date.year}';
                  grouped.putIfAbsent(key, () => []).add(income);
                }

                final keys = grouped.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    final items = grouped[key]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...items.map(_buildIncomeItem),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeItem(IncomeModel income) {
    return Dismissible(
      key: Key(income.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Xác nhận xoá'),
                content: const Text('Bạn có chắc muốn xoá khoản thu này không?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Huỷ'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Xoá'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => context.read<IncomeBloc>().add(IncomeDeleted(income.id)),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () => Navigator.pushNamed(
            context,
            '/income/edit/${income.id}',
            arguments: income,
          ),
          leading: CircleAvatar(
            backgroundColor: income.type.color,
            child: Icon(income.type.icon, color: Colors.white),
          ),
          title: Text(income.type.label),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (income.note.isNotEmpty) Text(income.note),
              Text(
                '${income.date.hour.toString().padLeft(2, '0')}:${income.date.minute.toString().padLeft(2, '0')}',
              ),
            ],
          ),
          trailing: Text(
            formatVnd(income.amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
