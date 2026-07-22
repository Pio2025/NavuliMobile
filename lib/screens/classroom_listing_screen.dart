import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/classroom_card.dart';
import 'classroom_detail_screen.dart';

enum ClassroomViewMode { card, list, table }

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
  static const _tablePageSize = 10;
  static const _pageSize = 20;

  late ApiClient _client;

  ClassroomViewMode _viewMode = ClassroomViewMode.card;

  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _status;
  int? _schoolId;
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _schools = [];
  Map<String, dynamic> _permissions = {};

  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  List<Map<String, dynamic>> _tableRows = [];
  int _tableOffset = 0;
  int _tableTotal = 0;
  bool _tableLoading = false;

  bool get _isAllScope => widget.scope == 'all';
  bool get _hasActiveAdmission => _permissions['hasActiveAdmission'] == true;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
        search: _isAllScope && _search.isNotEmpty ? _search : null,
        status: _isAllScope ? _status : null,
        schId: _isAllScope ? _schoolId : null,
        limit: _pageSize,
        offset: 0,
      );
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _hasMore = result.hasMore;
        _schools = result.schools;
        _permissions = result.permissions;
        _loading = false;
      });
      if (_viewMode == ClassroomViewMode.table) {
        await _loadTablePage(0);
      }
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || !_isAllScope) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _client.getClassrooms(
        scope: widget.scope,
        search: _search.isEmpty ? null : _search,
        status: _status,
        schId: _schoolId,
        limit: _pageSize,
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

  Future<void> _loadTablePage(int offset) async {
    setState(() {
      _tableLoading = true;
      _tableOffset = offset;
    });
    try {
      if (_isAllScope) {
        final result = await _client.getClassrooms(
          scope: widget.scope,
          search: _search.isEmpty ? null : _search,
          status: _status,
          schId: _schoolId,
          limit: _tablePageSize,
          offset: offset,
        );
        setState(() {
          _tableRows = result.items;
          _tableTotal = result.total;
          _tableLoading = false;
        });
      } else {
        setState(() {
          _tableTotal = _items.length;
          _tableRows = _items.skip(offset).take(_tablePageSize).toList();
          _tableLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _tableLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _setViewMode(ClassroomViewMode mode) {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    if (mode == ClassroomViewMode.table) {
      _loadTablePage(0);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _search = value.trim());
      _loadFirstPage();
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch && _search.isNotEmpty) {
        _searchController.clear();
        _search = '';
        _loadFirstPage();
      }
    });
  }

  Future<void> _pickSchool() async {
    final schId = await showModalBottomSheet<int?>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('All schools'),
              trailing: _schoolId == null ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () => Navigator.of(context).pop(-1),
            ),
            for (final s in _schools)
              ListTile(
                title: Text('${s['schName'] ?? ''}'),
                trailing: _schoolId == (s['schId'] as num).toInt()
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop((s['schId'] as num).toInt()),
              ),
          ],
        ),
      ),
    );
    if (schId == null) return;
    setState(() => _schoolId = schId == -1 ? null : schId);
    _loadFirstPage();
  }

  Future<void> _pickStatus() async {
    const statuses = ['Active', 'Inactive', 'Archived'];
    final status = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('All statuses'),
              trailing: _status == null ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final s in statuses)
              ListTile(
                title: Text(s),
                trailing: _status == s ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.of(context).pop(s),
              ),
          ],
        ),
      ),
    );
    if (status == null) return;
    setState(() => _status = status.isEmpty ? null : status);
    _loadFirstPage();
  }

  Future<void> _openDetail(Map<String, dynamic> classroom) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClassroomDetailScreen(classId: (classroom['id'] as num).toInt()),
      ),
    );
    if (changed == true) _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildToolbar(),
            if (_showSearch && _isAllScope) _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (_isAllScope) ...[
            IconButton(
              icon: Icon(_showSearch ? Icons.search_off : Icons.search, color: scheme.onSurfaceVariant),
              tooltip: 'Search',
              onPressed: _toggleSearch,
            ),
            if (!_hasActiveAdmission && _schools.isNotEmpty)
              IconButton(
                icon: Icon(Icons.apartment,
                    color: _schoolId != null ? AppColors.primary : scheme.onSurfaceVariant),
                tooltip: 'Filter by school',
                onPressed: _pickSchool,
              ),
            IconButton(
              icon: Icon(Icons.filter_alt_outlined,
                  color: _status != null ? AppColors.primary : scheme.onSurfaceVariant),
              tooltip: 'Filter by status',
              onPressed: _pickStatus,
            ),
          ],
          const Spacer(),
          IconButton(
            icon: Icon(Icons.grid_view_rounded,
                color: _viewMode == ClassroomViewMode.card ? AppColors.primary : scheme.onSurfaceVariant),
            tooltip: 'Card view',
            onPressed: () => _setViewMode(ClassroomViewMode.card),
          ),
          IconButton(
            icon: Icon(Icons.view_list_rounded,
                color: _viewMode == ClassroomViewMode.list ? AppColors.primary : scheme.onSurfaceVariant),
            tooltip: 'List view',
            onPressed: () => _setViewMode(ClassroomViewMode.list),
          ),
          IconButton(
            icon: Icon(Icons.table_chart_outlined,
                color: _viewMode == ClassroomViewMode.table ? AppColors.primary : scheme.onSurfaceVariant),
            tooltip: 'Table view',
            onPressed: () => _setViewMode(ClassroomViewMode.table),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search classrooms…',
          prefixIcon: Icon(Icons.search),
          isDense: true,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text('Failed to load classrooms: $_error')),
        ],
      );
    }
    switch (_viewMode) {
      case ClassroomViewMode.card:
        return _buildGrid();
      case ClassroomViewMode.list:
        return _buildList();
      case ClassroomViewMode.table:
        return _buildTable();
    }
  }

  Widget _buildGrid() {
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(child: Text('No classrooms found.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) _loadMore();
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
          ),
          itemCount: _items.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= _items.length) {
              return const Center(child: CircularProgressIndicator());
            }
            final c = _items[i];
            return ClassroomCard(classroom: c, dense: true, onTap: () => _openDetail(c));
          },
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(child: Text('No classrooms found.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) _loadMore();
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
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
    );
  }

  Widget _buildTable() {
    final totalPages = _tableTotal == 0 ? 1 : ((_tableTotal - 1) ~/ _tablePageSize) + 1;
    final currentPage = (_tableOffset ~/ _tablePageSize) + 1;
    return Column(
      children: [
        Expanded(
          child: _tableLoading
              ? const Center(child: CircularProgressIndicator())
              : _tableRows.isEmpty
                  ? const Center(child: Text('No classrooms found.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Year')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('School')),
                          DataColumn(label: Text('Stream')),
                          DataColumn(label: Text('Students')),
                          DataColumn(label: Text('Teacher')),
                        ],
                        rows: [
                          for (final c in _tableRows)
                            DataRow(
                              onSelectChanged: (_) => _openDetail(c),
                              cells: [
                                DataCell(Text('${c['name'] ?? ''}')),
                                DataCell(Text('${c['year'] ?? ''}')),
                                DataCell(Text('${c['status'] ?? ''}')),
                                DataCell(Text('${c['schoolName'] ?? ''}')),
                                DataCell(Text('${c['streamName'] ?? ''}')),
                                DataCell(Text('${c['studentCount'] ?? 0}')),
                                DataCell(Text('${c['classTeacher'] ?? ''}')),
                              ],
                            ),
                        ],
                      ),
                    ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _tableOffset > 0
                    ? () => _loadTablePage(_tableOffset - _tablePageSize)
                    : null,
              ),
              Text('Page $currentPage of $totalPages'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: (_tableOffset + _tablePageSize) < _tableTotal
                    ? () => _loadTablePage(_tableOffset + _tablePageSize)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
