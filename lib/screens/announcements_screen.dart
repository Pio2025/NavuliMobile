import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/announcement_card.dart';
import '../widgets/school_tab_bar.dart';
import 'announcement_detail_screen.dart';
import 'announcement_form_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late ApiClient _client;
  final List<Map<String, dynamic>> _items = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  int? _schoolId;
  List<Map<String, dynamic>> _schools = [];
  Map<String, dynamic> _permissions = {};

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
      final result = await _client.getAnnouncements(schoolId: _schoolId, offset: 0);
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _hasMore = result.hasMore;
        _schools = result.schools;
        _schoolId = result.activeSchoolId;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _client.getAnnouncements(
        schoolId: _schoolId,
        offset: _items.length,
      );
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  void _switchSchool(int schId) {
    setState(() => _schoolId = schId);
    _loadFirstPage();
  }

  bool get _canPost => _permissions['canPost'] == true;

  Future<void> _openForm({Map<String, dynamic>? announcement}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnnouncementFormScreen(
          announcement: announcement,
          schoolId: _schoolId,
        ),
      ),
    );
    if (saved == true) _loadFirstPage();
  }

  Future<void> _delete(Map<String, dynamic> announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete announcement?'),
        content: const Text('This announcement will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFF1416C))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.deleteAnnouncement((announcement['id'] as num).toInt());
      setState(() => _items.removeWhere((a) => a['id'] == announcement['id']));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openDetail(Map<String, dynamic> announcement) {
    final canEdit = announcement['canEdit'] == true;
    final canDelete = announcement['canDelete'] == true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(
          announcement: announcement,
          canEdit: canEdit,
          canDelete: canDelete,
          onEdit: () {
            Navigator.of(context).pop();
            _openForm(announcement: announcement);
          },
          onDelete: () {
            Navigator.of(context).pop();
            _delete(announcement);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          if (_canPost)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'New announcement',
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadFirstPage,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text('Failed to load announcements: $_error'),
                        ),
                      ],
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                          _loadMore();
                        }
                        return false;
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SchoolTabBar(
                            schools: _schools,
                            activeSchoolId: _schoolId ?? 0,
                            onSelected: _switchSchool,
                          ),
                          if (_items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 100),
                              child: Center(child: Text('No announcements right now.')),
                            )
                          else
                            for (final a in _items) ...[
                              AnnouncementCard(
                                announcement: a,
                                onTap: () => _openDetail(a),
                                canEdit: a['canEdit'] == true,
                                canDelete: a['canDelete'] == true,
                                onEdit: () => _openForm(announcement: a),
                                onDelete: () => _delete(a),
                                compact: true,
                              ),
                              const SizedBox(height: 12),
                            ],
                          if (_loadingMore)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
