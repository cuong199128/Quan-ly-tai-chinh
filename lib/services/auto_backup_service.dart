import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'drive_sync_service.dart';
import 'auth_service.dart';

enum SyncStatus { idle, syncing, restoring, success, error, signedOut }

/// Dịch vụ này lắng nghe mọi thay đổi dữ liệu trong app (qua notifyChanged())
/// và tự động tải bản sao lưu lên Drive sau vài giây im lặng (debounce),
/// tránh tải lên liên tục nếu người dùng thao tác nhanh liên tiếp.
///
/// Ngoài ra, checkForRemoteUpdates() phát hiện khi Drive có bản backup
/// mới hơn bản mà thiết bị này biết (ví dụ do một thiết bị khác vừa
/// đồng bộ lên) và tự động tải về.
class AutoBackupService {
  AutoBackupService._internal();
  static final AutoBackupService instance = AutoBackupService._internal();

  Timer? _debounceTimer;
  bool _pausedForRestore = false;

  static const _debounceDuration = Duration(seconds: 3);
  static const _prefsKeyLastRemoteTime = 'auto_backup_last_remote_time';

  final ValueNotifier<SyncStatus> status = ValueNotifier(SyncStatus.idle);
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier(null);
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  DateTime? _lastKnownRemoteTime;

  /// Gọi hàm này ngay sau mỗi lần thêm/sửa/xóa dữ liệu trong Repository.
  void notifyChanged() {
    if (_pausedForRestore) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _performBackup);
  }

  Future<void> _performBackup() async {
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      status.value = SyncStatus.signedOut;
      return;
    }

    status.value = SyncStatus.syncing;
    try {
      final newRemoteTime = await DriveSyncService.uploadBackup();
      if (newRemoteTime != null) await _saveLastKnownRemoteTime(newRemoteTime);
      status.value = SyncStatus.success;
      lastSyncedAt.value = DateTime.now();
      lastError.value = null;
    } catch (e) {
      status.value = SyncStatus.error;
      lastError.value = e.toString();
    }
  }

  /// Sao lưu thủ công (nút "Sao lưu ngay"). Dùng hàm này thay vì gọi
  /// DriveSyncService trực tiếp để mốc thời gian được cập nhật đồng bộ.
  Future<void> backupNow() async {
    _debounceTimer?.cancel();
    status.value = SyncStatus.syncing;
    try {
      final newRemoteTime = await DriveSyncService.uploadBackup();
      if (newRemoteTime != null) await _saveLastKnownRemoteTime(newRemoteTime);
      status.value = SyncStatus.success;
      lastSyncedAt.value = DateTime.now();
      lastError.value = null;
    } catch (e) {
      status.value = SyncStatus.error;
      lastError.value = e.toString();
      rethrow;
    }
  }

  /// Khôi phục thủ công (nút "Khôi phục từ Drive"). Tự lo việc tạm dừng
  /// auto-backup trong lúc khôi phục. Trả về false nếu Drive chưa có backup.
  Future<bool> restoreNow() async {
    pauseForRestore();
    try {
      final remoteTime = await DriveSyncService.downloadBackup();
      if (remoteTime != null) {
        await _saveLastKnownRemoteTime(remoteTime);
        lastSyncedAt.value = DateTime.now();
      }
      return remoteTime != null;
    } finally {
      resumeAfterRestore();
    }
  }

  /// Gọi khi app khởi động (đã đăng nhập) hoặc ngay sau khi đăng nhập.
  /// Nếu Drive có bản backup mới hơn mốc mà thiết bị này biết, tự động
  /// tải về — dùng cho trường hợp một thiết bị khác vừa đồng bộ dữ liệu.
  Future<void> checkForRemoteUpdates() async {
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      status.value = SyncStatus.signedOut;
      return;
    }

    await _loadLastKnownRemoteTime();

    try {
      final remoteTime = await DriveSyncService.getRemoteModifiedTime();
      if (remoteTime == null) return; // Drive chưa có bản sao lưu nào

      final isNewer = _lastKnownRemoteTime == null ||
          remoteTime.isAfter(_lastKnownRemoteTime!);
      if (!isNewer) return;

      status.value = SyncStatus.restoring;
      pauseForRestore();
      final downloadedTime = await DriveSyncService.downloadBackup();
      if (downloadedTime != null) {
        await _saveLastKnownRemoteTime(downloadedTime);
        lastSyncedAt.value = DateTime.now();
        status.value = SyncStatus.success;
        lastError.value = null;
      }
    } catch (e) {
      status.value = SyncStatus.error;
      lastError.value = e.toString();
    } finally {
      resumeAfterRestore();
    }
  }

  /// Gọi trước khi khôi phục dữ liệu từ Drive — tránh việc auto-backup
  /// vô tình ghi đè ngay sau khi vừa tải bản backup về.
  void pauseForRestore() {
    _pausedForRestore = true;
    _debounceTimer?.cancel();
  }

  void resumeAfterRestore() {
    _pausedForRestore = false;
  }

  Future<void> _loadLastKnownRemoteTime() async {
    if (_lastKnownRemoteTime != null) return;
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_prefsKeyLastRemoteTime);
    if (iso != null) _lastKnownRemoteTime = DateTime.tryParse(iso);
  }

  Future<void> _saveLastKnownRemoteTime(DateTime time) async {
    _lastKnownRemoteTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyLastRemoteTime, time.toIso8601String());
  }
}