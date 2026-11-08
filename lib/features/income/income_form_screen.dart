import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/income/income_bloc.dart';
import '../../blocs/income/income_event.dart';
import '../../models/income_model.dart';
import '../../shared/helpers/income_formatter.dart';

class IncomeFormScreen extends StatefulWidget {
  const IncomeFormScreen({super.key, this.income});

  final IncomeModel? income;

  @override
  State<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends State<IncomeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late IncomeType _selectedType;
  late DateTime _selectedDate;

  bool get _isEditing => widget.income != null;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.income?.type ?? IncomeType.salary;
    _selectedDate = widget.income?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: widget.income == null ? '' : _formatInput(widget.income!.amount),
    );
    _noteController = TextEditingController(text: widget.income?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa thu nhập' : 'Thêm thu nhập'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nguồn thu',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SegmentedButton<IncomeType>(
                  selected: {_selectedType},
                  showSelectedIcon: false,
                  segments: IncomeType.values
                      .map(
                        (type) => ButtonSegment<IncomeType>(
                          value: type,
                          icon: Icon(type.icon, size: 18),
                          label: Text(type.label),
                        ),
                      )
                      .toList(),
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedType = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThousandsSeparatorFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Số tiền',
                    suffixText: '₫',
                  ),
                  validator: (value) {
                    if (parseVnd(value ?? '') <= 0) {
                      return 'Vui lòng nhập số tiền hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text:
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Ngày ghi nhận',
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'Ghi chú'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saveIncome,
                    child: const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  void _saveIncome() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final income = IncomeModel(
      id: widget.income?.id ?? '',
      type: _selectedType,
      amount: parseVnd(_amountController.text),
      note: _noteController.text.trim(),
      date: _selectedDate,
      month: _selectedDate.month,
      year: _selectedDate.year,
      createdAt: widget.income?.createdAt,
      updatedAt: DateTime.now(),
      userId: '',
    );

    if (_isEditing) {
      context.read<IncomeBloc>().add(IncomeUpdated(income));
    } else {
      context.read<IncomeBloc>().add(IncomeAdded(income));
    }

    Navigator.pop(context);
  }

  String _formatInput(double amount) {
    return formatVnd(amount).replaceAll('₫', '').trim();
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    final formatted = digitsOnly.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
