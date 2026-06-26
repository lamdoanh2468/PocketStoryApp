import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../constants/app_categories.dart';
import '../../models/money_entry.dart';
import '../../services/finance_repository.dart';
import '../../services/storage_service.dart';

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, required this.user, this.initialEntry});

  final User user;
  final MoneyEntry? initialEntry;

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
  bool _removeExistingImage = false;
  bool _saving = false;

  bool get _isEditing => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    if (entry == null) return;

    _type = entry.type;
    _category = entry.category;
    _happenedAt = entry.happenedAt;
    _amountController.text = _VndAmountInputFormatter.formatAmount(entry.amount);
    _noteController.text = entry.note;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _categories => _type == EntryType.expense ? AppCategories.expense : AppCategories.income;

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    if (image == null) return;
    setState(() {
      _image = File(image.path);
      _removeExistingImage = false;
    });
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

  double? _parseAmount(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final existing = widget.initialEntry;
      final id = existing?.id ?? const Uuid().v4();
      String? imageUrl = existing?.imageUrl;
      String? imagePath = existing?.imagePath;

      if (_type == EntryType.income || _removeExistingImage) {
        await _storage.deleteEntryImage(existing?.imagePath);
        imageUrl = null;
        imagePath = null;
      }

      if (_type == EntryType.expense && _image != null) {
        await _storage.deleteEntryImage(existing?.imagePath);
        final result = await _storage.uploadEntryImage(
          uid: widget.user.uid,
          entryId: id,
          file: _image!,
        );
        imageUrl = result.url;
        imagePath = result.path;
      }

      final amount = _parseAmount(_amountController.text);
      if (amount == null || amount <= 0) {
        throw StateError('Số tiền không hợp lệ');
      }

      final entry = MoneyEntry(
        id: id,
        uid: widget.user.uid,
        type: _type,
        amount: amount,
        category: _category,
        note: _noteController.text.trim(),
        imageUrl: imageUrl,
        imagePath: imagePath,
        happenedAt: _happenedAt,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await context.read<FinanceRepository>().upsertEntry(widget.user.uid, entry);

      if (!mounted) return;
      if (_isEditing) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật giao dịch.')));
        return;
      }

      _amountController.clear();
      _noteController.clear();
      setState(() {
        _image = null;
        _removeExistingImage = false;
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
    final existingImageUrl = widget.initialEntry?.imageUrl;
    final shouldShowExistingImage = _type == EntryType.expense &&
        !_removeExistingImage &&
        _image == null &&
        existingImageUrl != null &&
        existingImageUrl.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _isEditing ? 'Sửa giao dịch' : 'Ghi nhận giao dịch',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
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
              _category = _categories.contains(_category) ? _category : _categories.first;
              if (_type == EntryType.income) {
                _image = null;
                _removeExistingImage = true;
              }
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
                  _VndAmountInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  hintText: 'VD: 50.000',
                  suffixText: 'VND',
                ),
                validator: (value) {
                  final amount = _parseAmount(value ?? '');
                  if (amount == null || amount <= 0) return 'Nhập số tiền hợp lệ, ví dụ 50.000 VND';
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
                    )
                  else if (shouldShowExistingImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: existingImageUrl,
                        height: 180,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded)),
                      ),
                    ),
                  if (_image != null || shouldShowExistingImage) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _image = null;
                          _removeExistingImage = true;
                        }),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Gỡ ảnh'),
                      ),
                    ),
                  ],
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
          label: Text(_isEditing ? 'Cập nhật giao dịch' : 'Lưu giao dịch'),
        ),
      ],
    );
  }
}

class _VndAmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final normalizedDigits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formatted = _formatDigits(normalizedDigits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatAmount(num amount) {
    return _formatDigits(amount.round().toString());
  }

  static String _formatDigits(String digits) {
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      final positionFromEnd = digits.length - i;
      buffer.write(digits[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }
}
