// lib/pages/customer_create_order_page.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:flutter_freelance_platform/services/order_complexity_service.dart';
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
  final _screensCtrl = TextEditingController(text: '1');
  final _dateFmt = DateFormat('dd.MM.yyyy');

  DateTime? _deadline;
  bool _loading = true;
  bool _saving = false;

  bool _requiresFiles = false;
  bool _requiresAuth = false;
  bool _requiresDatabase = false;
  bool _requiresApi = false;
  bool _requiresPayment = false;

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
    _descCtrl.addListener(_refreshComplexityPreview);
    _priceCtrl.addListener(_refreshComplexityPreview);
    _screensCtrl.addListener(_refreshComplexityPreview);
    _loadMeta();
  }

  @override
  void dispose() {
    _descCtrl.removeListener(_refreshComplexityPreview);
    _priceCtrl.removeListener(_refreshComplexityPreview);
    _screensCtrl.removeListener(_refreshComplexityPreview);
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _screensCtrl.dispose();
    super.dispose();
  }

  void _refreshComplexityPreview() {
    if (!mounted) return;
    setState(() {});
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
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _deadline = DateTime(picked.year, picked.month, picked.day);
      });
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

      if (_files.isNotEmpty) {
        _requiresFiles = true;
      }
    });
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
      if (_files.isEmpty) {
        _requiresFiles = false;
      }
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
        children: [
          AppBottomSheetOption(
            title: 'Не выбрано',
            selected: currentId == null,
            onTap: () {
              Navigator.pop(context);
              onSelected(null);
            },
          ),
          ...values.map((item) {
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
          }),
        ],
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

  double _parsePrice() {
    return double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.')) ?? 0;
  }

  int _parseScreensCount() {
    final value = int.tryParse(_screensCtrl.text.trim()) ?? 1;
    return value.clamp(1, 99).toInt();
  }

  OrderComplexityResult _calculateComplexity() {
    return OrderComplexityService.calculateAutoComplexity(
      description: _descCtrl.text,
      deadline: _deadline,
      price: _parsePrice(),
      requiresFiles: _requiresFiles || _files.isNotEmpty,
      requiresAuth: _requiresAuth,
      requiresDatabase: _requiresDatabase,
      requiresApi: _requiresApi,
      requiresPayment: _requiresPayment,
      screensOrFunctionsCount: _parseScreensCount(),
    );
  }

  Future<void> _submitOrder() async {
    final description = _descCtrl.text.trim();
    final price = _parsePrice();

    if (description.isEmpty || _deadline == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните описание, цену и дедлайн')),
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

    final complexity = _calculateComplexity();

    setState(() => _saving = true);

    try {
      final order = await service.pb
          .collection('orders')
          .create(
            body: {
              'customer_id': userId,
              if (_selectedFrameworkId != null)
                'framework_id': _selectedFrameworkId,
              if (_selectedLanguageId != null)
                'language_id': _selectedLanguageId,
              'task_description': description,
              'deadline': _deadline!.toIso8601String(),
              'price': price,
              'complexity_auto': complexity.complexity,
              'complexity_factors': complexity.factorsJson,
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
    final complexity = _calculateComplexity();

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
                        subtitle: 'Описание, бюджет, срок и сложность',
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
                            _ComplexityInputCard(
                              screensCtrl: _screensCtrl,
                              saving: _saving,
                              requiresFiles: _requiresFiles,
                              requiresAuth: _requiresAuth,
                              requiresDatabase: _requiresDatabase,
                              requiresApi: _requiresApi,
                              requiresPayment: _requiresPayment,
                              onRequiresFilesChanged: (value) {
                                setState(() => _requiresFiles = value);
                              },
                              onRequiresAuthChanged: (value) {
                                setState(() => _requiresAuth = value);
                              },
                              onRequiresDatabaseChanged: (value) {
                                setState(() => _requiresDatabase = value);
                              },
                              onRequiresApiChanged: (value) {
                                setState(() => _requiresApi = value);
                              },
                              onRequiresPaymentChanged: (value) {
                                setState(() => _requiresPayment = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            _ComplexityPreviewCard(complexity: complexity),
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

class _ComplexityInputCard extends StatelessWidget {
  final TextEditingController screensCtrl;
  final bool saving;
  final bool requiresFiles;
  final bool requiresAuth;
  final bool requiresDatabase;
  final bool requiresApi;
  final bool requiresPayment;
  final ValueChanged<bool> onRequiresFilesChanged;
  final ValueChanged<bool> onRequiresAuthChanged;
  final ValueChanged<bool> onRequiresDatabaseChanged;
  final ValueChanged<bool> onRequiresApiChanged;
  final ValueChanged<bool> onRequiresPaymentChanged;

  const _ComplexityInputCard({
    required this.screensCtrl,
    required this.saving,
    required this.requiresFiles,
    required this.requiresAuth,
    required this.requiresDatabase,
    required this.requiresApi,
    required this.requiresPayment,
    required this.onRequiresFilesChanged,
    required this.onRequiresAuthChanged,
    required this.onRequiresDatabaseChanged,
    required this.onRequiresApiChanged,
    required this.onRequiresPaymentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Факторы сложности'),
          const SizedBox(height: 12),
          TextField(
            controller: screensCtrl,
            enabled: !saving,
            keyboardType: TextInputType.number,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Количество экранов или функций',
              hintText: 'Например: 3',
              suffixIcon: Icon(Icons.dashboard_customize_outlined),
            ),
          ),
          const SizedBox(height: 8),
          _ComplexitySwitch(
            title: 'Работа с файлами',
            value: requiresFiles,
            onChanged: saving ? null : onRequiresFilesChanged,
          ),
          _ComplexitySwitch(
            title: 'Авторизация или роли',
            value: requiresAuth,
            onChanged: saving ? null : onRequiresAuthChanged,
          ),
          _ComplexitySwitch(
            title: 'База данных',
            value: requiresDatabase,
            onChanged: saving ? null : onRequiresDatabaseChanged,
          ),
          _ComplexitySwitch(
            title: 'Интеграция/API',
            value: requiresApi,
            onChanged: saving ? null : onRequiresApiChanged,
          ),
          _ComplexitySwitch(
            title: 'Оплата или платёжная логика',
            value: requiresPayment,
            onChanged: saving ? null : onRequiresPaymentChanged,
          ),
        ],
      ),
    );
  }
}

class _ComplexitySwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ComplexitySwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(color: AppColors.text),
      ),
      value: value,
      activeColor: AppColors.accent,
      onChanged: onChanged,
    );
  }
}

class _ComplexityPreviewCard extends StatelessWidget {
  final OrderComplexityResult complexity;

  const _ComplexityPreviewCard({required this.complexity});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: 'Автоматическая оценка'),
          const SizedBox(height: 12),
          Row(
            children: [
              AppStatusPill(
                text:
                    'Сложность ${complexity.complexity}/5 · ${OrderComplexityService.complexityLabel(complexity.complexity)}',
                color: AppColors.accent,
                icon: Icons.bar_chart_rounded,
              ),
              const SizedBox(width: 8),
              AppTag(
                icon: CupertinoIcons.sum,
                label: '${complexity.points} балл.',
              ),
            ],
          ),
          if (complexity.factors.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...complexity.factors.map(
              (factor) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.check_mark_circled,
                      size: 17,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${factor.label} (+${factor.points})',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Пока дополнительных факторов нет.',
              style: AppTextStyles.caption,
            ),
          ],
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
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.small.copyWith(color: AppColors.textMuted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.small.copyWith(
                color: AppColors.text,
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

  String _formatSize(int size) {
    if (size < 1024) return '$size Б';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} КБ';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

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
            'Можно приложить техническое задание, изображения, архивы или другие материалы.',
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
            ...files.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppSurfaceCard(
                  padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
                  radius: AppRadii.sm,
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.doc,
                        size: 20,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatSize(file.size),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => onRemoveFile(index),
                        icon: const Icon(
                          CupertinoIcons.xmark_circle,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
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
                    : const Icon(CupertinoIcons.paperplane_fill),
            label: Text(saving ? 'Создаём заказ...' : 'Создать заказ'),
          ),
          const SizedBox(height: 10),
          Text(
            'После создания заказ появится в ленте доступных заказов у исполнителей.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
