import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required String timezone,
  }) async {
    final data = await _api.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'timezone': timezone,
    });
    return _persist(data);
  }

  Future<AppUser> login(String email, String password) async {
    final data = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    return _persist(data);
  }

  Future<AppUser> googleSignIn(String idToken) async {
    final data = await _api.post('/auth/google', body: {'idToken': idToken});
    return _persist(data);
  }

  Future<void> verifyEmail(String email, String code) =>
      _api.post('/auth/verify-email', body: {'email': email, 'code': code});

  Future<void> resendCode(String email) =>
      _api.post('/auth/resend-code', body: {'email': email});

  Future<void> forgotPassword(String email) =>
      _api.post('/auth/forgot-password', body: {'email': email});

  Future<void> resetPassword(String token, String newPassword) => _api
      .post('/auth/reset-password', body: {'token': token, 'newPassword': newPassword});

  Future<void> changePassword(String current, String next) => _api.post(
        '/auth/change-password',
        body: {'currentPassword': current, 'newPassword': next},
      );

  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    try {
      await _api.post('/auth/logout', body: {'refreshToken': refresh});
    } catch (_) {
      // Signing out locally must succeed even if the network call does not.
    }
    await _storage.clear();
  }

  Future<AppUser?> currentUser() async {
    if (await _storage.accessToken == null) return null;
    try {
      final data = await _api.get('/users/me');
      return AppUser.fromJson((data as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<AppUser> _persist(dynamic data) async {
    final map = (data as Map).cast<String, dynamic>();
    await _storage.save(
      access: map['accessToken'] as String,
      refresh: map['refreshToken'] as String,
    );
    return AppUser.fromJson((map['user'] as Map).cast<String, dynamic>());
  }
}
