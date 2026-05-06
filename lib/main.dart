import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alt_gate/features/gate/turnike_simulator.dart';

import 'core/corporate_theme.dart';
import 'core/platform/native_desktop_check.dart';
import 'firebase_options.dart';
import 'features/auth/login_screen.dart';
import 'features/gate/gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught async error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  runZonedGuarded(
    () async {
      await relaunchAppAfterBootstrap();
    },
    (error, stackTrace) {
      debugPrint('runZonedGuarded fatal capture: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
}

/// Firebase yeniden deneme ve `runApp`; `main()` tekrar çağrılmaz (çift başlatma önlenir).
Future<void> relaunchAppAfterBootstrap() async {
  final bootstrapState = await _bootstrapApp();
  runApp(
    ProviderScope(
      child: AltGateApp(
        firebaseReady: bootstrapState.firebaseReady,
        bootstrapError: bootstrapState.errorMessage,
      ),
    ),
  );
}

final authStateChangesProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

class _BootstrapState {
  const _BootstrapState({required this.firebaseReady, this.errorMessage});

  final bool firebaseReady;
  final String? errorMessage;
}

Future<_BootstrapState> _bootstrapApp() async {
  try {
    await _initializeFirebaseSafely();
    return const _BootstrapState(firebaseReady: true);
  } catch (error, stackTrace) {
    debugPrint('Bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    return _BootstrapState(
      firebaseReady: false,
      errorMessage: _friendlyBootstrapError(error),
    );
  }
}

Future<void> _initializeFirebaseSafely() async {
  if (Firebase.apps.isNotEmpty) return;

  try {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return;
    } on FirebaseException catch (error) {
      final fallbackAllowed =
          _isApplePlatform &&
          (error.message?.contains('bundle') == true ||
              error.message?.contains('Bundle') == true ||
              error.code == 'unknown');

      if (!fallbackAllowed) rethrow;

      if (kDebugMode) {
        debugPrint('Firebase options init failed, retrying with native plist.');
        debugPrint('Firebase error: ${error.code} ${error.message}');
      }

      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
          return;
        } catch (fallbackError, fallbackStack) {
          debugPrint('Firebase native plist init failed: $fallbackError');
          debugPrintStack(stackTrace: fallbackStack);
          rethrow;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Firebase.initializeApp(options) unexpected: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
          return;
        } catch (e2, st2) {
          debugPrint('Firebase.initializeApp() last resort failed: $e2');
          debugPrintStack(stackTrace: st2);
          rethrow;
        }
      }
      rethrow;
    }
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization shield: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}

bool get _isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

String _friendlyBootstrapError(Object error) {
  if (error is FirebaseException) {
    return 'Firebase baslatilirken bir problem olustu. '
        'Lutfen internet baglantisini ve uygulama ayarlarini kontrol et.';
  }
  return 'Uygulama baslatilirken beklenmeyen bir hata olustu.';
}

class AltGateApp extends StatelessWidget {
  const AltGateApp({
    super.key,
    required this.firebaseReady,
    this.bootstrapError,
  });

  final bool firebaseReady;
  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADÜPass',
      debugShowCheckedModeBanner: false,
      theme: buildCorporateLightTheme(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (kIsWeb) {
      return const TurnikeSimulatorScreen();
    }

    if (isNativeDesktopPlatform) {
      return const TurnikeSimulatorScreen();
    }

    return firebaseReady
        ? const AuthGate()
        : BootstrapErrorScreen(message: bootstrapError);
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => user == null ? const LoginScreen() : const GateScreen(),
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.secondaryBlue),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Oturum durumu okunurken bir hata oluştu:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BootstrapErrorScreen extends StatelessWidget {
  const BootstrapErrorScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.secondaryBlue,
                        size: 44,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Uygulama Baslatilamadi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message ??
                            'Baslatma sirasinda beklenmeyen bir sorun olustu.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            unawaited(relaunchAppAfterBootstrap());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Yeniden Baslat',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
