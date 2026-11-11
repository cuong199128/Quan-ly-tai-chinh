import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// NavigatorKey dùng chung để có thể gọi pop() từ bên ngoài cây widget
/// (ví dụ từ phím tắt toàn app), không cần một BuildContext cụ thể.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Bọc quanh toàn bộ app để cho phép nhấn phím Esc nhằm quay lại màn hình
/// trước đó — tiện trên Windows/desktop khi không muốn với chuột tới nút back.
/// Không có tác dụng gì nếu đang ở màn hình gốc (không có gì để quay lại).
class EscToBack extends StatelessWidget {
  final Widget child;
  const EscToBack({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          navigatorKey.currentState?.maybePop();
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
