import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:personal_finance/blocs/theme/theme_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:personal_finance/features/auth/login_screen.dart';
import 'package:personal_finance/features/home/home_screen.dart';
import 'package:personal_finance/service/income_repository.dart';
import 'blocs/expense/expense_bloc.dart';
import 'blocs/income/income_bloc.dart';
import 'blocs/theme/theme_state.dart';
import 'navigator/navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize(
    serverClientId:
        '822917060497-1kf4cpbpun4s2gjvi9odhb1vfjlg9rqj.apps.googleusercontent.com',
  );

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
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
    debugPrint("Opened from notification");
  });

  RemoteMessage? initialMessage = await FirebaseMessaging.instance
      .getInitialMessage();

  if (initialMessage != null) {
    debugPrint("Opened app from terminated state");
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeBloc()),
        BlocProvider(create: (context) => ExpenseBloc()),
        BlocProvider(
          create: (context) =>
              IncomeBloc(incomeRepository: IncomeRepository()),
        ),
      ],
      child: MyApp(),
    ),
  );
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
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: state.getColorPrimary,
            colorScheme: ColorScheme.light(
              primary: state.getColorPrimary,
              secondary: state.getColorSecondary,
              brightness: Brightness.light,
            ),
            iconButtonTheme: IconButtonThemeData(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
                iconColor: WidgetStateProperty.all<Color>(Colors.black),
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: state.getColorPrimary,
            colorScheme: ColorScheme.dark(
              primary: state.getColorPrimary,
              secondary: state.getColorSecondary,
              brightness: Brightness.dark,
            ),
            iconButtonTheme: IconButtonThemeData(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
                iconColor: WidgetStateProperty.all<Color>(Colors.black),
              ),
            ),
          ),
          routes: routes,
          onGenerateRoute: onGenerateRoute,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return HomeScreen();
              } else {
                return LoginScreen();
              }
            },
          ),
        );
      },
    );
  }
}
