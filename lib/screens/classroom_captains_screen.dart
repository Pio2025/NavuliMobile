import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class ClassroomCaptainsScreen extends StatefulWidget {
  final int classId;

  const ClassroomCaptainsScreen({super.key, required this.classId});

  @override
  State<ClassroomCaptainsScreen> createState() => _ClassroomCaptainsScreenState();
}

class _ClassroomCaptainsScreenState extends State<ClassroomCaptainsScreen> {
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

  Widget _roleTile(String role, String label) {
    final scheme = Theme.of(context).colorScheme;
    final entry = _staff[role] is Map ? Map<String, dynamic>.from(_staff[role]) : null;
    final name = entry != null ? '${entry['name'] ?? ''}' : '';
    final photo = entry != null ? '${entry['photo'] ?? ''}' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: photo.isNotEmpty ? NetworkImage(ApiConfig.photoUrl(photo)) : null,
            child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  name.isNotEmpty ? name : 'Not assigned',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: name.isNotEmpty ? null : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Class Captains')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Failed to load captains: $_error'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _roleTile('Class Captain', 'Class Captain'),
                        _roleTile('Assistant Class Captain', 'Assistant Class Captain'),
                      ],
                    ),
                  ),
      ),
    );
  }
}
