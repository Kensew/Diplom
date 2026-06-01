from pathlib import Path
import re

def replace_regex(path: str, pattern: str, replacement: str):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f'Не найден нужный блок в {path}')
    p.write_text(new_text, encoding='utf-8')
    print(f'OK: {path}')

# 1) customer_executors_page.dart: строгая фильтрация исполнителей
replace_regex(
    'lib/pages/customer_executors_page.dart',
    r'''String _roleFallbackByEmail\(String email\) \{.*?\n  \}\n\n  String _roleFromUser\(Map<String, dynamic> data\) \{.*?\n  \}''',
    '''String? _roleFallbackByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru' ||
        normalized == 'dev1@test.local' ||
        normalized == '1') {
      return 'customer';
    }

    if (normalized == 'support@test.ru' ||
        normalized == 'dev3@test.local' ||
        normalized == '3') {
      return 'support';
    }

    if (normalized == 'executor@test.ru' ||
        normalized == 'dev2@test.local' ||
        normalized == '2') {
      return 'executor';
    }

    return null;
  }

  String? _roleFromUser(Map<String, dynamic> data) {
    final rawRole = data['role']?.toString().trim().toLowerCase();

    if (rawRole == 'customer' ||
        rawRole == 'support' ||
        rawRole == 'executor') {
      return rawRole;
    }

    final email = data['email']?.toString() ?? '';
    return _roleFallbackByEmail(email);
  }'''
)

# 2) application_decision_service.dart: добавить общий roleFromUser
service_path = Path('lib/services/application_decision_service.dart')
text = service_path.read_text(encoding='utf-8')

if 'static String? roleFromUser(Map<String, dynamic> data)' not in text:
    marker = '''  static String normalizedApplicationSource(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();

    if (raw == 'customer_invite' || raw == 'executor_apply') {
      return raw!;
    }

    return 'executor_apply';
  }'''
    insert = marker + '''

  static String? roleFallbackByEmail(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized == 'customer@test.ru' ||
        normalized == 'dev1@test.local' ||
        normalized == '1') {
      return 'customer';
    }

    if (normalized == 'support@test.ru' ||
        normalized == 'dev3@test.local' ||
        normalized == '3') {
      return 'support';
    }

    if (normalized == 'executor@test.ru' ||
        normalized == 'dev2@test.local' ||
        normalized == '2') {
      return 'executor';
    }

    return null;
  }

  static String? roleFromUser(Map<String, dynamic> data) {
    final rawRole = data['role']?.toString().trim().toLowerCase();

    if (rawRole == 'customer' ||
        rawRole == 'support' ||
        rawRole == 'executor') {
      return rawRole;
    }

    final email = data['email']?.toString() ?? '';
    return roleFallbackByEmail(email);
  }'''
    if marker not in text:
        raise RuntimeError('Не найден marker normalizedApplicationSource в application_decision_service.dart')
    text = text.replace(marker, insert, 1)

old = '''    final executorRole = executor['role']?.toString().trim().toLowerCase();
    if (executorRole != 'executor') {
      throw 'Выбранный пользователь не является исполнителем';
    }'''

new = '''    final executorRole = roleFromUser(executor);
    if (executorRole != 'executor') {
      throw 'Выбранный пользователь не является исполнителем';
    }'''

if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise RuntimeError('Не найден блок проверки executorRole в application_decision_service.dart')

service_path.write_text(text, encoding='utf-8')
print('OK: lib/services/application_decision_service.dart')
