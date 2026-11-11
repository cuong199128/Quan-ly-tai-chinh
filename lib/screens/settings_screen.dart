import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/google_user.dart';
import '../services/drive_sync_service.dart';
import '../services/auto_backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GoogleUserInfo? _user;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkSignIn();
  }

  Future<void> _checkSignIn() async {
    final user = await AuthService.getCurrentUser();
    setState(() => _user = user);
    if (user != null) {
      // Kiểm tra ngầm xem Drive có bản mới hơn không (không chặn UI)
      AutoBackupService.instance.checkForRemoteUpdates();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.signIn();
      setState(() => _user = user);
    } catch (e) {
      _showMessage('Đăng nhập thất bại: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    setState(() => _user = null);
  }

  Future<void> _backupNow() async {
    setState(() => _loading = true);
    try {
      await AutoBackupService.instance.backupNow();
      _showMessage('Sao lưu thành công!');
    } catch (e) {
      _showMessage('Sao lưu thất bại: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _restoreNow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận khôi phục'),
        content: const Text(
            'Toàn bộ dữ liệu hiện tại trên máy này sẽ bị THAY THẾ bằng bản sao lưu trên Drive. Bạn có chắc chắn?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final success = await AutoBackupService.instance.restoreNow();
      _showMessage(success ? 'Khôi phục thành công!' : 'Chưa có bản sao lưu nào trên Drive.');
    } catch (e) {
      _showMessage('Khôi phục thất bại: $e');
    }
    setState(() => _loading = false);
  }

  String _statusText(SyncStatus status, DateTime? lastSynced, String? error) {
    switch (status) {
      case SyncStatus.idle:
        return 'Chưa có thay đổi nào cần đồng bộ.';
      case SyncStatus.syncing:
        return 'Đang tự động đồng bộ...';
      case SyncStatus.restoring:
        return 'Phát hiện dữ liệu mới trên Drive, đang khôi phục...';
      case SyncStatus.success:
        final time = lastSynced != null
            ? DateFormat('HH:mm dd/MM/yyyy').format(lastSynced)
            : '';
        return 'Đã đồng bộ lúc $time';
      case SyncStatus.error:
        return 'Lỗi đồng bộ: ${error ?? ""}';
      case SyncStatus.signedOut:
        return 'Chưa đăng nhập nên chưa thể tự động đồng bộ.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đồng bộ Google Drive',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_user != null) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage:
                            _user!.photoUrl != null ? NetworkImage(_user!.photoUrl!) : null,
                        child: _user!.photoUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(_user!.displayName ?? _user!.email),
                      subtitle: Text(_user!.email),
                    ),
                    const SizedBox(height: 8),
                    // Trạng thái tự động đồng bộ — tự cập nhật realtime
                    ValueListenableBuilder<SyncStatus>(
                      valueListenable: AutoBackupService.instance.status,
                      builder: (context, status, _) {
                        return ValueListenableBuilder<DateTime?>(
                          valueListenable: AutoBackupService.instance.lastSyncedAt,
                          builder: (context, lastSynced, __) {
                            return ValueListenableBuilder<String?>(
                              valueListenable: AutoBackupService.instance.lastError,
                              builder: (context, error, ___) {
                                return Row(
                                  children: [
                                    if (status == SyncStatus.syncing || status == SyncStatus.restoring)
                                      const SizedBox(
                                        width: 14, height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    else
                                      Icon(
                                        status == SyncStatus.error
                                            ? Icons.error_outline
                                            : Icons.cloud_done_outlined,
                                        size: 16,
                                        color: status == SyncStatus.error ? Colors.red : Colors.green,
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _statusText(status, lastSynced, error),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      FilledButton.icon(
                        onPressed: _backupNow,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Sao lưu ngay'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _restoreNow,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Khôi phục từ Drive'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _signOut, child: const Text('Đăng xuất')),
                    ],
                  ] else ...[
                    const Text(
                        'Chưa đăng nhập. Đăng nhập để sao lưu và đồng bộ dữ liệu giữa các thiết bị.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loading ? null : _signIn,
                      icon: const Icon(Icons.login),
                      label: _loading
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Đăng nhập Google'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}