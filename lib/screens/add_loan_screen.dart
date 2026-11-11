import 'package:flutter/material.dart';
import '../main.dart';
import '../database/database.dart';
import '../repositories/loan_repository.dart';

class AddLoanScreen extends StatefulWidget {
  final Loan? loan; // null = thêm mới, có giá trị = đang sửa
  const AddLoanScreen({super.key, this.loan});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late String _type;
  bool _saving = false;

  bool get _isEditing => widget.loan != null;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    _nameController = TextEditingController(text: loan?.personName ?? '');
    _noteController = TextEditingController(text: loan?.note ?? '');
    _type = loan?.type ?? 'vay';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = LoanRepository(database);
    final name = _nameController.text.trim();
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    if (_isEditing) {
      await repo.updateLoan(
        id: widget.loan!.id,
        personName: name,
        type: _type,
        note: note,
      );
      if (mounted) Navigator.pop(context);
      return;
    }

    // Chống trùng: nếu đã có người cùng tên + cùng loại (vay/cho vay),
    // hỏi lại trước khi tạo thêm một mục mới trùng lặp.
    final duplicate = await repo.findDuplicate(personName: name, type: _type);
    if (duplicate != null) {
      setState(() => _saving = false);
      if (!mounted) return;
      final action = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã có người này'),
          content: Text(
            '"$name" (${_type == 'vay' ? 'Tôi vay' : 'Tôi cho vay'}) đã có trong danh sách.\n'
            'Bạn có thể mở mục đó và thêm khoản vay mới vào, thay vì tạo một người trùng tên.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vẫn tạo mới'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dùng mục có sẵn'),
            ),
          ],
        ),
      );
      if (action == null) return; // người dùng hủy, ở lại màn hình để sửa
      if (action == true) {
        if (mounted) Navigator.pop(context);
        return;
      }
      setState(() => _saving = true);
    }

    await repo.addLoan(
      personName: name,
      type: _type,
      note: note,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Sửa thông tin' : 'Thêm người vay/cho vay')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'vay', label: Text('Tôi vay')),
                ButtonSegment(value: 'cho_vay', label: Text('Tôi cho vay')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên người vay/cho vay',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 8),
              const Text(
                'Sau khi lưu, vào màn hình chi tiết để thêm từng khoản vay cụ thể.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
