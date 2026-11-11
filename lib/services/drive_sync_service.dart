import 'package:googleapis/drive/v3.dart' as drive;
import '../database/database.dart';   // getDatabaseFile() nằm ở đây
import '../main.dart';                 // vẫn cần cho biến `database`
import 'auth_service.dart';

class DriveSyncService {
  static const _backupFileName = 'quanlytaichinh_backup.sqlite';

  static Future<drive.DriveApi?> _getDriveApi() async {
    final client = await AuthService.getAuthenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  static Future<drive.File?> _findBackupFile(drive.DriveApi api) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id, name, modifiedTime)',
    );
    if (result.files == null || result.files!.isEmpty) return null;
    return result.files!.first;
  }

  /// Tải file database hiện tại lên Google Drive (ghi đè bản cũ nếu có).
  /// Trả về thời gian sửa đổi mới trên Drive sau khi upload xong.
  static Future<DateTime?> uploadBackup() async {
    final api = await _getDriveApi();
    if (api == null) throw Exception('Chưa đăng nhập Google');

    final dbFile = await getDatabaseFile();
    final media = drive.Media(dbFile.openRead(), await dbFile.length());

    final existing = await _findBackupFile(api);
    drive.File updated;
    if (existing != null) {
      updated = await api.files.update(
        drive.File(),
        existing.id!,
        uploadMedia: media,
        $fields: 'modifiedTime',
      );
    } else {
      final fileMetadata = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];
      updated = await api.files.create(
        fileMetadata,
        uploadMedia: media,
        $fields: 'modifiedTime',
      );
    }
    return updated.modifiedTime;
  }

  /// Tải bản backup từ Drive về, ghi đè database cục bộ.
  /// Trả về null nếu Drive chưa có bản sao lưu nào; ngược lại trả về
  /// thời gian sửa đổi của bản vừa tải, để bên gọi lưu làm mốc so sánh.
  static Future<DateTime?> downloadBackup() async {
    final api = await _getDriveApi();
    if (api == null) throw Exception('Chưa đăng nhập Google');

    final existing = await _findBackupFile(api);
    if (existing == null) return null;

    final media = await api.files.get(
      existing.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final dbFile = await getDatabaseFile();
    await database.close();

    final sink = dbFile.openWrite();
    await media.stream.pipe(sink);
    await sink.close();

    database = AppDatabase();

    return existing.modifiedTime;
  }

  /// Thời gian sửa đổi gần nhất của bản backup trên Drive (null nếu chưa có)
  static Future<DateTime?> getRemoteModifiedTime() async {
    final api = await _getDriveApi();
    if (api == null) return null;
    final existing = await _findBackupFile(api);
    return existing?.modifiedTime;
  }
}