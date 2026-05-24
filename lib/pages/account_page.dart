import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';

class AccountPage extends StatefulWidget {
  final String? userId;

  const AccountPage({Key? key, this.userId}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _dateFmt = DateFormat('dd.MM.yyyy');

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _profile;
  String? _profileId;
  String? _profileCreated;

  List<Map<String, dynamic>> _feedbacks = [];
  double _avgRating = 0;
  int _totalFb = 0;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final currentUserId = service.currentUserId;

      if (currentUserId == null) {
        throw 'Неавторизован';
      }

      final id = widget.userId ?? currentUserId;
      final user = await pb.collection('users').getOne(id);

      _profileId = user.id;
      _profileCreated = user.created;
      _profile = Map<String, dynamic>.from(user.data);

      final orders = await pb
          .collection('orders')
          .getFullList(filter: 'executor_id = "$id"', sort: '-created');

      _feedbacks = [];
      _avgRating = 0;
      _totalFb = 0;

      for (final order in orders) {
        final records = await pb
            .collection('feedbacks')
            .getFullList(filter: 'order_id = "${order.id}"', sort: '-created');

        for (final fb in records) {
          _feedbacks.add({
            'id': fb.id,
            'estimate': fb.data['estimate'],
            'text': fb.data['text'] as String? ?? '',
            'created': fb.created,
          });
        }
      }

      _feedbacks.sort((a, b) {
        final da = DateTime.tryParse(a['created'] as String? ?? '');
        final db = DateTime.tryParse(b['created'] as String? ?? '');
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      _totalFb = _feedbacks.length;

      if (_totalFb > 0) {
        _avgRating =
            _feedbacks
                .map((f) => (f['estimate'] as num?)?.toDouble() ?? 0)
                .reduce((a, b) => a + b) /
            _totalFb;
      }
    } catch (e) {
      _error = 'Ошибка загрузки профиля: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatAge(String? birthRaw) {
    final birth = DateTime.tryParse(birthRaw ?? '');
    if (birth == null) return '–';

    final now = DateTime.now();
    var age = now.year - birth.year;

    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }

    return '$age y.o.';
  }

  String? _nonEmptyString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: cs.surface,
        drawer: const SizedBox.shrink(),
        appBar: AppBar(
          title: Text(widget.userId == null ? 'Мой профиль' : 'Профиль'),
          backgroundColor: cs.surface,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: cs.surface,
        drawer: const SizedBox.shrink(),
        appBar: AppBar(
          title: Text(widget.userId == null ? 'Мой профиль' : 'Профиль'),
          backgroundColor: cs.surface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
          ),
        ),
      );
    }

    final user = _profile!;
    final currentUserId = PocketBaseService.instance.currentUserId;

    final name = user['name'] as String? ?? '–';
    final birth = user['birth_date'] as String?;
    final age = _formatAge(birth);
    final desc = user['description'] as String? ?? '–';
    final photoUrl = _nonEmptyString(user['photo']);
    final role = user['role'] as String? ?? 'executor';
    final isSelf = widget.userId == null || _profileId == currentUserId;

    return Scaffold(
      backgroundColor: cs.surface,
      drawer:
          isSelf
              ? AppDrawer(role: role, displayName: name, avatarUrl: photoUrl)
              : const SizedBox.shrink(),
      appBar: AppBar(
        title: Text(isSelf ? 'Мой профиль' : 'Профиль'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child:
                        photoUrl == null
                            ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white54,
                            )
                            : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          age,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          desc,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (isSelf)
                SizedBox(
                  width: 140,
                  child: ElevatedButton(
                    onPressed: () async {
                      await context.push('/account/edit');
                      await _loadAccountData();
                    },
                    child: const Text('Edit Profile'),
                  ),
                ),

              const SizedBox(height: 30),

              Text(
                'Feedbacks',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Text(
                    _avgRating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(width: 12),
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < _avgRating.round() ? Icons.star : Icons.star_border,
                      size: 20,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '($_totalFb)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (_feedbacks.isEmpty)
                Text(
                  'Отзывов пока нет',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                ..._feedbacks.map((f) {
                  final est = (f['estimate'] as num?)?.toInt() ?? 0;
                  final text = f['text'] as String? ?? '';
                  final dt = DateTime.tryParse(f['created'] as String? ?? '');
                  final date = dt == null ? '—' : _dateFmt.format(dt.toLocal());

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < est ? Icons.star : Icons.star_border,
                                size: 18,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              date,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
