import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_scaffold.dart';

const supabaseUrl = 'https://nufrgmlhlfmhxsqbybfd.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im51ZnJnbWxobGZtaHhzcWJ5YmZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzA2NDUsImV4cCI6MjA4OTUwNjY0NX0.E90FL3mrUSa18YHMhjyncZQx-yKqCpDTgC18F_ww5to';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const ArtseeApp());
}

class ArtseeApp extends StatelessWidget {
  const ArtseeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '艺见心',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6A00),
          primary: const Color(0xFFFF6A00),
        ),
        useMaterial3: true,
        fontFamily: 'PingFang SC',
        scaffoldBackgroundColor: const Color(0xFFF8F8F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Always show main scaffold; auth-required pages redirect to login
        return const MainScaffold();
      },
    );
  }
}
