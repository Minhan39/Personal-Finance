import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:personal_finance/blocs/theme/theme_bloc.dart';
import 'package:personal_finance/core/theme/app_theme.dart';
import 'package:personal_finance/features/auth/login_screen.dart';
import 'package:personal_finance/features/home/home_screen.dart';
import 'package:personal_finance/service/auth_service.dart';
import 'package:personal_finance/service/income_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'blocs/expense/expense_bloc.dart';
import 'blocs/income/income_bloc.dart';
import 'blocs/theme/theme_state.dart';
import 'navigator/navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const webClientId =
      '822917060497-1kf4cpbpun4s2gjvi9odhb1vfjlg9rqj.apps.googleusercontent.com';

  // These services are independent of each other, so start them together.
  await Future.wait([
    Firebase.initializeApp(),
    GoogleSignIn.instance.initialize(serverClientId: webClientId),
    Supabase.initialize(
      url: 'https://fmimpmegzytqaztnzsqh.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtaW1wbWVnenl0cWF6dG56c3FoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1NDI2NTgsImV4cCI6MjA5MjExODY1OH0.X7wnz-9H0trjbCEujZFuAYJDTpUX35RglJDAMiM5oVo',
    ),
  ]);

  // Firebase restores the previous sign-in asynchronously. Waiting for its
  // first auth event keeps the first data load from seeing only Supabase.
  await FirebaseAuth.instance.authStateChanges().first;

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeBloc()),
        BlocProvider(create: (context) => ExpenseBloc()),
        BlocProvider(
          create: (context) => IncomeBloc(incomeService: IncomeService()),
        ),
      ],
      child: const MyApp(),
    ),
  );

  // The notification permission prompt waits for the user, so it must not
  // hold up the first frame.
  unawaited(_setUpMessaging());
}

Future<void> _setUpMessaging() async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Opened from notification');
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Opened app from terminated state');
    }
  } catch (error) {
    debugPrint('FCM setup failed: $error');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: state.mode,
          theme: AppTheme.build(
            seed: state.getColorPrimary,
            brightness: Brightness.light,
          ),
          darkTheme: AppTheme.build(
            seed: state.getColorPrimary,
            brightness: Brightness.dark,
          ),
          routes: routes,
          onGenerateRoute: onGenerateRoute,
          home: StreamBuilder<Session?>(
            stream: AppAuthService.supabaseSessionChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
