import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

import '../../constants/app_categories.dart';
import '../../models/money_entry.dart';
import '../../services/finance_repository.dart';
import '../../services/storage_service.dart';

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, required this.user});

  final User user;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();
  final _storage = StorageService();

  EntryType _type = EntryType.expense;
  String _category = AppCategories.expense.first;
  DateTime _happenedAt = DateTime.now();
  File? _image;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _categories => _type == EntryType.expense ? AppCategories.expense : AppCategories.income;

  double _parseAmount() {
    final rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(rawAmount) ?? 0;
  }
  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    if (image == null) return;
    setState(() => _image = File(image.path));
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _happenedAt,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_happenedAt),
    );

    setState(() {
      _happenedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _happenedAt.hour,
        time?.minute ?? _happenedAt.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final id = const Uuid().v4();
      String? imageUrl;
      String? imagePath;

      if (_type == EntryType.expense && _image != null) {
        final result = await _storage.uploadEntryImage(
          uid: widget.user.uid,
          entryId: id,
          file: _image!,
        );
        imageUrl = result.url;
        imagePath = result.path;
      }

      final entry = MoneyEntry(
        id: id,
        uid: widget.user.uid,
        type: _type,
        amount: _parseAmount(),
        category: _category,
        note: _noteController.text.trim(),
        imageUrl: imageUrl,
        imagePath: imagePath,
        happenedAt: _happenedAt,
        createdAt: DateTime.now(),
      );

      await context.read<FinanceRepository>().upsertEntry(widget.user.uid, entry);

      if (!mounted) return;
      _amountController.clear();
      _noteController.clear();
      setState(() {
        _image = null;
        _happenedAt = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu giao dịch.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu thất bại: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ghi nhận giao dịch', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SegmentedButton<EntryType>(
          segments: const [
            ButtonSegment(value: EntryType.expense, label: Text('Khoản chi'), icon: Icon(Icons.remove_rounded)),
            ButtonSegment(value: EntryType.income, label: Text('Khoản thu'), icon: Icon(Icons.add_rounded)),
          ],
          selected: {_type},
          onSelectionChanged: (value) {
            final selected = value.first;
            setState(() {
              _type = selected;
              _category = _categories.first;
              if (_type == EntryType.income) _image = null;
            });
          },
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
            TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              VndInputFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Số tiền',
              hintText: '0',
              suffixText: 'VNĐ',
            ),
            validator: (value) {
              final rawAmount = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
              final amount = double.tryParse(rawAmount);

              if (amount == null || amount <= 0) {
                return 'Nhập số tiền hợp lệ';
              }

              return null;
            },
          ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: _categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                onChanged: (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.event_rounded),
            title: const Text('Thời điểm phát sinh'),
            subtitle: Text('${_happenedAt.day}/${_happenedAt.month}/${_happenedAt.year} ${_happenedAt.hour}:${_happenedAt.minute.toString().padLeft(2, '0')}'),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: _pickDate,
          ),
        ),
        if (_type == EntryType.expense) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Hình ảnh chi tiêu', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_image!, height: 180, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('Thư viện'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
          label: const Text('Lưu giao dịch'),
        ),
      ],
    );
  }
}
class VndInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _formatVnd(digits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatVnd(String digits) {
    final buffer = StringBuffer();
    int count = 0;

    for (int i = digits.length - 1; i >= 0; i--) {
      buffer.write(digits[i]);
      count++;

      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }

    return buffer.toString().split('').reversed.join();
  }
}
