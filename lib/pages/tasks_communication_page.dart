// lib/pages/tasks_communication_page.dart

import 'package:flutter/material.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class TasksCommunicationPage extends StatefulWidget {
  final String taskId;

  const TasksCommunicationPage({required this.taskId, Key? key})
    : super(key: key);

  @override
  State<TasksCommunicationPage> createState() => _TasksCommunicationPageState();
}

class _TasksCommunicationPageState extends State<TasksCommunicationPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  String? get _currentUserId => PocketBaseService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _subscribeRealtime();
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

  Future<void> _loadHistory() async {
    try {
      final result = await PocketBaseService.instance.pb
          .collection('tasks_messages')
          .getList(page: 1, perPage: 200);

      final loaded = <Map<String, dynamic>>[];

      for (final record in result.items) {
        final taskId = _relationId(record.data['task_id']);

        if (taskId != widget.taskId) continue;

        loaded.add({
          'id': record.id,
          'user_id': _relationId(record.data['user_id']) ?? '',
          'text': record.data['text'] as String? ?? '',
          'created': record.created,
        });
      }

      loaded.sort((a, b) {
        final da = DateTime.tryParse(a['created'] as String? ?? '');
        final db = DateTime.tryParse(b['created'] as String? ?? '');

        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;

        return da.compareTo(db);
      });

      _messages = loaded;
    } catch (e) {
      _error = 'Ошибка загрузки сообщений: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _subscribeRealtime() async {
    await PocketBaseService.instance.pb.collection('tasks_messages').subscribe(
      '*',
      (event) {
        if (!mounted) return;

        final record = event.record;
        if (record == null) return;

        final taskId = _relationId(record.data['task_id']);
        if (taskId != widget.taskId) return;

        setState(() {
          if (event.action == 'create') {
            final exists = _messages.any((m) => m['id'] == record.id);

            if (!exists) {
              _messages.add({
                'id': record.id,
                'user_id': _relationId(record.data['user_id']) ?? '',
                'text': record.data['text'] as String? ?? '',
                'created': record.created,
              });
            }
          } else if (event.action == 'update') {
            final index = _messages.indexWhere((m) => m['id'] == record.id);

            if (index != -1) {
              _messages[index] = {
                'id': record.id,
                'user_id': _relationId(record.data['user_id']) ?? '',
                'text': record.data['text'] as String? ?? '',
                'created': record.created,
              };
            }
          } else if (event.action == 'delete') {
            _messages.removeWhere((m) => m['id'] == record.id);
          }

          _messages.sort((a, b) {
            final da = DateTime.tryParse(a['created'] as String? ?? '');
            final db = DateTime.tryParse(b['created'] as String? ?? '');

            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;

            return da.compareTo(db);
          });
        });

        _scrollToBottom();
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    final userId = _currentUserId;
    if (userId == null) return;

    _controller.clear();

    try {
      await PocketBaseService.instance.pb
          .collection('tasks_messages')
          .create(
            body: {'task_id': widget.taskId, 'user_id': userId, 'text': text},
          );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка отправки сообщения: $e')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  void dispose() {
    PocketBaseService.instance.pb.collection('tasks_messages').unsubscribe('*');

    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: cs.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Task chat'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(color: cs.error),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.forum_outlined, color: cs.onSurface),
            const SizedBox(width: 8),
            Text(
              'Task chat',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child:
                  _messages.isEmpty
                      ? Center(
                        child: Text(
                          'Сообщений пока нет',
                          style: tt.bodyLarge?.copyWith(
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                        ),
                      )
                      : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final isMe = msg['user_id'] == _currentUserId;
                          final createdAt = _parseDate(msg['created']);

                          return Align(
                            alignment:
                                isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        isMe
                                            ? cs.secondary
                                            : cs.surface.withOpacity(0.9),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: Radius.circular(
                                        isMe ? 18 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 18,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          isMe
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg['text'] as String? ?? '',
                                          style: tt.bodyMedium?.copyWith(
                                            color:
                                                isMe
                                                    ? cs.onSecondary
                                                    : cs.onSurface,
                                          ),
                                        ),
                                        if (createdAt != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                            style: tt.bodySmall?.copyWith(
                                              color: (isMe
                                                      ? cs.onSecondary
                                                      : cs.onSurface)
                                                  .withOpacity(0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: cs.background,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Введите сообщение…',
                        hintStyle: tt.bodyMedium?.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor: cs.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.secondary,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded),
                      color: cs.onSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
