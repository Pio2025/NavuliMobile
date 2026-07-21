import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/notice_card.dart';
import '../widgets/school_tab_bar.dart';
import 'notice_detail_screen.dart';
import 'notice_form_screen.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  late ApiClient _client;
  final List<Map<String, dynamic>> _notices = [];

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
      final result = await _client.getNotices(schoolId: _schoolId, offset: 0);
      setState(() {
        _notices
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
      final result = await _client.getNotices(
        schoolId: _schoolId,
        offset: _notices.length,
      );
      setState(() {
        _notices.addAll(result.items);
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
  bool get _canPin => _permissions['canPin'] == true;

  Future<void> _openForm({Map<String, dynamic>? notice}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoticeFormScreen(
          notice: notice,
          canPin: _canPin,
          schoolId: _schoolId,
        ),
      ),
    );
    if (saved == true) _loadFirstPage();
  }

  Future<void> _togglePin(Map<String, dynamic> notice) async {
    try {
      final updated = await _client.toggleNoticePin((notice['id'] as num).toInt());
      final index = _notices.indexWhere((n) => n['id'] == notice['id']);
      if (index != -1) setState(() => _notices[index] = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete notice?'),
        content: const Text('This notice will be removed from the board.'),
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
      await _client.deleteNotice((notice['id'] as num).toInt());
      setState(() => _notices.removeWhere((n) => n['id'] == notice['id']));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _openDetail(Map<String, dynamic> notice) {
    final canEdit = notice['canEdit'] == true;
    final canPin = notice['canPin'] == true;
    final canDelete = notice['canDelete'] == true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoticeDetailScreen(
          notice: notice,
          canEdit: canEdit,
          canPin: canPin,
          canDelete: canDelete,
          onEdit: () {
            Navigator.of(context).pop();
            _openForm(notice: notice);
          },
          onTogglePin: () {
            Navigator.of(context).pop();
            _togglePin(notice);
          },
          onDelete: () {
            Navigator.of(context).pop();
            _delete(notice);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Board'),
        actions: [
          if (_canPost)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'New notice',
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
                        Center(child: Text('Failed to load notices: $_error')),
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
                          if (_notices.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 100),
                              child: Center(child: Text('No notices right now.')),
                            )
                          else
                            for (final n in _notices) ...[
                              NoticeCard(
                                notice: n,
                                onTap: () => _openDetail(n),
                                canEdit: n['canEdit'] == true,
                                canPin: n['canPin'] == true,
                                canDelete: n['canDelete'] == true,
                                onEdit: () => _openForm(notice: n),
                                onTogglePin: () => _togglePin(n),
                                onDelete: () => _delete(n),
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
