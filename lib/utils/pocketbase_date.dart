class PocketBaseDate {
  const PocketBaseDate._();

  static String? asDateString(dynamic raw) {
    if (raw == null) return null;

    if (raw is String) {
      final value = raw.trim();
      return value.isEmpty ? null : value;
    }

    if (raw is DateTime) {
      return raw.toUtc().toIso8601String();
    }

    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  static DateTime? parse(dynamic raw) {
    final value = asDateString(raw);
    if (value == null) return null;

    var normalized = value;
    if (normalized.contains(' ') && !normalized.contains('T')) {
      normalized = normalized.replaceFirst(' ', 'T');
    }

    return DateTime.tryParse(normalized);
  }

  static int compareDesc(String? a, String? b) {
    final da = parse(a);
    final db = parse(b);

    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;

    final cmp = db.compareTo(da);
    if (cmp != 0) return cmp;

    return 0;
  }

  static int compareAsc(String? a, String? b) {
    final da = parse(a);
    final db = parse(b);

    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;

    final cmp = da.compareTo(db);
    if (cmp != 0) return cmp;

    return 0;
  }

  /// Сортировка по дате создания; при равных/пустых датах — по id записи.
  static int compareDescWithId({
    dynamic createdA,
    dynamic createdB,
    String? idA,
    String? idB,
  }) {
    final dateCmp = compareDesc(
      asDateString(createdA),
      asDateString(createdB),
    );
    if (dateCmp != 0) return dateCmp;

    return (idB ?? '').compareTo(idA ?? '');
  }

  static int compareAscWithId({
    dynamic createdA,
    dynamic createdB,
    String? idA,
    String? idB,
  }) {
    final dateCmp = compareAsc(
      asDateString(createdA),
      asDateString(createdB),
    );
    if (dateCmp != 0) return dateCmp;

    return (idA ?? '').compareTo(idB ?? '');
  }
}
