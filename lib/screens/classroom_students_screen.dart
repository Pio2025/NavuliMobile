import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ClassroomStudentsScreen extends StatefulWidget {
  final int classId;

  const ClassroomStudentsScreen({super.key, required this.classId});

  @override
  State<ClassroomStudentsScreen> createState() => _ClassroomStudentsScreenState();
}

class _ClassroomStudentsScreenState extends State<ClassroomStudentsScreen> {
  late ApiClient _client;
  final List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _client.getClassroomStudents(widget.classId, offset: 0);
      setState(() {
        _students
          ..clear()
          ..addAll(result.items);
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _client.getClassroomStudents(widget.classId, offset: _students.length);
      setState(() {
        _students.addAll(result.items);
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  Widget _statusBadge(String status) {
    final Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = AppColors.success;
        break;
      case 'inactive':
        color = AppColors.danger;
        break;
      default:
        color = const Color(0xFF9A9AB2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Failed to load students: $_error'))
                : _students.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadFirstPage,
                        child: ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No students enrolled yet.')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadFirstPage,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                              _loadMore();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _students.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i >= _students.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final s = _students[i];
                              final name = '${s['name'] ?? ''}';
                              final photo = s['photo'] as String?;
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
                                        radius: 16,
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
                                        child: Text(name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600, fontSize: 14)),
                                      ),
                                      _statusBadge('${s['status'] ?? ''}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
      ),
    );
  }
}
