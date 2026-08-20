import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'screens/main_scaffold.dart';
import 'screens/messages/light_message_screen.dart';
import 'screens/onboarding/art_interest_onboarding_screen.dart';
import 'services/supabase_service.dart';
import 'services/tencent_push_service.dart';
import 'theme/artsee_app_themes.dart';
import 'theme/artsee_theme_controller.dart';
import 'theme/artsee_ui_colors.dart';
import 'widgets/app_scroll_behavior.dart';
import 'widgets/common.dart';

const supabaseUrl = 'https://nufrgmlhlfmhxsqbybfd.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im51ZnJnbWxobGZtaHhzcWJ5YmZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzA2NDUsImV4cCI6MjA4OTUwNjY0NX0.E90FL3mrUSa18YHMhjyncZQx-yKqCpDTgC18F_ww5to';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await ArtseeThemeController.instance.load();
  _applySystemUi(ArtseeThemeController.instance.isDark);

  runApp(const ArtseeApp());
}

void _applySystemUi(bool isDark) {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? kInkDark : kPorcelain,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ),
  );
}

class ArtseeApp extends StatefulWidget {
  const ArtseeApp({super.key});

  @override
  State<ArtseeApp> createState() => _ArtseeAppState();
}

class _ArtseeAppState extends State<ArtseeApp> {
  @override
  void initState() {
    super.initState();
    ArtseeThemeController.instance.addListener(_onTheme);
  }

  @override
  void dispose() {
    ArtseeThemeController.instance.removeListener(_onTheme);
    super.dispose();
  }

  void _onTheme() {
    _applySystemUi(ArtseeThemeController.instance.isDark);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'artiqore 艺见心',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const ArtseeScrollBehavior(),
      theme: buildArtseeLightTheme(),
      darkTheme: buildArtseeDarkTheme(),
      themeMode: ArtseeThemeController.instance.mode,
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
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;
  bool _onboardingDoneThisSession = false;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<TencentPushNotificationClick>? _pushClickSub;
  bool _openingPushNotification = false;

  @override
  void initState() {
    super.initState();
    _pushClickSub =
        TencentPushService.notificationClicks.listen(_onPushNotification);
    _init();
    _authSub = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => _reload());
  }

  Future<void> _init() async {
    await _reload();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _pushClickSub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!SupabaseService.isLoggedIn) {
      unawaited(TencentPushService.unregister());
      TencentPushService.consumePendingNotification();
      if (mounted) {
        setState(() {
          _profile = null;
          _onboardingDoneThisSession = false;
          _loadingProfile = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loadingProfile = true);
    final p = await SupabaseService.fetchProfile();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loadingProfile = false;
    });
    final dbDone = p != null && p['has_completed_onboarding'] == true;
    final needOnboarding = !dbDone && !_onboardingDoneThisSession;
    if (needOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openPendingPushNotification());
      });
    }
  }

  Future<void> _onOnboardingCompleted() async {
    if (mounted) {
      setState(() {
        _onboardingDoneThisSession = true;
        _loadingProfile = true;
      });
    }

    Map<String, dynamic>? refreshedProfile;
    try {
      refreshedProfile = await SupabaseService.fetchProfile();
    } catch (error) {
      debugPrint('Reload profile after onboarding failed: $error');
    }

    if (mounted) {
      setState(() {
        _profile = {
          ...?_profile,
          ...?refreshedProfile,
          'has_completed_onboarding': true,
        };
        _loadingProfile = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openPendingPushNotification());
      });
    }
  }

  void _onPushNotification(TencentPushNotificationClick _) {
    if (!SupabaseService.isLoggedIn) {
      TencentPushService.consumePendingNotification();
      return;
    }
    unawaited(_openPendingPushNotification());
  }

  Future<void> _openPendingPushNotification() async {
    if (!mounted || _openingPushNotification || _loadingProfile) return;
    if (!SupabaseService.isLoggedIn) {
      TencentPushService.consumePendingNotification();
      return;
    }
    final dbDone =
        _profile != null && _profile!['has_completed_onboarding'] == true;
    final devSkip = AppConfig.devLoginEnabled &&
        SupabaseService.currentUser?.email == 'dev.test@artsee.app';
    if (!dbDone && !_onboardingDoneThisSession && !devSkip) return;

    final click = TencentPushService.consumePendingNotification();
    if (click == null) return;
    if (!click.opensConversation) {
      debugPrint('Ignoring unsupported Tencent Push ext: ${click.rawExt}');
      return;
    }

    _openingPushNotification = true;
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => LightMessageScreen(
            conversation: {
              'id': click.conversationId,
              'title': '消息',
            },
          ),
        ),
      );
    } finally {
      _openingPushNotification = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isLoggedIn) {
      return MainScaffold(key: MainScaffold.globalKey);
    }
    if (_loadingProfile) {
      return Scaffold(
        backgroundColor: context.artC.porcelain,
        body: const Center(
          child: CircularProgressIndicator(color: kCobalt, strokeWidth: 2.5),
        ),
      );
    }
    final dbDone =
        _profile != null && _profile!['has_completed_onboarding'] == true;
    final devSkip = AppConfig.devLoginEnabled &&
        SupabaseService.currentUser?.email == 'dev.test@artsee.app';
    final done = dbDone || _onboardingDoneThisSession || devSkip;
    if (!done) {
      return ArtInterestOnboardingScreen(onCompleted: _onOnboardingCompleted);
    }
    return MainScaffold(
      key: MainScaffold.globalKey,
      initialProfile: _profile,
    );
  }
}
