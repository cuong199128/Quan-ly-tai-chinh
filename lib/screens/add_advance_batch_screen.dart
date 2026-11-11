import 'package:flutter/material.dart';
import '../main.dart';
import '../database/database.dart';
import '../repositories/advance_repository.dart';

class AddAdvanceBatchScreen extends StatefulWidget {
  final AdvanceBatch? batch;
  const AddAdvanceBatchScreen({super.key, this.batch});

  @override
  State<AddAdvanceBatchScreen> createState() => _AddAdvanceBatchScreenState();
}

class _AddAdvanceBatchScreenState extends State<AddAdvanceBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _purposeController;
  late final TextEditingController _noteController;
  bool _saving = false;

  bool get _isEditing => widget.batch != null;

  @override
  void initState() {
    super.initState();
    _purposeController = TextEditingController(text: widget.batch?.purpose ?? '');
    _noteController = TextEditingController(text: widget.batch?.note ?? '');
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = AdvanceRepository(database);
    final purpose = _purposeController.text.trim();
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    if (_isEditing) {
      await repo.updateBatch(
        id: widget.batch!.id,
        purpose: purpose,
        note: note,
      );
      if (mounted) Navigator.pop(context);
      return;
    }

    // Chống trùng: nếu đã có đợt cùng mục đích/tên, hỏi lại trước khi
    // tạo thêm một đợt mới trùng lặp.
    final duplicate = await repo.findDuplicate(purpose: purpose);
    if (duplicate != null) {
      setState(() => _saving = false);
      if (!mounted) return;
      final action = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã có đợt này'),
          content: Text(
            '"$purpose" đã có trong danh sách.\n'
            'Bạn có thể mở đợt đó và thêm khoản chi mới vào, thay vì tạo một đợt trùng tên.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vẫn tạo mới'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dùng đợt có sẵn'),
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

    await repo.addBatch(
      purpose: purpose,
      note: note,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Sửa đợt ứng trước' : 'Thêm đợt ứng trước')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: 'Mục đích / Tên đợt',
                hintText: 'VD: Công tác Đà Nẵng T9',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Vui lòng nhập mục đích' : null,
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