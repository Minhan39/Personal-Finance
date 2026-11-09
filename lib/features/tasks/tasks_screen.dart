import 'package:flutter/material.dart';

import '../../models/task_item.dart';
import '../../service/task_service.dart';
import '../../shared/ui/ui.dart';
import 'task_agenda.dart';
import 'widgets/task_tile.dart';

enum _TaskView { todo, recurring, done }

/// To-do list: what's due (overdue, today, tomorrow, later), the recurring
/// tasks, and finished one-time tasks.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final Stream<List<TaskItem>> _tasks = TaskService.watch();
  _TaskView _view = _TaskView.todo;

  /// Swiped-away tasks, hidden until Firestore drops them.
  final _removedIds = <String>{};

  Future<void> _openForm([TaskItem? task]) =>
      Navigator.pushNamed(context, '/tasks/edit', arguments: task);

  Future<void> _delete(TaskItem task) async {
    setState(() => _removedIds.add(task.id));
    try {
      await TaskService.delete(task.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _removedIds.remove(task.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xoá được công việc.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskItem>>(
      stream: _tasks,
      builder: (context, snapshot) {
        final tasks = snapshot.data
            ?.where((task) => !_removedIds.contains(task.id))
            .toList();

        return ModuleScaffold(
          title: 'Công việc',
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openForm,
            icon: const Icon(Icons.add),
            label: const Text('Thêm việc'),
          ),
          children: [
            PillRow(
              children: [
                PillChip(
                  label: 'Cần làm',
                  selected: _view == _TaskView.todo,
                  onTap: () => setState(() => _view = _TaskView.todo),
                ),
                PillChip(
                  label: 'Định kỳ',
                  selected: _view == _TaskView.recurring,
                  onTap: () => setState(() => _view = _TaskView.recurring),
                ),
                PillChip(
                  label: 'Đã xong',
                  selected: _view == _TaskView.done,
                  onTap: () => setState(() => _view = _TaskView.done),
                ),
              ],
            ),
            if (snapshot.hasError)
              const EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Không tải được công việc',
                message: 'Kiểm tra kết nối mạng và đăng nhập lại nếu cần.',
              )
            else if (tasks == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...switch (_view) {
                _TaskView.todo => _buildTodo(context, tasks),
                _TaskView.recurring => _buildRecurring(context, tasks),
                _TaskView.done => _buildDone(context, tasks),
              },
          ],
        );
      },
    );
  }

  Widget _dismissible(TaskItem task, Widget child) {
    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      background: const SwipeDeleteBackground(),
      confirmDismiss: (_) =>
          confirmDelete(context, 'Xoá công việc "${task.title}"?'),
      onDismissed: (_) => _delete(task),
      child: child,
    );
  }

  List<Widget> _buildTodo(BuildContext context, List<TaskItem> tasks) {
    final now = DateTime.now();
    final entries = buildAgenda(tasks, now);
    if (entries.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.task_alt,
          title: 'Không có việc nào cần làm',
          message: 'Bấm "Thêm việc" để tạo công việc mới.',
        ),
      ];
    }

    final todayCount = entries
        .where((e) => e.section == AgendaSection.today && !e.checked)
        .length;
    final overdueCount = entries
        .where((e) => e.section == AgendaSection.overdue)
        .length;

    return [
      _buildSummary(context, todayCount, overdueCount),
      for (final section in AgendaSection.values)
        if (entries.any((e) => e.section == section))
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: section.label),
              for (final entry in entries.where((e) => e.section == section))
                _dismissible(
                  entry.task,
                  TaskTile(
                    task: entry.task,
                    checked: entry.checked,
                    overdue: section == AgendaSection.overdue,
                    subtitle:
                        taskWhenLabel(entry.when, now) +
                        (entry.task.isRecurring
                            ? ' · ${entry.task.repeat.label}'
                            : ''),
                    onToggle: () => toggleAgendaEntry(context, entry),
                    onTap: () => _openForm(entry.task),
                  ),
                ),
            ],
          ),
    ];
  }

  Widget _buildSummary(BuildContext context, int today, int overdue) {
    final tone = ModuleTone.of(context, AppModule.tasks);
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          IconBadge(icon: Icons.task_alt, tone: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              today == 0 && overdue == 0
                  ? 'Đã xong hết việc hôm nay.'
                  : '$today việc hôm nay'
                        '${overdue > 0 ? ' · $overdue việc quá hạn' : ''}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: overdue > 0 ? theme.colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecurring(BuildContext context, List<TaskItem> tasks) {
    final now = DateTime.now();
    final recurring = tasks.where((task) => task.isRecurring).toList();
    if (recurring.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.repeat,
          title: 'Chưa có việc định kỳ',
          message: 'Chọn "Lặp lại" khi tạo việc để nhắc theo chu kỳ.',
        ),
      ];
    }

    return [
      Column(
        children: [
          for (final task in recurring)
            _dismissible(task, () {
              final next = task.nextPending(now);
              final end = task.endDate;
              final parts = [
                task.scheduleLabel(),
                if (next != null) 'Lần tới ${taskWhenLabel(next, now)}',
                if (next == null) 'Đã kết thúc',
                if (next != null && end != null)
                  'đến ${end.day}/${end.month}/${end.year}',
              ];
              final doneToday = task.isDoneOn(now);
              return TaskTile(
                task: task,
                checked: doneToday,
                subtitle: parts.join(' · '),
                // Un-ticks today when done; otherwise ticks the next
                // occurrence (doing it early counts for that day).
                onToggle: () => toggleAgendaEntry(
                  context,
                  AgendaEntry(
                    task: task,
                    when: doneToday ? now : (next ?? now),
                    checked: doneToday,
                    section: AgendaSection.today,
                  ),
                ),
                onTap: () => _openForm(task),
              );
            }()),
        ],
      ),
    ];
  }

  List<Widget> _buildDone(BuildContext context, List<TaskItem> tasks) {
    final now = DateTime.now();
    final done =
        tasks
            .where(
              (task) =>
                  (!task.isRecurring && task.completedAt != null) ||
                  (task.isRecurring && task.isFinished(now)),
            )
            .toList()
          ..sort(
            (a, b) => (b.completedAt ?? b.startAt).compareTo(
              a.completedAt ?? a.startAt,
            ),
          );
    if (done.isEmpty) {
      return const [
        EmptyState(icon: Icons.done_all, title: 'Chưa có việc nào xong'),
      ];
    }

    return [
      Column(
        children: [
          for (final task in done)
            _dismissible(
              task,
              TaskTile(
                task: task,
                checked: true,
                subtitle: task.completedAt != null
                    ? 'Xong lúc ${taskWhenLabel(task.completedAt!, now)}'
                    : 'Đã kết thúc · ${task.repeat.label}',
                // A finished recurring task is reopened by editing its
                // schedule; a one-time task is simply un-ticked.
                onToggle: task.isRecurring
                    ? () => _openForm(task)
                    : () => toggleAgendaEntry(
                        context,
                        AgendaEntry(
                          task: task,
                          when: task.startAt,
                          checked: true,
                          section: AgendaSection.today,
                        ),
                      ),
                onTap: () => _openForm(task),
              ),
            ),
        ],
      ),
    ];
  }
}
