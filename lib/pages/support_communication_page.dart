// lib/pages/support_communication_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class SupportCommunicationPage extends StatefulWidget {
  final String requestId;
  final String? agentName;
  final String? agentPhoto;

  const SupportCommunicationPage({
    required this.requestId,
    this.agentName,
    this.agentPhoto,
    Key? key,
  }) : super(key: key);

  @override
  State<SupportCommunicationPage> createState() =>
      _SupportCommunicationPageState();
}

class _SupportCommunicationPageState extends State<SupportCommunicationPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _dateFmt = DateFormat('HH:mm, dd.MM.yyyy');

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
          .collection('support_requests_messages')
          .getList(page: 1, perPage: 200);

      final loaded = <Map<String, dynamic>>[];

      for (final record in result.items) {
        final requestId = _relationId(record.data['request_id']);

        if (requestId != widget.requestId) continue;

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
    await PocketBaseService.instance.pb
        .collection('support_requests_messages')
        .subscribe('*', (event) {
          if (!mounted) return;

          final record = event.record;
          if (record == null) return;

          final requestId = _relationId(record.data['request_id']);
          if (requestId != widget.requestId) return;

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
        });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();

    if (text.isEmpty) return;

    final userId = _currentUserId;
    if (userId == null) return;

    _textController.clear();

    try {
      await PocketBaseService.instance.pb
          .collection('support_requests_messages')
          .create(
            body: {
              'request_id': widget.requestId,
              'user_id': userId,
              'text': text,
            },
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
    PocketBaseService.instance.pb
        .collection('support_requests_messages')
        .unsubscribe('*');

    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meId = _currentUserId;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: BackButton(color: cs.onSurface),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  widget.agentPhoto != null && widget.agentPhoto!.isNotEmpty
                      ? NetworkImage(widget.agentPhoto!)
                      : null,
              backgroundColor: cs.secondary,
              child:
                  widget.agentPhoto == null || widget.agentPhoto!.isEmpty
                      ? Icon(Icons.support_agent, color: cs.onSecondary)
                      : null,
            ),
            const SizedBox(width: 12),
            Text(
              widget.agentName ?? 'Поддержка',
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge?.copyWith(color: cs.error),
                  ),
                ),
              ),
            )
          else
            Expanded(
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
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final message = _messages[i];
                          final isMe = message['user_id'] == meId;
                          final createdAt = _parseDate(message['created']);

                          final bubbleColor =
                              isMe
                                  ? cs.secondary
                                  : cs.surfaceVariant.withOpacity(0.9);
                          final textColor =
                              isMe ? cs.onSecondary : cs.onSurface;

                          return Align(
                            alignment:
                                isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 360,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: bubbleColor,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      bottomLeft: Radius.circular(
                                        isMe ? 20 : 6,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 6 : 20,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          isMe
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message['text'] as String? ?? '',
                                          style: tt.bodyLarge?.copyWith(
                                            color: textColor,
                                            fontSize: 18,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (createdAt != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            _dateFmt.format(createdAt),
                                            style: tt.bodyMedium?.copyWith(
                                              color: textColor.withOpacity(0.8),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Введите сообщение…',
                        hintStyle: tt.bodyMedium?.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor: cs.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface,
                        fontSize: 16,
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.secondary,
                    child: IconButton(
                      icon: Icon(Icons.send, color: cs.onSecondary),
                      onPressed: _sendMessage,
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
