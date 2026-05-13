import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import 'volunteer_dashboard.dart';
import '../../../shared/widgets/error_state.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  int? _selectedNgoId;
  final List<String> _skills = [];
  String _availability = 'FLEXIBLE';
  List<dynamic> _ngos = [];
  bool _loading = false;
  bool _loadingNgos = true;
  String? _error;

  final List<Map<String, dynamic>> _skillOptions = [
    {'key': 'MEDICAL', 'label': 'Medical', 'icon': Icons.medical_services_outlined},
    {'key': 'DRIVING', 'label': 'Driving', 'icon': Icons.drive_eta_outlined},
    {'key': 'LOGISTICS', 'label': 'Logistics', 'icon': Icons.inventory_2_outlined},
    {'key': 'TEACHING', 'label': 'Teaching', 'icon': Icons.school_outlined},
    {'key': 'CONSTRUCTION', 'label': 'Construction', 'icon': Icons.construction_outlined},
    {'key': 'GENERAL', 'label': 'General Help', 'icon': Icons.volunteer_activism_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadNgos();
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  Future<void> _loadNgos() async {
    setState(() {
      _loadingNgos = true;
      _error = null;
    });
    try {
      final api = ApiClient();
      final res = await api.dio.get('/ngos');
      if (mounted) {
        setState(() {
          // ApiClient unwraps {success, data} -> returns array
          _ngos = List<Map<String, dynamic>>.from(res.data);
          _loadingNgos = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loadingNgos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load NGOs';
          _loadingNgos = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedNgoId == null) {
      _showError('Please select an NGO');
      return;
    }
    if (_skills.isEmpty) {
      _showError('Please select at least one skill');
      return;
    }

    setState(() => _loading = true);

    try {
      final api = ApiClient();
      await api.dio.post('/volunteers/register', data: {
        'ngo_id': _selectedNgoId,
        'location': _location.text.trim(),
        'skills': _skills,
        'availability': _availability,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VolunteerDashboard()),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You need to complete your profile to access volunteer features. Logout now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) await _logout();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Profile'),
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ),
        body: _loadingNgos
         ? _buildShimmer()
          : _error!= null
           ? ErrorState(message: _error!, onRetry: _loadNgos)
            : _buildForm(cs, tt),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 24, width: 200, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 16, width: double.infinity, color: Colors.white),
              const SizedBox(height: 24),
              Container(height: 56, width: double.infinity, color: Colors.white),
              const SizedBox(height: 16),
              Container(height: 56, width: double.infinity, color: Colors.white),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm(ColorScheme cs, TextTheme tt) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: cs.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complete your profile to start accepting volunteer tasks',
                    style: tt.bodyMedium?.copyWith(color: cs.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // NGO Selection
          DropdownButtonFormField<int>(
            value: _selectedNgoId,
            items: _ngos.map((ngo) => DropdownMenuItem<int>(
              value: ngo['id'],
              child: Row(
                children: [
                  Icon(Icons.business, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(child: Text(ngo['org_name'])),
                ],
              ),
            )).toList(),
            onChanged: (v) => setState(() => _selectedNgoId = v),
            decoration: const InputDecoration(
              labelText: 'Select NGO *',
              helperText: 'Choose an organization to volunteer with',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.volunteer_activism_outlined),
            ),
            validator: (v) => v == null? 'Please select an NGO' : null,
          ),
          const SizedBox(height: 16),

          // Location
          TextFormField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your City/Location *',
              hintText: 'e.g. Lahore, Gujrat',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (v) => v!.trim().length < 3? 'Minimum 3 characters' : null,
          ),
          const SizedBox(height: 16),

          // Availability
          DropdownButtonFormField(
            value: _availability,
            items: const [
              DropdownMenuItem(value: 'FLEXIBLE', child: Text('Flexible - Any time')),
              DropdownMenuItem(value: 'WEEKDAYS', child: Text('Weekdays only')),
              DropdownMenuItem(value: 'WEEKENDS', child: Text('Weekends only')),
            ],
            onChanged: (v) => setState(() => _availability = v!),
            decoration: const InputDecoration(
              labelText: 'Availability',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.schedule_outlined),
            ),
          ),
          const SizedBox(height: 24),

          // Skills Section
          Text(
            'Your Skills *',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Select all that apply',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skillOptions.map((skill) => FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(skill['icon'], size: 18),
                  const SizedBox(width: 6),
                  Text(skill['label']),
                ],
              ),
              selected: _skills.contains(skill['key']),
              onSelected: (sel) => setState(() {
                sel? _skills.add(skill['key']) : _skills.remove(skill['key']);
              }),
            )).toList(),
          ),
          const SizedBox(height: 32),

          // Submit Button
          FilledButton(
            onPressed: _loading? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
           ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Complete Profile', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),

          // Logout Option
          TextButton(
            onPressed: _loading? null : _logout,
            child: Text(
              'Logout and complete later',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}