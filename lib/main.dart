// lib/main.dart

import 'package:flutter/material.dart';

import 'package:flutter_freelance_platform/services/app_router.dart';
import 'package:flutter_freelance_platform/services/pocketbase_service.dart';
import 'package:flutter_freelance_platform/services/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PocketBaseService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Freelance Platform',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
    );
  }
}
