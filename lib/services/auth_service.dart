import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'google_user.dart';
import 'windows_auth_service.dart';

/// Lớp này che giấu sự khác biệt giữa Android (dùng google_sign_in)
/// và Windows (dùng cơ chế đăng nhập qua trình duyệt) — các màn hình
/// khác chỉ cần gọi AuthService, không cần biết đang chạy trên nền tảng nào.
class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.appdata'],
  );

  static GoogleUserInfo? _windowsUserCache;

  static bool get _isWindows => Platform.isWindows;

  static Future<GoogleUserInfo?> getCurrentUser() async {
    if (_isWindows) {
      if (_windowsUserCache != null) return _windowsUserCache;
      final client = await WindowsAuthService.getAuthenticatedClient();
      if (client == null) return null;
      _windowsUserCache = await _fetchUserInfo(client);
      return _windowsUserCache;
    } else {
      final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      if (account == null) return null;
      return GoogleUserInfo(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
    }
  }

  static Future<GoogleUserInfo?> signIn() async {
    if (_isWindows) {
      final client = await WindowsAuthService.signIn();
      _windowsUserCache = await _fetchUserInfo(client);
      return _windowsUserCache;
    } else {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      return GoogleUserInfo(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
    }
  }

  static Future<void> signOut() async {
    if (_isWindows) {
      await WindowsAuthService.signOut();
      _windowsUserCache = null;
    } else {
      await _googleSignIn.signOut();
    }
  }

  /// Dùng cho DriveSyncService — không cần sửa gì ở đó.
  static Future<http.Client?> getAuthenticatedClient() async {
    if (_isWindows) {
      return await WindowsAuthService.getAuthenticatedClient();
    } else {
      if (_googleSignIn.currentUser == null) {
        await _googleSignIn.signInSilently();
      }
      if (_googleSignIn.currentUser == null) return null;
      return await _googleSignIn.authenticatedClient();
    }
  }

  static Future<GoogleUserInfo?> _fetchUserInfo(http.Client client) async {
    final response =
        await client.get(Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'));
    if (response.statusCode != 200) {
      throw Exception('Không lấy được thông tin tài khoản (mã lỗi ${response.statusCode})');
    }
    final data = jsonDecode(response.body);
    return GoogleUserInfo(
      email: data['email'] ?? '',
      displayName: data['name'],
      photoUrl: data['picture'],
    );
  }
}