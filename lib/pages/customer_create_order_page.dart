// lib/pages/customer_create_order_page.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_drawer.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class CustomerCreateOrderPage extends StatefulWidget {
  const CustomerCreateOrderPage({Key? key}) : super(key: key);

  @override
  State<CustomerCreateOrderPage> createState() =>
      _CustomerCreateOrderPageState();
}

class _CustomerCreateOrderPageState extends State<CustomerCreateOrderPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _dateFmt = DateFormat('dd.MM.yyyy');

  DateTime? _deadline;
  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _frameworks = [];
  List<Map<String, dynamic>> _languages = [];
  List<PlatformFile> _files = [];

  String? _selectedFrameworkId;
  String? _selectedLanguageId;

  String? _role;
  String? _name;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
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

  String _roleFallbackByEmail(String email) {
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

    return 'customer';
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

  Future<void> _loadMeta() async {
    setState(() => _loading = true);

    try {
      final service = PocketBaseService.instance;
      final pb = service.pb;
      final userId = service.currentUserId;

      if (userId == null) {
        throw 'Неавторизован';
      }

      final user = await pb.collection('users').getOne(userId);

      _role = _roleFromUser(user.data);
      _name =
          user.data['name'] as String? ??
          user.data['email'] as String? ??
          'User';

      _photo = _fileUrl(
        collectionName: 'users',
        recordId: user.id,
        fileValue: user.data['photo'],
      );

      final frameworkResult = await pb
          .collection('frameworks')
          .getList(page: 1, perPage: 200);

      final languageResult = await pb
          .collection('languages')
          .getList(page: 1, perPage: 200);

      _frameworks =
          frameworkResult.items
              .map((record) {
                return {
                  'id': record.id,
                  'name': record.data['name'] as String? ?? '',
                };
              })
              .where((item) {
                return (item['name'] as String).trim().isNotEmpty;
              })
              .toList()
            ..sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String),
            );

      _languages =
          languageResult.items
              .map((record) {
                return {
                  'id': record.id,
                  'name': record.data['name'] as String? ?? '',
                };
              })
              .where((item) {
                return (item['name'] as String).trim().isNotEmpty;
              })
              .toList()
            ..sort(
              (a, b) => (a['name'] as String).compareTo(b['name'] as String),
            );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _files = [
        ..._files,
        ...result.files.where((file) {
          return !_files.any(
            (existing) =>
                existing.name == file.name && existing.size == file.size,
          );
        }),
      ];
    });
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
  }

  Future<void> _selectReference({
    required String title,
    required List<Map<String, dynamic>> values,
    required String? currentId,
    required ValueChanged<String?> onSelected,
  }) async {
    await showAppBottomSheet(
      context: context,
      title: title,
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children:
            values.map((item) {
              final id = item['id'] as String;
              final name = item['name'] as String;

              return AppBottomSheetOption(
                title: name,
                selected: currentId == id,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(id);
                },
              );
            }).toList(),
      ),
    );
  }

  String _selectedName(List<Map<String, dynamic>> values, String? id) {
    if (id == null) return 'Не выбрано';

    for (final item in values) {
      if (item['id'] == id) {
        return item['name'] as String? ?? 'Не выбрано';
      }
    }

    return 'Не выбрано';
  }

  Future<void> _submitOrder() async {
    final description = _descCtrl.text.trim();
    final price =
        double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.')) ?? 0;

    if (description.isEmpty ||
        _selectedFrameworkId == null ||
        _selectedLanguageId == null ||
        _deadline == null ||
        price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните описание, цену, язык, фреймворк и дедлайн'),
        ),
      );
      return;
    }

    final service = PocketBaseService.instance;
    final userId = service.currentUserId;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь не авторизован')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final order = await service.pb
          .collection('orders')
          .create(
            body: {
              'customer_id': userId,
              'framework_id': _selectedFrameworkId,
              'language_id': _selectedLanguageId,
              'task_description': description,
              'deadline': _deadline!.toIso8601String(),
              'price': price,
            },
          );

      for (final file in _files) {
        final bytes = file.bytes;

        if (bytes == null) continue;

        await service.pb
            .collection('order_attachments')
            .create(
              body: {'order_id': order.id},
              files: [
                http.MultipartFile.fromBytes('url', bytes, filename: file.name),
              ],
            );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заказ создан')));

      context.pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при создании заказа: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
                  : Column(
                    children: [
                      AppTopBar(
                        title: 'Создать заказ',
                        subtitle: 'Описание, бюджет, срок и вложения',
                        onBack: _goBack,
                        onRefresh: _loadMeta,
                      ),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          children: [
                            _CreateOrderIntroCard(
                              name: _name ?? 'Заказчик',
                              avatarUrl: _photo,
                            ),
                            const SizedBox(height: 12),
                            _OrderFormCard(
                              descCtrl: _descCtrl,
                              priceCtrl: _priceCtrl,
                              saving: _saving,
                              frameworkName: _selectedName(
                                _frameworks,
                                _selectedFrameworkId,
                              ),
                              languageName: _selectedName(
                                _languages,
                                _selectedLanguageId,
                              ),
                              deadlineText:
                                  _deadline == null
                                      ? 'Не выбран'
                                      : _dateFmt.format(_deadline!),
                              onPickFramework: () {
                                _selectReference(
                                  title: 'Фреймворк',
                                  values: _frameworks,
                                  currentId: _selectedFrameworkId,
                                  onSelected: (id) {
                                    setState(() => _selectedFrameworkId = id);
                                  },
                                );
                              },
                              onPickLanguage: () {
                                _selectReference(
                                  title: 'Язык',
                                  values: _languages,
                                  currentId: _selectedLanguageId,
                                  onSelected: (id) {
                                    setState(() => _selectedLanguageId = id);
                                  },
                                );
                              },
                              onPickDeadline: _pickDeadline,
                            ),
                            const SizedBox(height: 12),
                            _AttachmentsCard(
                              files: _files,
                              saving: _saving,
                              onPickFiles: _pickFiles,
                              onRemoveFile: _removeFile,
                            ),
                            const SizedBox(height: 12),
                            _SubmitCard(
                              saving: _saving,
                              onSubmit: _submitOrder,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _CreateOrderIntroCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _CreateOrderIntroCard({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AppProfileAvatar(avatarUrl: avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Новый заказ будет доступен исполнителям',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const AppStatusPill(
            text: 'draft',
            color: AppColors.accent,
            icon: CupertinoIcons.doc_text,
          ),
        ],
      ),
    );
  }
}

class _OrderFormCard extends StatelessWidget {
  final TextEditingController descCtrl;
  final TextEditingController priceCtrl;
  final bool saving;
  final String frameworkName;
  final String languageName;
  final String deadlineText;
  final VoidCallback onPickFramework;
  final VoidCallback onPickLanguage;
  final VoidCallback onPickDeadline;

  const _OrderFormCard({
    required this.descCtrl,
    required this.priceCtrl,
    required this.saving,
    required this.frameworkName,
    required this.languageName,
    required this.deadlineText,
    required this.onPickFramework,
    required this.onPickLanguage,
    required this.onPickDeadline,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Параметры заказа'),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            enabled: !saving,
            maxLines: 5,
            minLines: 3,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Описание задачи',
              hintText: 'Опиши, что нужно сделать исполнителю',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceCtrl,
            enabled: !saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Бюджет, ₽',
              hintText: 'Например: 5000',
              suffixIcon: Icon(Icons.currency_ruble_rounded),
            ),
          ),
          const SizedBox(height: 12),
          _PickerRow(
            icon: Icons.view_in_ar_outlined,
            label: 'Фреймворк',
            value: frameworkName,
            disabled: saving,
            onTap: onPickFramework,
          ),
          const SizedBox(height: 10),
          _PickerRow(
            icon: Icons.code_rounded,
            label: 'Язык',
            value: languageName,
            disabled: saving,
            onTap: onPickLanguage,
          ),
          const SizedBox(height: 10),
          _PickerRow(
            icon: CupertinoIcons.calendar,
            label: 'Дедлайн',
            value: deadlineText,
            disabled: saving,
            onTap: onPickDeadline,
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool disabled;
  final VoidCallback onTap;

  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      onTap: disabled ? null : onTap,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      radius: AppRadii.sm,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.small)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.small.copyWith(
                color:
                    value == 'Не выбрано' || value == 'Не выбран'
                        ? AppColors.textMuted
                        : AppColors.text,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _AttachmentsCard extends StatelessWidget {
  final List<PlatformFile> files;
  final bool saving;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemoveFile;

  const _AttachmentsCard({
    required this.files,
    required this.saving,
    required this.onPickFiles,
    required this.onRemoveFile,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Вложения', count: files.length),
          const SizedBox(height: 12),
          Text(
            'Можно прикрепить изображения, документы или архивы. Исполнитель увидит их на странице заказа.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: saving ? null : onPickFiles,
            icon: const Icon(CupertinoIcons.paperclip),
            label: const Text('Добавить файлы'),
          ),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...files.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PickedFileTile(
                  file: entry.value,
                  onRemove: saving ? null : () => onRemoveFile(entry.key),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickedFileTile extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback? onRemove;

  const _PickedFileTile({required this.file, required this.onRemove});

  String get _extension {
    final dot = file.name.lastIndexOf('.');
    if (dot == -1 || dot == file.name.length - 1) return 'FILE';

    return file.name.substring(dot + 1).toUpperCase();
  }

  String get _sizeText {
    final bytes = file.size;

    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }

    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(_sizeText, style: AppTextStyles.caption),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 34,
            onPressed: onRemove,
            child: const Icon(
              CupertinoIcons.xmark_circle,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitCard extends StatelessWidget {
  final bool saving;
  final VoidCallback onSubmit;

  const _SubmitCard({required this.saving, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: saving ? null : onSubmit,
            icon:
                saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check_circle_outline),
            label: Text(saving ? 'Создаём заказ...' : 'Создать заказ'),
          ),
          const SizedBox(height: 10),
          Text(
            'После создания заказ появится у исполнителей в разделе доступных заказов.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
