// lib/pages/tasks_communication_page.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

const String _attachmentOnlyText = 'Вложение';

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
  final _timeFmt = DateFormat('HH:mm');

  List<Map<String, dynamic>> _messages = [];
  final Map<String, List<Map<String, dynamic>>> _attachmentsByMessageId = {};
  final Map<String, Map<String, dynamic>> _usersById = {};

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _taskTitle;

  String? _customerId;
  String? _customerName;
  String? _customerPhoto;

  String? _executorId;
  String? _executorName;
  String? _executorPhoto;

  String? get _currentUserId => PocketBaseService.instance.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    PocketBaseService.instance.pb.collection('tasks_messages').unsubscribe('*');
    PocketBaseService.instance.pb
        .collection('task_message_attachments')
        .unsubscribe('*');

    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  String? _firstFileName(dynamic value) {
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

  String? _fileUrl({
    required String collectionName,
    required String recordId,
    required dynamic fileValue,
  }) {
    final fileName = _firstFileName(fileValue);
    if (fileName == null) return null;

    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      return fileName;
    }

    final base = PocketBaseService.baseUrl;
    final encodedName = Uri.encodeComponent(fileName);

    return '$base/api/files/$collectionName/$recordId/$encodedName';
  }

  bool _isImageFile(String value) {
    final lower = value.toLowerCase();

    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  Future<Map<String, dynamic>?> _getRecordData(
    String collection,
    String? id,
  ) async {
    if (id == null || id.isEmpty) return null;

    try {
      final record = await PocketBaseService.instance.pb
          .collection(collection)
          .getOne(id);

      return {
        'id': record.id,
        'created': record.get<String>('created') ?? '',
        ...record.data,
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _messageFromRecord(dynamic record) {
    return {
      'id': record.id,
      'user_id': _relationId(record.data['user_id']) ?? '',
      'text': record.data['text'] as String? ?? '',
      'created': record.get<String>('created') ?? '',
    };
  }

  void _sortMessages() {
    _messages.sort((a, b) {
      final da = DateTime.tryParse(a['created'] as String? ?? '');
      final db = DateTime.tryParse(b['created'] as String? ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return da.compareTo(db);
    });
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadTaskContext();
      await _loadHistory();
      await _loadAttachments();
      await _loadUsersForMessages();
    } catch (e) {
      _error = 'Ошибка загрузки чата: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _loadTaskContext() async {
    final task = await PocketBaseService.instance.pb
        .collection('tasks')
        .getOne(widget.taskId);

    final orderId = _relationId(task.data['order_id']);
    final order = await _getRecordData('orders', orderId);

    _taskTitle = order?['task_description'] as String? ?? 'Чат задачи';

    _customerId = _relationId(order?['customer_id']);
    _executorId = _relationId(task.data['executor_id']);

    final customer = await _getRecordData('users', _customerId);
    final executor = await _getRecordData('users', _executorId);

    _customerName =
        customer?['name'] as String? ??
        customer?['email'] as String? ??
        'Заказчик';

    _executorName =
        executor?['name'] as String? ??
        executor?['email'] as String? ??
        'Исполнитель';

    _customerPhoto =
        _customerId == null
            ? null
            : _fileUrl(
              collectionName: 'users',
              recordId: _customerId!,
              fileValue: customer?['photo'],
            );

    _executorPhoto =
        _executorId == null
            ? null
            : _fileUrl(
              collectionName: 'users',
              recordId: _executorId!,
              fileValue: executor?['photo'],
            );
  }

  Future<void> _loadHistory() async {
    final result = await PocketBaseService.instance.pb
        .collection('tasks_messages')
        .getList(page: 1, perPage: 200);

    final loaded = <Map<String, dynamic>>[];

    for (final record in result.items) {
      final taskId = _relationId(record.data['task_id']);
      if (taskId != widget.taskId) continue;

      loaded.add(_messageFromRecord(record));
    }

    _messages = loaded;
    _sortMessages();
  }

  Future<void> _loadAttachments() async {
    final messageIds = _messages.map((m) => m['id'] as String).toSet();

    _attachmentsByMessageId.clear();

    if (messageIds.isEmpty) return;

    final result = await PocketBaseService.instance.pb
        .collection('task_message_attachments')
        .getList(page: 1, perPage: 200);

    for (final record in result.items) {
      final messageId = _relationId(record.data['task_message_id']);
      if (messageId == null || !messageIds.contains(messageId)) continue;

      final fileName = _firstFileName(record.data['photo']) ?? 'Файл';

      final url = _fileUrl(
        collectionName: 'task_message_attachments',
        recordId: record.id,
        fileValue: record.data['photo'],
      );

      if (url == null) continue;

      final attachment = {
        'id': record.id,
        'message_id': messageId,
        'name': fileName,
        'url': url,
        'is_image': _isImageFile(fileName) || _isImageFile(url),
      };

      _attachmentsByMessageId.putIfAbsent(messageId, () => []);
      _attachmentsByMessageId[messageId]!.add(attachment);
    }
  }

  Future<void> _loadUsersForMessages() async {
    final userIds =
        _messages
            .map((m) => m['user_id'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();

    for (final userId in userIds) {
      if (_usersById.containsKey(userId)) continue;

      final user = await _getRecordData('users', userId);
      if (user == null) continue;

      final avatarUrl = _fileUrl(
        collectionName: 'users',
        recordId: userId,
        fileValue: user['photo'],
      );

      _usersById[userId] = {...user, 'avatar_url': avatarUrl};
    }
  }

  Future<void> _subscribeRealtime() async {
    await PocketBaseService.instance.pb.collection('tasks_messages').subscribe(
      '*',
      (event) async {
        if (!mounted) return;

        final record = event.record;
        if (record == null) return;

        final taskId = _relationId(record.data['task_id']);
        if (taskId != widget.taskId) return;

        final message = _messageFromRecord(record);

        setState(() {
          if (event.action == 'create') {
            final exists = _messages.any((m) => m['id'] == record.id);
            if (!exists) _messages.add(message);
          } else if (event.action == 'update') {
            final index = _messages.indexWhere((m) => m['id'] == record.id);
            if (index != -1) _messages[index] = message;
          } else if (event.action == 'delete') {
            _messages.removeWhere((m) => m['id'] == record.id);
            _attachmentsByMessageId.remove(record.id);
          }

          _sortMessages();
        });

        await _loadUsersForMessages();
        await _loadAttachments();

        if (mounted) {
          setState(() {});
          _scrollToBottom();
        }
      },
    );

    await PocketBaseService.instance.pb
        .collection('task_message_attachments')
        .subscribe('*', (event) async {
          if (!mounted) return;

          await _loadAttachments();

          if (mounted) {
            setState(() {});
            _scrollToBottom();
          }
        });
  }

  Future<void> _sendTextMessage() async {
    await _sendMessage();
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );

    if (result == null || result.files.isEmpty) return;

    await _sendMessage(file: result.files.first);
  }

  Future<void> _sendMessage({PlatformFile? file}) async {
    if (_sending) return;

    final rawText = _controller.text.trim();
    final hasFile = file != null;

    if (rawText.isEmpty && !hasFile) return;

    final userId = _currentUserId;
    if (userId == null) {
      _showSnack('Неавторизован');
      return;
    }

    final messageText =
        rawText.isEmpty && hasFile ? _attachmentOnlyText : rawText;

    setState(() => _sending = true);

    try {
      final bytes = hasFile ? file.bytes : null;

      if (hasFile && bytes == null) {
        throw 'Не удалось прочитать файл';
      }

      _controller.clear();

      final message = await PocketBaseService.instance.pb
          .collection('tasks_messages')
          .create(
            body: {
              'task_id': widget.taskId,
              'user_id': userId,
              'text': messageText,
            },
          );

      if (hasFile) {
        await PocketBaseService.instance.pb
            .collection('task_message_attachments')
            .create(
              body: {'task_message_id': message.id},
              files: [
                http.MultipartFile.fromBytes(
                  'photo',
                  bytes!,
                  filename: file.name,
                ),
              ],
            );
      }

      await _loadHistory();
      await _loadAttachments();
      await _loadUsersForMessages();

      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;

      _showSnack('Ошибка отправки сообщения: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final url = attachment['url'] as String;
    final isImage = attachment['is_image'] == true;

    if (isImage) {
      _openImage(url);
      return;
    }

    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);

    if (!ok && mounted) {
      _showSnack('Не удалось открыть файл');
    }
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.82),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(14),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return const AppSurfaceCard(
                    child: Text('Не удалось открыть изображение'),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _openUserProfile(String? userId) {
    if (userId == null || userId.isEmpty) return;

    context.push('/account/$userId');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tasks');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _taskTitle?.trim();
    final headerSubtitle =
        title == null || title.isEmpty ? 'Переписка по задаче' : title;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? AppErrorState(message: _error!, onRetry: _loadAll)
                  : Column(
                    children: [
                      AppTopBar(
                        title: 'Чат задачи',
                        subtitle: headerSubtitle,
                        onBack: _goBack,
                        onRefresh: _loadAll,
                      ),
                      _ChatParticipantsBar(
                        customerName: _customerName ?? 'Заказчик',
                        customerPhoto: _customerPhoto,
                        executorName: _executorName ?? 'Исполнитель',
                        executorPhoto: _executorPhoto,
                        onOpenCustomer:
                            _customerId == null
                                ? null
                                : () => _openUserProfile(_customerId),
                        onOpenExecutor:
                            _executorId == null
                                ? null
                                : () => _openUserProfile(_executorId),
                      ),
                      Expanded(
                        child:
                            _messages.isEmpty
                                ? const AppEmptyState(
                                  icon: CupertinoIcons.chat_bubble_2,
                                  title: 'Сообщений пока нет',
                                  subtitle:
                                      'Напиши первое сообщение или прикрепи изображение.',
                                )
                                : ListView.builder(
                                  controller: _scrollController,
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    12,
                                  ),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _messages[index];
                                    final messageId = message['id'] as String;
                                    final userId =
                                        message['user_id'] as String? ?? '';
                                    final isMe = userId == _currentUserId;
                                    final user = _usersById[userId];
                                    final attachments =
                                        _attachmentsByMessageId[messageId] ??
                                        const <Map<String, dynamic>>[];

                                    return _MessageBubble(
                                      isMe: isMe,
                                      text: message['text'] as String? ?? '',
                                      createdAt: _parseDate(message['created']),
                                      timeFmt: _timeFmt,
                                      senderName:
                                          isMe
                                              ? 'Вы'
                                              : user?['name'] as String? ??
                                                  user?['email'] as String? ??
                                                  'Собеседник',
                                      avatarUrl: user?['avatar_url'] as String?,
                                      attachments: attachments,
                                      onAttachmentTap: _openAttachment,
                                      onOpenSenderProfile:
                                          userId.isEmpty
                                              ? null
                                              : () => _openUserProfile(userId),
                                    );
                                  },
                                ),
                      ),
                      _ChatInputBar(
                        controller: _controller,
                        sending: _sending,
                        onSend: _sendTextMessage,
                        onAttach: _pickAndSendFile,
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _ChatParticipantsBar extends StatelessWidget {
  final String customerName;
  final String? customerPhoto;
  final String executorName;
  final String? executorPhoto;
  final VoidCallback? onOpenCustomer;
  final VoidCallback? onOpenExecutor;

  const _ChatParticipantsBar({
    required this.customerName,
    required this.customerPhoto,
    required this.executorName,
    required this.executorPhoto,
    required this.onOpenCustomer,
    required this.onOpenExecutor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _ParticipantChip(
              name: customerName,
              role: 'Заказчик',
              avatarUrl: customerPhoto,
              onTap: onOpenCustomer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ParticipantChip(
              name: executorName,
              role: 'Исполнитель',
              avatarUrl: executorPhoto,
              onTap: onOpenExecutor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  final String name;
  final String role;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const _ParticipantChip({
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(9, 8, 8, 8),
      radius: AppRadii.sm,
      child: Row(
        children: [
          AppProfileAvatar(avatarUrl: avatarUrl, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? role : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(role, style: AppTextStyles.caption),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.person_crop_circle,
            size: 18,
            color: onTap == null ? AppColors.textMuted : AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  final DateTime? createdAt;
  final DateFormat timeFmt;
  final String senderName;
  final String? avatarUrl;
  final List<Map<String, dynamic>> attachments;
  final ValueChanged<Map<String, dynamic>> onAttachmentTap;
  final VoidCallback? onOpenSenderProfile;

  const _MessageBubble({
    required this.isMe,
    required this.text,
    required this.createdAt,
    required this.timeFmt,
    required this.senderName,
    required this.avatarUrl,
    required this.attachments,
    required this.onAttachmentTap,
    required this.onOpenSenderProfile,
  });

  @override
  Widget build(BuildContext context) {
    final hasAttachments = attachments.isNotEmpty;
    final hasText =
        text.trim().isNotEmpty &&
        !(hasAttachments && text.trim() == _attachmentOnlyText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: onOpenSenderProfile,
              child: AppProfileAvatar(avatarUrl: avatarUrl, size: 32),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 330),
              child: Container(
                decoration: BoxDecoration(
                  color: isMe ? AppColors.accentSoft : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 5),
                    bottomRight: Radius.circular(isMe ? 5 : 18),
                  ),
                  border: Border.all(
                    color:
                        isMe
                            ? AppColors.accent.withOpacity(0.20)
                            : AppColors.border,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GestureDetector(
                          onTap: onOpenSenderProfile,
                          child: Text(
                            senderName,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    if (hasText)
                      Text(
                        text,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.text,
                        ),
                      ),
                    if (hasAttachments) ...[
                      if (hasText) const SizedBox(height: 8),
                      ...attachments.map(
                        (attachment) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _AttachmentPreview(
                            attachment: attachment,
                            onTap: () => onAttachmentTap(attachment),
                          ),
                        ),
                      ),
                    ],
                    if (!hasText && !hasAttachments)
                      Text(
                        'Пустое сообщение',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      createdAt == null ? '' : timeFmt.format(createdAt!),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) ...[const SizedBox(width: 8), const SizedBox(width: 32)],
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final Map<String, dynamic> attachment;
  final VoidCallback onTap;

  const _AttachmentPreview({required this.attachment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = attachment['name'] as String? ?? 'Файл';
    final url = attachment['url'] as String;
    final isImage = attachment['is_image'] == true;

    if (isImage) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Image.network(
            url,
            width: 230,
            height: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return _FileTile(name: name, extension: 'IMG', onTap: onTap);
            },
          ),
        ),
      );
    }

    return _FileTile(name: name, extension: _extension(name), onTap: onTap);
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'FILE';

    return name.substring(dot + 1).toUpperCase();
  }
}

class _FileTile extends StatelessWidget {
  final String name;
  final String extension;
  final VoidCallback onTap;

  const _FileTile({
    required this.name,
    required this.extension,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      radius: AppRadii.sm,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              extension,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.small.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.arrow_down_doc,
            color: AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _ChatInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppIconSurfaceButton(
              icon: CupertinoIcons.photo,
              onTap: sending ? () {} : onAttach,
              size: 42,
              iconColor: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  enabled: !sending,
                  cursorColor: AppColors.accent,
                  textInputAction: TextInputAction.newline,
                  style: AppTextStyles.body.copyWith(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Сообщение',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 42,
              onPressed: sending ? null : onSend,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: sending ? AppColors.surfaceSoft : AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child:
                    sending
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
