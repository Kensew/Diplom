// lib/widgets/app_ui.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_freelance_platform/services/theme.dart';

class AppScreenBackground extends StatelessWidget {
  final Widget child;

  const AppScreenBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundTop, AppColors.background],
        ),
      ),
      child: child,
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const AppSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.radius = AppRadii.lg,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return content;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      pressedOpacity: 0.75,
      onPressed: onTap,
      child: content,
    );
  }
}

class AppIconSurfaceButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? iconColor;

  const AppIconSurfaceButton({
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: size,
      onPressed: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: iconColor ?? AppColors.text),
      ),
    );
  }
}

class AppTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onMenu;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final Widget? trailing;

  const AppTopBar({
    required this.title,
    this.subtitle,
    this.onMenu,
    this.onBack,
    this.onRefresh,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final leadingAction = onBack ?? onMenu;
    final leadingIcon =
        onBack != null
            ? CupertinoIcons.arrow_left
            : CupertinoIcons.line_horizontal_3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          if (leadingAction != null)
            AppIconSurfaceButton(icon: leadingIcon, onTap: leadingAction)
          else
            const SizedBox(width: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.pageTitle),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (trailing != null)
            trailing!
          else if (onRefresh != null)
            AppIconSurfaceButton(
              icon: CupertinoIcons.arrow_clockwise,
              onTap: onRefresh!,
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const AppSearchField({
    required this.controller,
    this.hint = 'Поиск',
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: AppColors.accent,
        style: AppTextStyles.body.copyWith(color: AppColors.text),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: Colors.transparent,
          icon: const Icon(
            CupertinoIcons.search,
            color: AppColors.textMuted,
            size: 18,
          ),
          hintText: hint,
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class AppFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onTap;

  const AppFilterChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final Color border;

    if (danger) {
      background = AppColors.surface;
      foreground = AppColors.danger;
      border = AppColors.border;
    } else if (active) {
      background = AppColors.accentSoft;
      foreground = AppColors.accent;
      border = AppColors.border;
    } else {
      background = AppColors.surface;
      foreground = AppColors.textSecondary;
      border = AppColors.border;
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;

  const AppSectionHeader({
    required this.title,
    this.count,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              count.toString(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expand;

  const AppTag({
    required this.icon,
    required this.label,
    this.expand = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );

    return Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          if (expand)
            Expanded(
              child: Text(
                label,
                style: labelStyle,
                softWrap: true,
              ),
            )
          else
            Text(
              label,
              style: labelStyle,
            ),
        ],
      ),
    );
  }
}

class AppMetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const AppMetaItem({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.small.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppStatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const AppStatusPill({
    required this.text,
    required this.color,
    this.icon,
    super.key,
  });

  factory AppStatusPill.pending(String text) {
    return AppStatusPill(
      text: text,
      color: AppColors.warning,
      icon: CupertinoIcons.clock,
    );
  }

  factory AppStatusPill.success(String text) {
    return AppStatusPill(
      text: text,
      color: AppColors.success,
      icon: CupertinoIcons.check_mark_circled,
    );
  }

  factory AppStatusPill.error(String text) {
    return AppStatusPill(
      text: text,
      color: AppColors.danger,
      icon: CupertinoIcons.xmark_circle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class AppProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  final IconData fallbackIcon;

  const AppProfileAvatar({
    this.avatarUrl,
    this.size = 46,
    this.fallbackIcon = CupertinoIcons.person_fill,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceSoft,
        child:
            avatarUrl != null && avatarUrl!.trim().isNotEmpty
                ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Icon(
                        fallbackIcon,
                        color: AppColors.textMuted,
                        size: size * 0.55,
                      ),
                )
                : Icon(
                  fallbackIcon,
                  color: AppColors.textMuted,
                  size: size * 0.55,
                ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      title: 'Ошибка',
      subtitle: message,
      action: ElevatedButton(
        onPressed: onRetry,
        child: const Text('Повторить'),
      ),
    );
  }
}

class AppBottomSheetOption extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const AppBottomSheetOption({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: selected ? AppColors.accent : AppColors.text,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  softWrap: true,
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTextStyles.caption, softWrap: true),
                ],
              ],
            ),
          ),
          if (selected)
            const Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: AppColors.accent,
              size: 20,
            ),
        ],
      ),
    );
  }
}

Future<void> showAppBottomSheet({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (_) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: AppTextStyles.sectionTitle),
              ),
              const SizedBox(height: 12),
              Flexible(child: child),
            ],
          ),
        ),
      );
    },
  );
}
