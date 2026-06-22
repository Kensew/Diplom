import 'package:pocketbase/pocketbase.dart';

import 'pocketbase_service.dart';

class SupportModerationService {
  SupportModerationService._();

  static final SupportModerationService instance = SupportModerationService._();

  PocketBase get _pb => PocketBaseService.instance.pb;

  void _ensureSupport() {
    if (!PocketBaseService.instance.isSupport) {
      throw StateError('Доступно только сотрудникам поддержки');
    }
  }

  String? _relationId(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String) {
        final trimmed = first.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
    }

    return null;
  }

  Future<List<RecordModel>> _listAll(String collection) async {
    return _pb.collection(collection).getFullList(sort: '-id');
  }

  Future<Map<String, RecordModel>> loadActiveBans() async {
    final bans = await _listAll('user_bans');
    final result = <String, RecordModel>{};

    for (final ban in bans) {
      final userId = _relationId(ban.data['user_id']);
      if (userId != null) {
        result[userId] = ban;
      }
    }

    return result;
  }

  Future<RecordModel?> findBanForUser(String userId) async {
    final result = await _pb.collection('user_bans').getList(
      filter: 'user_id = "$userId"',
      perPage: 1,
    );

    if (result.items.isEmpty) return null;
    return result.items.first;
  }

  Future<String?> banReasonForUser(String userId) async {
    final ban = await findBanForUser(userId);
    if (ban == null) return null;

    final reason = ban.data['reason'] as String? ?? '';
    return reason.trim().isEmpty ? null : reason.trim();
  }

  Future<bool> isUserBanned(String userId) async {
    final ban = await findBanForUser(userId);
    return ban != null;
  }

  Future<void> banUser({
    required String userId,
    required String reason,
  }) async {
    _ensureSupport();

    final currentUserId = PocketBaseService.instance.currentUserId;
    if (currentUserId == userId) {
      throw StateError('Нельзя заблокировать свой аккаунт');
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw StateError('Укажите причину блокировки');
    }

    final bannedAt = DateTime.now().toUtc().toIso8601String();
    final existing = await findBanForUser(userId);

    if (existing != null) {
      await _pb.collection('user_bans').update(
        existing.id,
        body: {
          'reason': trimmedReason,
          'banned_at': bannedAt,
          if (currentUserId != null) 'banned_by': currentUserId,
        },
      );
    } else {
      await _pb.collection('user_bans').create(
        body: {
          'user_id': userId,
          'reason': trimmedReason,
          'banned_at': bannedAt,
          if (currentUserId != null) 'banned_by': currentUserId,
        },
      );
    }

    final saved = await findBanForUser(userId);
    if (saved == null) {
      throw StateError('Блокировка не сохранилась');
    }
  }

  Future<void> unbanUser(String userId) async {
    _ensureSupport();

    final existing = await _pb.collection('user_bans').getList(
      filter: 'user_id = "$userId"',
      perPage: 50,
    );

    for (final ban in existing.items) {
      await _pb.collection('user_bans').delete(ban.id);
    }
  }

  Future<void> deleteFeedback(String feedbackId) async {
    _ensureSupport();
    await _pb.collection('feedbacks').delete(feedbackId);
  }

  Future<void> closeSupportRequest(String requestId) async {
    _ensureSupport();

    await _pb.collection('support_requests').update(
      requestId,
      body: {
        'status': 'closed',
        'closed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> reopenSupportRequest(String requestId) async {
    _ensureSupport();

    await _pb.collection('support_requests').update(
      requestId,
      body: {
        'status': 'open',
        'closed_at': null,
      },
    );
  }

  Future<void> deleteOrderCascade(String orderId) async {
    _ensureSupport();

    final tasks = await _listAll('tasks');
    for (final task in tasks) {
      if (_relationId(task.data['order_id']) != orderId) continue;

      final taskId = task.id;

      final paymentRequests = await _listAll('payment_requests');
      for (final payment in paymentRequests) {
        if (_relationId(payment.data['task_id']) == taskId) {
          await _pb.collection('payment_requests').delete(payment.id);
        }
      }

      final messages = await _listAll('tasks_messages');
      for (final message in messages) {
        if (_relationId(message.data['task_id']) != taskId) continue;

        final attachments = await _listAll('task_message_attachments');
        for (final attachment in attachments) {
          if (_relationId(attachment.data['task_message_id']) == message.id) {
            await _pb
                .collection('task_message_attachments')
                .delete(attachment.id);
          }
        }

        await _pb.collection('tasks_messages').delete(message.id);
      }

      await _pb.collection('tasks').delete(taskId);
    }

    final applications = await _listAll('applications');
    for (final application in applications) {
      if (_relationId(application.data['order_id']) == orderId) {
        await _pb.collection('applications').delete(application.id);
      }
    }

    final orderAttachments = await _listAll('order_attachments');
    for (final attachment in orderAttachments) {
      if (_relationId(attachment.data['order_id']) == orderId) {
        await _pb.collection('order_attachments').delete(attachment.id);
      }
    }

    final feedbacks = await _listAll('feedbacks');
    for (final feedback in feedbacks) {
      if (_relationId(feedback.data['order_id']) == orderId) {
        await _pb.collection('feedbacks').delete(feedback.id);
      }
    }

    await _pb.collection('orders').delete(orderId);
  }

  Future<List<Map<String, dynamic>>> loadUserFeedbacks(String userId) async {
    _ensureSupport();

    final ordersById = <String, Map<String, dynamic>>{};
    for (final order in await _listAll('orders')) {
      ordersById[order.id] = order.data;
    }

    final result = <Map<String, dynamic>>[];

    for (final feedback in await _listAll('feedbacks')) {
      final reviewerId = _relationId(feedback.data['reviewer_id']);
      final reviewedUserId = _relationId(feedback.data['reviewed_user_id']);
      final orderId = _relationId(feedback.data['order_id']);

      final isRelated =
          reviewerId == userId ||
          reviewedUserId == userId ||
          (reviewedUserId == null &&
              orderId != null &&
              _relationId(ordersById[orderId]?['executor_id']) == userId);

      if (!isRelated) continue;

      final order = orderId == null ? null : ordersById[orderId];

      result.add({
        'id': feedback.id,
        'estimate': feedback.data['estimate'],
        'text': feedback.data['text'] as String? ?? '',
        'type': feedback.data['type'] as String? ?? '',
        'order_title':
            order?['task_description'] as String? ?? 'Заказ без описания',
        'created': feedback.created,
      });
    }

    result.sort((a, b) {
      final idA = a['id'] as String? ?? '';
      final idB = b['id'] as String? ?? '';
      return idB.compareTo(idA);
    });

    return result;
  }
}
