import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ClassroomStaffScreen extends StatefulWidget {
  final int classId;

  const ClassroomStaffScreen({super.key, required this.classId});

  @override
  State<ClassroomStaffScreen> createState() => _ClassroomStaffScreenState();
}

class _ClassroomStaffScreenState extends State<ClassroomStaffScreen> {
  static const _roles = [
    'Class Teacher',
    'Assistant Class Teacher',
    'Class Captain',
    'Assistant Class Captain',
  ];

  late ApiClient _client;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _staff = {};

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
      final staff = await _client.getClassroomStaff(widget.classId);
      setState(() {
        _staff = staff;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Failed to load staff: $_error'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final role in _roles) ...[
                          Builder(builder: (context) {
                            final entry = _staff[role];
                            final person = entry is Map ? Map<String, dynamic>.from(entry) : null;
                            final name = person?['name'] as String?;
                            final photo = person?['photo'] as String?;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardTheme.color ?? scheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                      backgroundImage: (photo != null && photo.isNotEmpty)
                                          ? NetworkImage(ApiConfig.photoUrl(photo))
                                          : null,
                                      child: (photo == null || photo.isEmpty)
                                          ? const Icon(Icons.person, color: AppColors.primary)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(role,
                                              style: TextStyle(
                                                  fontSize: 12, color: scheme.onSurfaceVariant)),
                                          const SizedBox(height: 2),
                                          Text(
                                            name != null && name.isNotEmpty ? name : 'Not assigned',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
