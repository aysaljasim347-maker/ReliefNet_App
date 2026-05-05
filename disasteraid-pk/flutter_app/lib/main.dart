import 'package:flutter/material.dart';
import 'core/api/api_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/ngo/ngo_onboard_screen.dart';
import 'features/admin/admin_dashboard.dart';
import 'features/campaigns/screens/campaign_list_screen.dart';
import 'features/campaigns/screens/campaign_create_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..checkAuth(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'DisasterAid PK',
            theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green), useMaterial3: true),
            home:!auth.isAuthenticated? const LoginScreen() : const AppShell(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/ngo/onboard': (_) => const NgoOnboardScreen(),
              '/campaign/create': (_) => const CampaignCreateScreen(),
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

    if (role == 'admin') return const AdminDashboard();
    if (role == 'ngo') {
      if (_ngoStatus == 'APPROVED') return const NgoDashboard();
      return NgoStatusScreen(status: _ngoStatus, onRefresh: _fetchNgoStatus);
    }
    if (role == 'donor') return const CampaignListScreen();

    return const LoginScreen();
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

class NgoDashboard extends StatelessWidget {
  const NgoDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthProvider>().logout())],
      ),
      body: const Center(child: Text('Module 3: Create Campaigns')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/campaign/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create Campaign'),
      ),
    );
  }
}
