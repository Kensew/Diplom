// lib/widgets/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentRoute = GoRouterState.of(context).uri.toString();
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Drawer(
      child: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 28,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.fieldFill,
                      backgroundImage:
                          hasAvatar ? NetworkImage(avatarUrl!) : null,
                      child:
                          !hasAvatar
                              ? Icon(
                                Icons.person_rounded,
                                size: 36,
                                color: cs.onBackground,
                              )
                              : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        displayName,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          color: cs.onBackground,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: Colors.white.withOpacity(0.3)),

              if (role == 'customer') ...[
                _DrawerItem(
                  icon: Icons.dashboard_customize_rounded,
                  label: 'Dashboard',
                  route: '/customer',
                  selected: currentRoute == '/customer',
                ),
                _DrawerItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'My Orders',
                  route: '/orders',
                  selected: currentRoute == '/orders',
                ),
                _DrawerItem(
                  icon: Icons.add_circle_rounded,
                  label: 'Create Order',
                  route: '/customer/create',
                  selected: currentRoute == '/customer/create',
                ),
                _DrawerItem(
                  icon: Icons.mail_outline_rounded,
                  label: 'Applications',
                  route: '/customer/applications',
                  selected: currentRoute == '/customer/applications',
                ),
              ],

              if (role == 'executor') ...[
                _DrawerItem(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Available Orders',
                  route: '/executor',
                  selected: currentRoute == '/executor',
                ),
                _DrawerItem(
                  icon: Icons.task_rounded,
                  label: 'My Tasks',
                  route: '/tasks',
                  selected: currentRoute == '/tasks',
                ),
              ],

              if (role == 'support') ...[
                _DrawerItem(
                  icon: Icons.view_list_rounded,
                  label: 'All Orders',
                  route: '/support/orders',
                  selected: currentRoute == '/support/orders',
                ),
                _DrawerItem(
                  icon: Icons.support_agent_rounded,
                  label: 'Support Chats',
                  route: '/support',
                  selected: currentRoute == '/support',
                ),
              ] else ...[
                _DrawerItem(
                  icon: Icons.support_agent_rounded,
                  label: 'Support',
                  route: '/support',
                  selected: currentRoute == '/support',
                ),
              ],

              const Spacer(),

              Divider(height: 1, color: Colors.white.withOpacity(0.3)),

              _DrawerItem(
                icon: Icons.account_circle_rounded,
                label: 'Profile',
                route: '/account',
                selected: currentRoute == '/account',
              ),
              _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                route: '/login',
                selected: false,
                onTap: () => _logout(context),
              ),
            ],
          ),
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
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap:
          onTap ??
          () {
            Navigator.of(context).pop();
            context.go(route);
          },
      child: Container(
        decoration: BoxDecoration(
          color: selected ? cs.secondary.withOpacity(0.28) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: selected ? cs.onSecondary : AppColors.text,
            ),
            const SizedBox(width: 18),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? cs.onSecondary : AppColors.text,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
