import 'package:flutter/material.dart';

import '../../models/task_item.dart';
import '../../service/task_notification_service.dart';
import '../../service/task_service.dart';
import '../../shared/ui/ui.dart';

/// Create or edit a task: title, note, one-time or repeating schedule,
/// optional end date and reminder.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final TaskItem? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _note;

  late TaskRepeat _repeat;
  late Set<int> _weekdays;
  late DateTime _date;
  late TimeOfDay _time;
  DateTime? _endDate;
  late bool _remind;
  bool _exactAllowed = true;
  bool _saving = false;
  String? _weekdayError;

  bool get _isEditing => widget.task != null && widget.task!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final defaultStart = DateTime.now().add(const Duration(hours: 1));
    final start = task?.startAt ?? defaultStart;
    _title = TextEditingController(text: task?.title ?? '');
    _note = TextEditingController(text: task?.note ?? '');
    _repeat = task?.repeat ?? TaskRepeat.none;
    _weekdays = {...?task?.weekdays};
    if (_weekdays.isEmpty) _weekdays = {start.weekday};
    _date = DateTime(start.year, start.month, start.day);
    _time = task == null
        ? TimeOfDay(hour: start.hour, minute: 0)
        : TimeOfDay.fromDateTime(start);
    _endDate = task?.endDate;
    _remind = task?.remind ?? true;
    _checkExact();
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _checkExact() async {
    final allowed = await TaskNotificationService.canScheduleExact();
    if (mounted) setState(() => _exactAllowed = allowed);
  }

  DateTime get _startAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _date.add(const Duration(days: 30)),
      firstDate: _date,
      lastDate: DateTime(_date.year + 10),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _toggleRemind(bool value) async {
    setState(() => _remind = value);
    if (value) {
      final granted = await TaskNotificationService.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ứng dụng chưa được phép gửi thông báo. Bật lại trong Cài đặt.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _allowExact() async {
    await TaskNotificationService.requestExactPermission();
    await _checkExact();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    final weekdaysOk = _repeat != TaskRepeat.weekly || _weekdays.isNotEmpty;
    setState(() => _weekdayError = weekdaysOk ? null : 'Chọn ít nhất 1 ngày');
    if (!valid || !weekdaysOk) return;

    final base = widget.task ?? TaskItem(title: '', startAt: _startAt);
    final scheduleChanged =
        base.startAt != _startAt ||
        base.repeat != _repeat ||
        base.weekdays.toSet().difference(_weekdays).isNotEmpty ||
        _weekdays.difference(base.weekdays.toSet()).isNotEmpty;

    final task = base.copyWith(
      title: _title.text.trim(),
      note: _note.text.trim(),
      repeat: _repeat,
      weekdays: _repeat == TaskRepeat.weekly
          ? (_weekdays.toList()..sort())
          : [],
      startAt: _startAt,
      endDate: _repeat == TaskRepeat.none ? null : _endDate,
      clearEndDate: _repeat == TaskRepeat.none || _endDate == null,
      remind: _remind,
      // A rescheduled one-time task is pending again.
      clearCompletedAt: !base.isRecurring && scheduleChanged,
    );

    setState(() => _saving = true);
    try {
      await TaskService.save(task);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lưu được công việc. Thử lại nhé.')),
      );
    }
  }

  Future<void> _delete() async {
    final task = widget.task!;
    if (!await confirmDelete(context, 'Xoá công việc "${task.title}"?')) {
      return;
    }
    try {
      await TaskService.delete(task.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xoá được công việc.')),
      );
    }
  }

  String _formatDate(DateTime date) =>
      '${weekdayShortNames[date.weekday - 1]}, '
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recurring = _repeat != TaskRepeat.none;
    final inPast = !recurring && _startAt.isBefore(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa công việc' : 'Công việc mới'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              tooltip: 'Xoá',
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TextFormField(
                controller: _title,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tên công việc',
                  hintText: 'Đóng tiền điện',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Nhập tên công việc'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  hintText: 'Hiện trong thông báo nhắc việc',
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Lịch'),
              const SizedBox(height: 8),
              PillRow(
                children: [
                  for (final repeat in TaskRepeat.values)
                    PillChip(
                      label: repeat.label,
                      selected: _repeat == repeat,
                      onTap: () => setState(() => _repeat = repeat),
                    ),
                ],
              ),
              if (_repeat == TaskRepeat.weekly) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      PillChip(
                        label: weekdayShortNames[day - 1],
                        selected: _weekdays.contains(day),
                        onTap: () => setState(() {
                          if (!_weekdays.remove(day)) _weekdays.add(day);
                          _weekdayError = null;
                        }),
                      ),
                  ],
                ),
                if (_weekdayError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _weekdayError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: Text(recurring ? 'Bắt đầu từ' : 'Ngày'),
                      trailing: Text(_formatDate(_date)),
                      onTap: _pickDate,
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Giờ'),
                      trailing: Text(_time.format(context)),
                      onTap: _pickTime,
                    ),
                    if (recurring) ...[
                      const Divider(indent: 16, endIndent: 16),
                      SwitchListTile(
                        secondary: const Icon(Icons.event_busy_outlined),
                        title: const Text('Có ngày kết thúc'),
                        subtitle: _endDate == null
                            ? const Text('Lặp lại mãi')
                            : Text('Đến ${_formatDate(_endDate!)}'),
                        value: _endDate != null,
                        onChanged: (value) {
                          if (value) {
                            _pickEndDate();
                          } else {
                            setState(() => _endDate = null);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (_repeat == TaskRepeat.monthly)
                _hint(
                  context,
                  'Lặp vào ngày ${_date.day} mỗi tháng; tháng ngắn hơn sẽ '
                  'nhắc vào ngày cuối tháng.',
                ),
              if (inPast)
                _hint(
                  context,
                  'Thời điểm này đã qua nên sẽ không có thông báo.',
                  error: true,
                ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Nhắc việc'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                      ),
                      title: const Text('Gửi thông báo khi đến giờ'),
                      value: _remind,
                      onChanged: _toggleRemind,
                    ),
                    if (_remind && !_exactAllowed) ...[
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.alarm_on_outlined),
                        title: const Text('Nhắc đúng giờ'),
                        subtitle: const Text(
                          'Chưa được cấp quyền nên thông báo có thể đến trễ '
                          'vài phút.',
                        ),
                        trailing: TextButton(
                          onPressed: _allowExact,
                          child: const Text('Cho phép'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Lưu thay đổi' : 'Tạo công việc'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, String text, {bool error = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: error
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
