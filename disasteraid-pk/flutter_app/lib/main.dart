import 'package:disasteraid_pk/core/api/api_client.dart';
import 'package:disasteraid_pk/core/auth/auth_provider.dart';
import 'package:disasteraid_pk/core/settings/app_settings_provider.dart';
import 'package:disasteraid_pk/core/services/socket_service.dart';
import 'package:disasteraid_pk/features/admin/admin_dashboard.dart';
import 'package:disasteraid_pk/features/auth/login_screen.dart';
import 'package:disasteraid_pk/features/auth/register_screen.dart';
import 'package:disasteraid_pk/features/beneficiaries/screens/beneficiary_dashboard.dart';
import 'package:disasteraid_pk/features/campaigns/screens/campaign_create_screen.dart';
import 'package:disasteraid_pk/features/chat/screens/services/chat_badge_provider.dart';
import 'package:disasteraid_pk/features/donor/donor_dashboard.dart';
import 'package:disasteraid_pk/features/maps/campaign_map_screen.dart';
import 'package:disasteraid_pk/features/ngo/ngo_dashboard.dart';
import 'package:disasteraid_pk/features/ngo/ngo_onboard_screen.dart';
import 'package:disasteraid_pk/features/volunteers/complete_profile_screen.dart';
import 'package:disasteraid_pk/features/volunteers/volunteer_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider( // CHANGED FROM ChangeNotifierProvider
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
        ChangeNotifierProvider(create: (_) => ChatBadgeProvider()), // ADD THIS
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
      ],
      child: Consumer2<AuthProvider, AppSettingsProvider>(
        builder: (context, auth, settings, _) {
          return MaterialApp(
            title: 'DisasterAid PK',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6B48)),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0B6B48),
                brightness: Brightness.dark,
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              useMaterial3: true,
            ),
            themeMode: settings.themeMode,
            debugShowCheckedModeBanner: false,
            initialRoute: auth.isAuthenticated ? '/' : '/login',
            routes: {
              '/': (_) => const AppShell(),
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/ngo/onboard': (_) => const NgoOnboardScreen(),
              '/campaign/create': (_) => const CampaignCreateScreen(),
              '/volunteer/complete-profile': (_) => const CompleteProfileScreen(),
              '/map' : (_) => const CampaignMapScreen(),
            },
          );
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _ngoStatus;
  bool _loadingStatus = true;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user?['role'] == 'ngo') {
      _fetchNgoStatus();
    } else {
      _loadingStatus = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user;
    if (user != null && user['id'] != null) {
      SocketService().connect(user['id']);
      
      // Load unread chat count on login
      context.read<ChatBadgeProvider>().refreshUnread(); // ADD THIS
      
      SocketService().onNotification = (data) {
        final messenger = _scaffoldMessengerKey.currentState;
        messenger?.hideCurrentMaterialBanner();
        messenger?.showMaterialBanner(
          MaterialBanner(
            leading: const Icon(Icons.notifications_active_outlined),
            content: Text(data['title']?.toString() ?? 'New notification'),
            actions: [
              TextButton(
                onPressed: () => messenger?.hideCurrentMaterialBanner(),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      };

      // ADD THIS: Refresh badge on new message
      SocketService().on('new_message', (data) {
        if (mounted) {
          context.read<ChatBadgeProvider>().refreshUnread();
        }
      });
    }
  }

  @override
  void dispose() {
    SocketService().disconnect();
    super.dispose();
  }

Future<void> _fetchNgoStatus() async {
  try {
    final api = ApiClient();
    final res = await api.dio.get('/ngos/me');
    if (!mounted) return;
    setState(() => _ngoStatus = (res.data as Map?)?['status']?.toString()); // FIXED: removed ['data']
  } catch (e) {
    if (!mounted) return;
    setState(() => _ngoStatus = null);
  } finally {
    if (mounted) setState(() => _loadingStatus = false);
  }
}
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?['role'];

    if (_loadingStatus) {
      return const Scaffold(body: Center(child: LinearProgressIndicator()));
    }

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: switch (role) {
        'admin' => const AdminDashboard(),
        'ngo' => _ngoStatus == 'APPROVED' 
           ? const NgoDashboard() 
            : NgoStatusScreen(status: _ngoStatus, onRefresh: _fetchNgoStatus),
        'donor' => const DonorDashboard(),
        'volunteer' => const VolunteerDashboard(),
        'beneficiary' => const BeneficiaryDashboard(),
        _ => const LoginScreen(),
      },
    );
  }
}

class NgoStatusScreen extends StatelessWidget {
  final String? status;
  final VoidCallback onRefresh;
  const NgoStatusScreen({super.key, this.status, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Verification'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthProvider>().logout())],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (status == null)...[
                Icon(Icons.business, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text('Complete Your Profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Submit documents to get verified', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/ngo/onboard').then((_) => onRefresh()),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Start Verification'),
                ),
              ] else if (status == 'PENDING')...[
                Icon(Icons.hourglass_top, size: 80, color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(height: 24),
                Text('Pending Approval', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Admin is reviewing your documents', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Refresh Status')),
              ] else if (status == 'REJECTED')...[
                Icon(Icons.cancel, size: 80, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 24),
                Text('Application Rejected', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Please resubmit with correct documents', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/ngo/onboard').then((_) => onRefresh()),
                  icon: const Icon(Icons.edit),
                  label: const Text('Resubmit Application'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
