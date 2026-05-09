import 'package:disasteraid_pk/core/api/api_client.dart';
import 'package:disasteraid_pk/core/auth/auth_provider.dart';
import 'package:disasteraid_pk/core/services/socket_serivce.dart';
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
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'DisasterAid PK',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
              useMaterial3: true,
            ),
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
      setState(() => _loadingStatus = false);
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
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(data['title'] ?? 'New notification'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // TODO: Navigate to notifications screen
              },
            ),
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
      setState(() => _ngoStatus = res.data['data']?['status']);
    } catch (e) {
      setState(() => _ngoStatus = null);
    } finally {
      setState(() => _loadingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?['role'];

    if (_loadingStatus) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
                const Icon(Icons.business, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                const Text('Complete Your Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Submit documents to get verified', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/ngo/onboard').then((_) => onRefresh()),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Start Verification'),
                ),
              ] else if (status == 'PENDING')...[
                const Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                const Text('Pending Approval', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Admin is reviewing your documents', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Refresh Status')),
              ] else if (status == 'REJECTED')...[
                const Icon(Icons.cancel, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                const Text('Application Rejected', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Please resubmit with correct documents', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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