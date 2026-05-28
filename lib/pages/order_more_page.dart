// lib/pages/order_more_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_freelance_platform/services/order_complexity_service.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class OrderMorePage extends StatefulWidget {
  final String orderId;

  const OrderMorePage({required this.orderId, Key? key}) : super(key: key);

  @override
  State<OrderMorePage> createState() => _OrderMorePageState();
}

class _OrderMorePageState extends State<OrderMorePage> {
  final _dateFmt = DateFormat('dd.MM.yyyy');
  final _complexityReasonCtrl = TextEditingController();

  bool _loading = true;
  bool _applying = false;
  String? _error;

  String? _description;
  DateTime? _deadline;
  String? _framework;
  String? _language;
  num? _price;

  int? _complexityAuto;
  String? _complexityFactorsRaw;
  int? _complexityProposed;

  String? _customerId;
  String? _customerName;
  String? _customerPhoto;

  String? _executorId;
  String? _executorName;
  String? _executorPhoto;

  String? _taskId;
  bool _hasApplied = false;
  String? _applicationStatus;

  String? _role;
  String? _name;
  String? _photo;

  final List<_OrderAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _complexityReasonCtrl.dispose();
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

    final encodedName = Uri.encodeComponent(fileName);

    return '${PocketBaseService.baseUrl}/api/files/$collectionName/$recordId/$encodedName';
  }

  bool _isImageFile(String value) {
    final lower = value.toLowerCase();

    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String _roleFallbackByEmail(String email) {
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

    return 'executor';
  }

  String _roleFromUser(Map<String, dynamic> data) {
    final email = data['email']?.toString() ?? '';
    final rawRole = data['role']?.toString().trim().toLowerCase();

    if (rawRole == 'customer' ||
        rawRole == 'support' ||
        rawRole == 'executor') {
      return rawRole!;
    }

    return _roleFallbackByEmail(email);
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

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadDrawerData();
      await _loadOrder();
      await _loadAttachments();
      await _loadTask();
      await _loadApplicationState();
    } catch (e) {
      _error = 'Ошибка загрузки заказа: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadDrawerData() async {
    final service = PocketBaseService.instance;
    final userId = service.currentUserId;

    if (userId == null) return;

    final user = await service.pb.collection('users').getOne(userId);

    _role = _roleFromUser(user.data);
    _name =
        user.data['name'] as String? ?? user.data['email'] as String? ?? 'User';

    _photo = _fileUrl(
      collectionName: 'users',
      recordId: user.id,
      fileValue: user.data['photo'],
    );
  }

  Future<void> _loadOrder() async {
    final pb = PocketBaseService.instance.pb;
    final order = await pb.collection('orders').getOne(widget.orderId);

    _description = order.data['task_description'] as String?;
    _price = order.data['price'] as num?;

    _complexityAuto = (order.data['complexity_auto'] as num?)?.toInt();
    _complexityFactorsRaw = order.data['complexity_factors']?.toString();

    final baseComplexity = (_complexityAuto ?? 3).clamp(1, 5).toInt();
    _complexityProposed ??= baseComplexity;

    final deadlineRaw = order.data['deadline'] as String?;
    _deadline = DateTime.tryParse(deadlineRaw ?? '')?.toLocal();

    final frameworkId = _relationId(order.data['framework_id']);
    final languageId = _relationId(order.data['language_id']);
    final customerId = _relationId(order.data['customer_id']);
    final executorId = _relationId(order.data['executor_id']);

    final framework = await _getRecordData('frameworks', frameworkId);
    final language = await _getRecordData('languages', languageId);
    final customer = await _getRecordData('users', customerId);
    final executor = await _getRecordData('users', executorId);

    _framework = framework?['name'] as String? ?? '—';
    _language = language?['name'] as String? ?? '—';

    _customerId = customerId;
    _customerName =
        customer?['name'] as String? ??
        customer?['email'] as String? ??
        'Заказчик';

    _customerPhoto =
        customerId == null
            ? null
            : _fileUrl(
              collectionName: 'users',
              recordId: customerId,
              fileValue: customer?['photo'],
            );

    _executorId = executorId;
    _executorName =
        executor?['name'] as String? ?? executor?['email'] as String?;

    _executorPhoto =
        executorId == null
            ? null
            : _fileUrl(
              collectionName: 'users',
              recordId: executorId,
              fileValue: executor?['photo'],
            );
  }

  Future<void> _loadAttachments() async {
    final pb = PocketBaseService.instance.pb;

    _attachments.clear();

    final attachmentsResult = await pb
        .collection('order_attachments')
        .getList(page: 1, perPage: 200);

    final attachments =
        attachmentsResult.items.where((record) {
          final orderId = _relationId(record.data['order_id']);
          return orderId == widget.orderId;
        }).toList();

    attachments.sort((a, b) {
      final da = DateTime.tryParse(a.get<String>('created') ?? '');
      final db = DateTime.tryParse(b.get<String>('created') ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return da.compareTo(db);
    });

    for (final record in attachments) {
      final fileValue = record.data['url'] ?? record.data['file'];
      final fileName = _firstFileName(fileValue) ?? 'Файл';

      final url = _fileUrl(
        collectionName: 'order_attachments',
        recordId: record.id,
        fileValue: fileValue,
      );

      if (url == null) continue;

      _attachments.add(
        _OrderAttachment(
          id: record.id,
          name: fileName,
          url: url,
          isImage: _isImageFile(fileName) || _isImageFile(url),
        ),
      );
    }
  }

  Future<void> _loadTask() async {
    final pb = PocketBaseService.instance.pb;

    _taskId = null;

    final tasksResult = await pb
        .collection('tasks')
        .getList(page: 1, perPage: 200);

    final tasks =
        tasksResult.items.where((record) {
          final orderId = _relationId(record.data['order_id']);
          return orderId == widget.orderId;
        }).toList();

    tasks.sort((a, b) {
      final da = DateTime.tryParse(a.get<String>('created') ?? '');
      final db = DateTime.tryParse(b.get<String>('created') ?? '');

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return db.compareTo(da);
    });

    _taskId = tasks.isEmpty ? null : tasks.first.id;
  }

  Future<void> _loadApplicationState() async {
    final userId = PocketBaseService.instance.currentUserId;

    _hasApplied = false;
    _applicationStatus = null;

    if (userId == null) return;

    final result = await PocketBaseService.instance.pb
        .collection('applications')
        .getList(page: 1, perPage: 200);

    for (final app in result.items) {
      final orderId = _relationId(app.data['order_id']);
      final executorId = _relationId(app.data['executor_id']);
      final status = app.data['status']?.toString().trim().toLowerCase();

      if (orderId == widget.orderId && executorId == userId) {
        _applicationStatus = status ?? 'pending';

        if (status != 'rejected') {
          _hasApplied = true;

          final proposed = (app.data['complexity_proposed'] as num?)?.toInt();
          if (proposed != null) {
            _complexityProposed = proposed.clamp(1, 5).toInt();
          }

          _complexityReasonCtrl.text =
              app.data['complexity_reason'] as String? ?? '';
        }

        return;
      }
    }
  }

  Future<void> _apply() async {
    if (_applying) return;

    setState(() => _applying = true);

    try {
      final service = PocketBaseService.instance;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      if (_role != 'executor') {
        throw 'Подать заявку может только исполнитель';
      }

      if (_customerId == userId) {
        throw 'Нельзя подать заявку на собственный заказ';
      }

      if (_executorId != null) {
        throw 'Заказ уже назначен исполнителю';
      }

      if (_hasApplied) {
        throw 'Заявка уже отправлена';
      }

      final autoComplexity = (_complexityAuto ?? 3).clamp(1, 5).toInt();
      final proposedComplexity = OrderComplexityService.clampProposedComplexity(
        autoComplexity: autoComplexity,
        proposedComplexity: _complexityProposed ?? autoComplexity,
      );

      if (proposedComplexity != autoComplexity &&
          _complexityReasonCtrl.text.trim().isEmpty) {
        throw 'Укажите причину изменения сложности';
      }

      await service.pb
          .collection('applications')
          .create(
            body: {
              'order_id': widget.orderId,
              'executor_id': userId,
              'status': 'pending',
              'complexity_proposed': proposedComplexity,
              'complexity_reason': _complexityReasonCtrl.text.trim(),
            },
          );

      await _loadApplicationState();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заявка отправлена')));

      setState(() => _applying = false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при подаче заявки: $e')));

      setState(() => _applying = false);
    }
  }

  Future<void> _openAttachment(_OrderAttachment attachment) async {
    if (attachment.isImage) {
      _openImage(attachment.url);
      return;
    }

    final uri = Uri.parse(attachment.url);
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);

    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось открыть файл')));
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

  String _formatMoney(num? value) {
    if (value == null) return '—';

    if (value % 1 == 0) {
      return '${value.toStringAsFixed(0)} ₽';
    }

    return '${value.toStringAsFixed(2)} ₽';
  }

  String _deadlineText() {
    if (_deadline == null) return '—';
    return _dateFmt.format(_deadline!);
  }

  bool get _canApply {
    final currentUserId = PocketBaseService.instance.currentUserId;

    return _role == 'executor' &&
        currentUserId != null &&
        currentUserId != _customerId &&
        _executorId == null &&
        !_hasApplied &&
        _taskId == null;
  }

  bool get _canOpenChat {
    final currentUserId = PocketBaseService.instance.currentUserId;

    if (_taskId == null || currentUserId == null) return false;

    return currentUserId == _customerId ||
        currentUserId == _executorId ||
        _role == 'support';
  }

  bool get _canOpenTask {
    final currentUserId = PocketBaseService.instance.currentUserId;

    return _taskId != null &&
        currentUserId != null &&
        (currentUserId == _customerId ||
            currentUserId == _executorId ||
            _role == 'support');
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    if (_role == 'customer') {
      context.go('/orders');
      return;
    }

    if (_role == 'support') {
      context.go('/support/orders');
      return;
    }

    context.go('/executor');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer:
          (_role != null && _name != null)
              ? AppDrawer(role: _role!, displayName: _name!, avatarUrl: _photo)
              : null,
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
                        title: 'Детали заказа',
                        subtitle: 'Описание, сложность, вложения и действия',
                        onBack: _goBack,
                        onRefresh: _loadAll,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadAll,
                          child: ListView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                            children: [
                              _OrderMainCard(
                                description: _description ?? '—',
                                framework: _framework ?? '—',
                                language: _language ?? '—',
                                deadline: _deadlineText(),
                                price: _formatMoney(_price),
                                assigned: _executorId != null,
                                hasApplied: _hasApplied,
                                applicationStatus: _applicationStatus,
                              ),
                              const SizedBox(height: 12),
                              _OrderComplexityCard(
                                autoComplexity: _complexityAuto,
                                factorsRaw: _complexityFactorsRaw,
                                proposedComplexity: _complexityProposed,
                                reasonCtrl: _complexityReasonCtrl,
                                canEdit: _canApply,
                                onChanged: (value) {
                                  setState(() {
                                    _complexityProposed = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _CustomerCard(
                                customerId: _customerId,
                                customerName: _customerName ?? 'Заказчик',
                                customerPhoto: _customerPhoto,
                                onOpenProfile:
                                    _customerId == null
                                        ? null
                                        : () => context.push(
                                          '/account/$_customerId',
                                        ),
                              ),
                              if (_executorId != null) ...[
                                const SizedBox(height: 12),
                                _ExecutorCard(
                                  executorName: _executorName ?? 'Исполнитель',
                                  executorPhoto: _executorPhoto,
                                  executorId: _executorId,
                                  onOpenProfile:
                                      _executorId == null
                                          ? null
                                          : () => context.push(
                                            '/account/$_executorId',
                                          ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _AttachmentsCard(
                                attachments: _attachments,
                                onOpenAttachment: _openAttachment,
                              ),
                              const SizedBox(height: 12),
                              _OrderActionsCard(
                                applying: _applying,
                                canApply: _canApply,
                                hasApplied: _hasApplied,
                                assigned: _executorId != null,
                                canOpenChat: _canOpenChat,
                                canOpenTask: _canOpenTask,
                                onApply: _apply,
                                onOpenChat:
                                    _taskId == null
                                        ? null
                                        : () {
                                          context.push(
                                            '/tasks/communication/$_taskId',
                                          );
                                        },
                                onOpenTask:
                                    _taskId == null
                                        ? null
                                        : () {
                                          context.push(
                                            '/tasks/details/$_taskId',
                                          );
                                        },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _OrderAttachment {
  final String id;
  final String name;
  final String url;
  final bool isImage;

  const _OrderAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.isImage,
  });
}

class _OrderMainCard extends StatelessWidget {
  final String description;
  final String framework;
  final String language;
  final String deadline;
  final String price;
  final bool assigned;
  final bool hasApplied;
  final String? applicationStatus;

  const _OrderMainCard({
    required this.description,
    required this.framework,
    required this.language,
    required this.deadline,
    required this.price,
    required this.assigned,
    required this.hasApplied,
    required this.applicationStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        assigned
            ? AppStatusPill.success('Исполнитель назначен')
            : hasApplied
            ? AppStatusPill.pending(
              applicationStatus == 'approved'
                  ? 'Заявка принята'
                  : applicationStatus == 'rejected'
                  ? 'Заявка отклонена'
                  : 'Заявка отправлена',
            )
            : const AppStatusPill(
              text: 'Ожидает исполнителя',
              color: AppColors.textMuted,
              icon: CupertinoIcons.clock,
            );

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Заказ'),
          const SizedBox(height: 12),
          Text(
            description.trim().isEmpty ? 'Без описания' : description,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppTag(icon: Icons.view_in_ar_outlined, label: framework),
              AppTag(icon: Icons.code_rounded, label: language),
              status,
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppMetaItem(
                  icon: Icons.currency_ruble_rounded,
                  label: 'Бюджет',
                  value: price,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppMetaItem(
                  icon: CupertinoIcons.calendar_today,
                  label: 'Дедлайн',
                  value: deadline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderComplexityCard extends StatelessWidget {
  final int? autoComplexity;
  final String? factorsRaw;
  final int? proposedComplexity;
  final TextEditingController reasonCtrl;
  final bool canEdit;
  final ValueChanged<int> onChanged;

  const _OrderComplexityCard({
    required this.autoComplexity,
    required this.factorsRaw,
    required this.proposedComplexity,
    required this.reasonCtrl,
    required this.canEdit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final base = (autoComplexity ?? 3).clamp(1, 5).toInt();
    final selected = (proposedComplexity ?? base).clamp(1, 5).toInt();
    final allowedValues = OrderComplexityService.allowedProposedValues(base);
    final factors = OrderComplexityService.parseFactors(factorsRaw);
    final changed = selected != base;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Сложность'),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '$base/5',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      OrderComplexityService.complexityLabel(base),
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canEdit
                          ? 'Можно предложить сложность на один уровень ниже или выше системной оценки.'
                          : 'Системная оценка сложности заказа.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (factors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  factors
                      .map(
                        (factor) => AppTag(
                          icon: CupertinoIcons.checkmark_circle,
                          label: '${factor.label} +${factor.points}',
                        ),
                      )
                      .toList(),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            Text(
              'Ваша оценка',
              style: AppTextStyles.small.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  allowedValues.map((value) {
                    final isSelected = value == selected;

                    if (isSelected) {
                      return ElevatedButton(
                        onPressed: () => onChanged(value),
                        child: Text('$value / 5'),
                      );
                    }

                    return OutlinedButton(
                      onPressed: () => onChanged(value),
                      child: Text('$value / 5'),
                    );
                  }).toList(),
            ),
            if (changed) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                minLines: 2,
                style: AppTextStyles.body.copyWith(color: AppColors.text),
                decoration: const InputDecoration(
                  labelText: 'Причина изменения сложности',
                  hintText:
                      'Например: потребуется интеграция API и работа с файлами',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ] else if (proposedComplexity != null) ...[
            const SizedBox(height: 12),
            AppTag(
              icon: CupertinoIcons.person_crop_circle,
              label: 'Оценка исполнителя: $selected / 5',
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final String? customerId;
  final String customerName;
  final String? customerPhoto;
  final VoidCallback? onOpenProfile;

  const _CustomerCard({
    required this.customerId,
    required this.customerName,
    required this.customerPhoto,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onOpenProfile,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AppProfileAvatar(avatarUrl: customerPhoto),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: AppTextStyles.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text('Заказчик', style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 18,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _ExecutorCard extends StatelessWidget {
  final String executorName;
  final String? executorPhoto;
  final String? executorId;
  final VoidCallback? onOpenProfile;

  const _ExecutorCard({
    required this.executorName,
    required this.executorPhoto,
    required this.executorId,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: onOpenProfile,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AppProfileAvatar(avatarUrl: executorPhoto),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  executorName,
                  style: AppTextStyles.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text('Назначенный исполнитель', style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 18,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _AttachmentsCard extends StatelessWidget {
  final List<_OrderAttachment> attachments;
  final ValueChanged<_OrderAttachment> onOpenAttachment;

  const _AttachmentsCard({
    required this.attachments,
    required this.onOpenAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Вложения', count: attachments.length),
          const SizedBox(height: 12),
          if (attachments.isEmpty)
            Text('К заказу не прикреплены файлы.', style: AppTextStyles.body)
          else
            ...attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AttachmentTile(
                  attachment: attachment,
                  onTap: () => onOpenAttachment(attachment),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final _OrderAttachment attachment;
  final VoidCallback onTap;

  const _AttachmentTile({required this.attachment, required this.onTap});

  String get _extension {
    final dot = attachment.name.lastIndexOf('.');
    if (dot == -1 || dot == attachment.name.length - 1) return 'FILE';

    return attachment.name.substring(dot + 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return AppSurfaceCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        radius: AppRadii.md,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.network(
                attachment.url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: 120,
                    alignment: Alignment.center,
                    child: Text(
                      'Не удалось загрузить изображение',
                      style: AppTextStyles.body,
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Text(
                  attachment.name,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      radius: AppRadii.sm,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            alignment: Alignment.center,
            child: Text(
              _extension,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              attachment.name,
              style: AppTextStyles.small.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

class _OrderActionsCard extends StatelessWidget {
  final bool applying;
  final bool canApply;
  final bool hasApplied;
  final bool assigned;
  final bool canOpenChat;
  final bool canOpenTask;
  final VoidCallback onApply;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenTask;

  const _OrderActionsCard({
    required this.applying,
    required this.canApply,
    required this.hasApplied,
    required this.assigned,
    required this.canOpenChat,
    required this.canOpenTask,
    required this.onApply,
    required this.onOpenChat,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: 'Действия'),
          const SizedBox(height: 12),
          if (canApply)
            ElevatedButton.icon(
              onPressed: applying ? null : onApply,
              icon:
                  applying
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_rounded),
              label: Text(applying ? 'Отправляем заявку...' : 'Подать заявку'),
            )
          else if (hasApplied)
            AppStatusPill.pending('Заявка уже отправлена')
          else if (assigned)
            AppStatusPill.success('Заказ назначен исполнителю')
          else
            const AppStatusPill(
              text: 'Действий нет',
              color: AppColors.textMuted,
              icon: CupertinoIcons.info,
            ),
          if (canOpenChat) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: onOpenChat,
              icon: const Icon(CupertinoIcons.chat_bubble_2),
              label: const Text('Открыть чат'),
            ),
          ],
          if (canOpenTask) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onOpenTask,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Открыть задачу'),
            ),
          ],
        ],
      ),
    );
  }
}
