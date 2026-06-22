// lib/widgets/app_drawer.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';
import 'package:flutter_freelance_platform/widgets/app_ui.dart';

class AppDrawer extends StatelessWidget {
  final String role;
  final String displayName;
  final String? avatarUrl;

  const AppDrawer({
    Key? key,
    required this.role,
    required this.displayName,
    this.avatarUrl,
  }) : super(key: key);

  void _logout(BuildContext context) {
    PocketBaseService.instance.logout();

    Navigator.of(context).pop();
    context.go('/login');
  }

  String get _roleLabel {
    switch (role) {
      case 'customer':
        return 'Заказчик';
      case 'executor':
        return 'Исполнитель';
      case 'support':
        return 'Поддержка';
      default:
        return 'Пользователь';
    }
  }

  bool _isSelected(String currentRoute, String route) {
    if (route == '/customer' || route == '/executor' || route == '/support') {
      return currentRoute == route;
    }

    return currentRoute == route || currentRoute.startsWith('$route/');
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();

    return Drawer(
      width: 304,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      child: AppScreenBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(
                displayName: displayName,
                roleLabel: _roleLabel,
                avatarUrl: avatarUrl,
                onProfileTap: () {
                  Navigator.of(context).pop();
                  context.go('/account');
                },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Divider(height: 1),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (role == 'customer') ...[
                      const _DrawerGroupTitle('Заказчик'),
                      _DrawerItem(
                        icon: Icons.dashboard_outlined,
                        label: 'Главная',
                        route: '/customer',
                        selected: _isSelected(currentRoute, '/customer'),
                      ),
                      _DrawerItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Мои заказы',
                        route: '/orders',
                        selected: _isSelected(currentRoute, '/orders'),
                      ),
                      _DrawerItem(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Создать заказ',
                        route: '/customer/create',
                        selected: _isSelected(currentRoute, '/customer/create'),
                      ),
                      _DrawerItem(
                        icon: Icons.person_search_rounded,
                        label: 'Исполнители',
                        route: '/customer/executors',
                        selected: _isSelected(
                          currentRoute,
                          '/customer/executors',
                        ),
                      ),
                      _DrawerItem(
                        icon: Icons.mail_outline_rounded,
                        label: 'Заявки и оплаты',
                        route: '/customer/applications',
                        selected: _isSelected(
                          currentRoute,
                          '/customer/applications',
                        ),
                      ),
                    ],

                    if (role == 'executor') ...[
                      const _DrawerGroupTitle('Исполнитель'),
                      _DrawerItem(
                        icon: Icons.work_outline_rounded,
                        label: 'Доступные заказы',
                        route: '/executor',
                        selected: _isSelected(currentRoute, '/executor'),
                      ),
                      _DrawerItem(
                        icon: CupertinoIcons.mail,
                        label: 'Приглашения',
                        route: '/executor/invitations',
                        selected: _isSelected(
                          currentRoute,
                          '/executor/invitations',
                        ),
                      ),
                      _DrawerItem(
                        icon: Icons.task_alt_rounded,
                        label: 'Мои задачи',
                        route: '/tasks',
                        selected: _isSelected(currentRoute, '/tasks'),
                      ),
                    ],

                    if (role == 'support') ...[
                      const _DrawerGroupTitle('Поддержка'),
                      _DrawerItem(
                        icon: Icons.view_list_outlined,
                        label: 'Все заказы',
                        route: '/support/orders',
                        selected: _isSelected(currentRoute, '/support/orders'),
                      ),
                      _DrawerItem(
                        icon: Icons.people_outline_rounded,
                        label: 'Пользователи',
                        route: '/support/users',
                        selected: _isSelected(currentRoute, '/support/users'),
                      ),
                      _DrawerItem(
                        icon: Icons.support_agent_rounded,
                        label: 'Чаты поддержки',
                        route: '/support',
                        selected: _isSelected(currentRoute, '/support'),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      _DrawerItem(
                        icon: Icons.support_agent_rounded,
                        label: 'Поддержка',
                        route: '/support',
                        selected: _isSelected(currentRoute, '/support'),
                      ),
                    ],

                    const SizedBox(height: 8),
                    const _DrawerGroupTitle('Аккаунт'),
                    _DrawerItem(
                      icon: CupertinoIcons.person_crop_circle,
                      label: 'Профиль',
                      route: '/account',
                      selected: _isSelected(currentRoute, '/account'),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                child: _LogoutButton(onTap: () => _logout(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final String displayName;
  final String roleLabel;
  final String? avatarUrl;
  final VoidCallback onProfileTap;

  const _DrawerHeader({
    required this.displayName,
    required this.roleLabel,
    required this.avatarUrl,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: AppSurfaceCard(
        onTap: onProfileTap,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        radius: AppRadii.md,
        child: Row(
          children: [
            AppProfileAvatar(avatarUrl: avatarUrl, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName.trim().isEmpty ? 'Пользователь' : displayName,
                    style: AppTextStyles.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(roleLabel, style: AppTextStyles.caption),
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
      ),
    );
  }
}

class _DrawerGroupTitle extends StatelessWidget {
  final String title;

  const _DrawerGroupTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 7),
      child: Text(
        title,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool selected;
  final VoidCallback? onTap;

  const _DrawerItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.route,
    required this.selected,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.accent : AppColors.textSecondary;
    final background = selected ? AppColors.accentSoft : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 0,
        pressedOpacity: 0.68,
        onPressed:
            onTap ??
            () {
              Navigator.of(context).pop();
              context.go(route);
            },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: selected ? AppColors.border : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.small.copyWith(
                    color: selected ? AppColors.text : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      pressedOpacity: 0.7,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.logout_rounded,
                size: 20,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Выйти',
                style: AppTextStyles.small.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
