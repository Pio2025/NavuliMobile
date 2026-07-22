import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/classroom_card.dart';
import 'classroom_detail_screen.dart';

class ClassroomListingScreen extends StatefulWidget {
  final String scope;
  final int? childId;
  final String title;

  const ClassroomListingScreen({
    super.key,
    this.scope = 'all',
    this.childId,
    this.title = 'Classroom Listing',
  });

  @override
  State<ClassroomListingScreen> createState() => _ClassroomListingScreenState();
}

class _ClassroomListingScreenState extends State<ClassroomListingScreen> {
  late ApiClient _client;

  final List<Map<String, dynamic>> _items = [];
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
      final result = await _client.getClassrooms(
        scope: widget.scope,
        childId: widget.scope == 'child' ? widget.childId : null,
        offset: 0,
      );
      setState(() {
        _items
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
    if (_loadingMore || !_hasMore || widget.scope != 'all') return;
    setState(() => _loadingMore = true);
    try {
      final result = await _client.getClassrooms(
        scope: widget.scope,
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

  void _openDetail(Map<String, dynamic> classroom) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassroomDetailScreen(classId: (classroom['id'] as num).toInt()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Failed to load classrooms: $_error'))
                : _items.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadFirstPage,
                        child: ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No classrooms found.')),
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
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i >= _items.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final c = _items[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ClassroomCard(classroom: c, onTap: () => _openDetail(c)),
                              );
                            },
                          ),
                        ),
                      ),
      ),
    );
  }
}
