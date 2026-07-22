import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'classroom_form_screen.dart';
import 'classroom_listing_screen.dart';

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  late ApiClient _client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _schools = [];
  Map<String, dynamic> _permissions = {};

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _client.getClassrooms(limit: 1, offset: 0);
      setState(() {
        _schools = result.schools;
        _permissions = result.permissions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  bool get _hasActiveAdmission => _permissions['hasActiveAdmission'] == true;
  bool get _canViewAllListing => _permissions['canViewAllListing'] == true;
  bool get _canAdd => _permissions['canAdd'] == true;
  bool get _canViewMyClassroom =>
      _permissions['canViewMyClassroom'] == true && _hasActiveAdmission;
  bool get _canViewMyChildClassroom => _permissions['canViewMyChildClassroom'] == true;
  bool get _canViewListing => _hasActiveAdmission || _canViewAllListing;

  void _openListing({required String scope, int? childId, required String title}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassroomListingScreen(scope: scope, childId: childId, title: title),
      ),
    );
  }

  Future<void> _openForm() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClassroomFormScreen(
          schools: _schools,
          canChooseSchool: _canViewAllListing && !_hasActiveAdmission,
        ),
      ),
    );
  }

  Future<void> _openChildClassrooms() async {
    final children = context.read<AuthService>().user?.children ?? [];
    if (children.length <= 1) {
      _openListing(
        scope: 'child',
        childId: children.isEmpty ? null : children.first.userId,
        title: 'My Child Classroom',
      );
      return;
    }
    final childId = await showModalBottomSheet<int?>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('All children'),
              onTap: () => Navigator.of(context).pop(-1),
            ),
            for (final c in children)
              ListTile(
                title: Text(c.name),
                onTap: () => Navigator.of(context).pop(c.userId),
              ),
          ],
        ),
      ),
    );
    if (childId == null) return;
    _openListing(scope: 'child', childId: childId == -1 ? null : childId, title: 'My Child Classroom');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classroom')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Failed to load: $_error'))
                : GridView.count(
                    padding: const EdgeInsets.all(20),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.05,
                    children: [
                      if (_canViewListing)
                        _MenuTile(
                          icon: Icons.view_list_rounded,
                          label: 'Classroom Listing',
                          onTap: () => _openListing(scope: 'all', title: 'Classroom Listing'),
                        ),
                      if (_canAdd)
                        _MenuTile(
                          icon: Icons.add_circle_outline,
                          label: 'Add Classroom',
                          onTap: _openForm,
                        ),
                      if (_canViewMyClassroom)
                        _MenuTile(
                          icon: Icons.school_outlined,
                          label: 'My Classroom',
                          onTap: () => _openListing(scope: 'mine', title: 'My Classroom'),
                        ),
                      if (_canViewMyChildClassroom)
                        _MenuTile(
                          icon: Icons.family_restroom_outlined,
                          label: 'My Child Classroom',
                          onTap: _openChildClassrooms,
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardTheme.color ?? scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
