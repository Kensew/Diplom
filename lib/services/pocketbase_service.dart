import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PocketBaseService {
  PocketBaseService._(this.pb);

  static PocketBaseService? _instance;

  static PocketBaseService get instance {
    final service = _instance;
    if (service == null) {
      throw StateError('PocketBaseService не инициализирован');
    }
    return service;
  }

  static const String baseUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'http://192.168.0.5:8090',
  );

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final authStore = AsyncAuthStore(
      initial: prefs.getString('pb_auth'),
      save: (String data) async {
        await prefs.setString('pb_auth', data);
      },
    );

    _instance = PocketBaseService._(PocketBase(baseUrl, authStore: authStore));
  }

  final PocketBase pb;

  bool get isLoggedIn => pb.authStore.isValid;

  String? get currentUserId => pb.authStore.record?.id;

  RecordModel? get currentUser => pb.authStore.record;

  String get currentUserRole => _resolveRole(pb.authStore.record);

  bool get isSupport => currentUserRole == 'support';

  bool get isBanned {
    final value = pb.authStore.record?.data['is_banned'];
    if (value == true || value == 1) return true;
    if (value is String) return value.trim().toLowerCase() == 'true';
    return false;
  }

  static String resolveRole(RecordModel? record) => _resolveRole(record);

  static String _resolveRole(RecordModel? record) {
    if (record == null) return 'executor';

    final rawRole = record.get<String>('role')?.trim().toLowerCase();
    if (rawRole == 'customer' ||
        rawRole == 'support' ||
        rawRole == 'executor') {
      return rawRole!;
    }

    return _roleByEmail(record.get<String>('email') ?? '');
  }

  static String _roleByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru' || normalized == 'dev1@test.local') {
      return 'customer';
    }

    if (normalized == 'support@test.ru' || normalized == 'dev3@test.local') {
      return 'support';
    }

    if (normalized == 'executor@test.ru' || normalized == 'dev2@test.local') {
      return 'executor';
    }

    return 'executor';
  }

  String get currentUserName {
    return pb.authStore.record?.get<String>('name') ??
        pb.authStore.record?.get<String>('email') ??
        'User';
  }

  String? get currentUserPhoto {
    return pb.authStore.record?.get<String>('photo');
  }

  Future<RecordAuth> login({
    required String email,
    required String password,
  }) async {
    return pb.collection('users').authWithPassword(email, password);
  }

  Future<RecordModel> register({
    required String email,
    required String password,
    required String name,
    required String role,
    DateTime? birthDate,
  }) async {
    return pb
        .collection('users')
        .create(
          body: {
            'email': email,
            'password': password,
            'passwordConfirm': password,
            'name': name,
            'role': role,
            if (birthDate != null) 'birth_date': birthDate.toIso8601String(),
          },
        );
  }

  Future<RecordModel?> refreshUser() async {
    if (!pb.authStore.isValid) return null;

    try {
      final auth = await pb.collection('users').authRefresh();
      return auth.record;
    } catch (_) {
      pb.authStore.clear();
      return null;
    }
  }

  void logout() {
    pb.authStore.clear();
  }
}
