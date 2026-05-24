import 'package:pocketbase/pocketbase.dart';

class PocketBaseService {
  PocketBaseService._();

  static final PocketBaseService instance = PocketBaseService._();

  static const String baseUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'http://127.0.0.1:8090',
  );

  final PocketBase pb = PocketBase(baseUrl);

  bool get isLoggedIn => pb.authStore.isValid;

  String? get currentUserId => pb.authStore.record?.id;

  RecordModel? get currentUser => pb.authStore.record;

  String get currentUserRole {
    return pb.authStore.record?.get<String>('role') ?? 'executor';
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
