// lib/services/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/account_page.dart';
import '../pages/customer_applications_page.dart';
import '../pages/customer_create_order_page.dart';
import '../pages/customer_dashboard_page.dart';
import '../pages/customer_orders_page.dart';
import '../pages/edit_profile_page.dart';
import '../pages/feedback_create_page.dart';
import '../pages/executor_orders_page.dart';
import '../pages/log_in_page.dart';
import '../pages/log_up_page.dart';
import '../pages/mock_payment_page.dart';
import '../pages/order_apply_page.dart';
import '../pages/order_more_page.dart';
import '../pages/support_create_page.dart';
import '../pages/support_orders_page.dart';
import '../pages/support_page.dart';
import '../pages/support_communication_page.dart' as support_chat;
import '../pages/task_details_page.dart';
import '../pages/tasks_check_page.dart';
import '../pages/tasks_communication_page.dart' as task_chat;
import '../pages/tasks_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('404 — Страница не найдена')),
        body: Center(child: Text('Маршрут ${state.uri.path} не найден')),
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LogInPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const LogUpPage(),
      ),

      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountPage(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => const EditProfilePage(),
          ),
        ],
      ),

      GoRoute(
        path: '/account/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return AccountPage(userId: userId);
        },
      ),

      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerDashboardPage(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CustomerCreateOrderPage(),
          ),
          GoRoute(
            path: 'applications',
            builder: (context, state) => const CustomerApplicationsPage(),
          ),
        ],
      ),

      GoRoute(
        path: '/orders',
        builder: (context, state) => const CustomerOrdersPage(),
        routes: [
          GoRoute(
            path: 'details/:orderId',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return OrderMorePage(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'apply',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final orderId = extra?['id'] as String?;

              if (orderId == null) {
                return const Scaffold(
                  body: Center(child: Text('Order ID не передан')),
                );
              }

              return OrderApplyPage(orderId: orderId);
            },
          ),
        ],
      ),

      GoRoute(
        path: '/executor',
        builder: (context, state) => const ExecutorOrdersPage(),
      ),

      GoRoute(
        path: '/payments/mock/:paymentRequestId',
        builder: (context, state) {
          final paymentRequestId = state.pathParameters['paymentRequestId']!;
          return MockPaymentPage(paymentRequestId: paymentRequestId);
        },
      ),

      GoRoute(
        path: '/tasks',
        builder: (context, state) => const TasksPage(),
        routes: [
          GoRoute(
            path: 'details/:taskId',
            builder: (context, state) {
              final taskId = state.pathParameters['taskId']!;
              return TaskDetailsPage(taskId: taskId);
            },
          ),
          GoRoute(
            path: 'communication/:taskId',
            builder: (context, state) {
              final taskId = state.pathParameters['taskId']!;
              return task_chat.TasksCommunicationPage(taskId: taskId);
            },
          ),
          GoRoute(
            path: 'check/:taskId',
            builder: (context, state) {
              final taskId = state.pathParameters['taskId']!;
              return TaskCheckPage(taskId: taskId);
            },
          ),
        ],
      ),


      GoRoute(
        path: '/feedbacks/task/:taskId',
        builder: (context, state) {
          final taskId = state.pathParameters['taskId']!;
          return FeedbackCreatePage(taskId: taskId);
        },
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportPage(),
        routes: [
          GoRoute(
            path: 'orders',
            builder: (context, state) => const SupportOrdersPage(),
          ),
          GoRoute(
            path: 'new',
            builder: (context, state) => const SupportCreatePage(),
          ),
          GoRoute(
            path: ':requestId',
            builder: (context, state) {
              final requestId = state.pathParameters['requestId']!;
              return support_chat.SupportCommunicationPage(
                requestId: requestId,
              );
            },
          ),
        ],
      ),
    ],
  );
}
