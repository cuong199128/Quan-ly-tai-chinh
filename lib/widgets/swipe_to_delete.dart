import 'dart:io';
import 'package:flutter/material.dart';

/// Bọc một mục trong danh sách để hỗ trợ xóa nhanh:
/// - Trên Android/iOS: vuốt sang trái để xóa.
/// - Trên Windows/Linux/macOS: hiện icon thùng rác bên phải để xóa.
/// Cả hai cách đều yêu cầu xác nhận trước khi xóa thật sự.
class SwipeToDelete extends StatelessWidget {
  final Widget child;

  /// Key duy nhất cho mục này (thường là id trong database).
  final Object itemKey;

  /// Hàm thực hiện xóa (gọi repository, v.v.). Không cần tự hỏi xác nhận
  /// bên trong hàm này — SwipeToDelete đã lo việc đó.
  final Future<void> Function() onDelete;

  /// Nội dung hộp thoại xác nhận, ví dụ: 'Xóa khoản vay của "An"?'
  final String confirmMessage;
  final String confirmTitle;

  const SwipeToDelete({
    super.key,
    required this.child,
    required this.itemKey,
    required this.onDelete,
    required this.confirmMessage,
    this.confirmTitle = 'Xác nhận xóa',
  });

  static bool get _useSwipeGesture => Platform.isAndroid || Platform.isIOS;

  Future<bool> _confirm(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_useSwipeGesture) {
      return Dismissible(
        key: ValueKey(itemKey),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirm(context),
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: child,
      );
    }

    // Desktop (Windows/Linux/macOS): không có thao tác vuốt tiện lợi,
    // nên hiện icon thùng rác cạnh mục để xóa.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: child),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Xóa',
          onPressed: () async {
            final confirmed = await _confirm(context);
            if (confirmed) await onDelete();
          },
        ),
      ],
    );
  }
}
