import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

class ClassroomFormScreen extends StatefulWidget {
  final List<Map<String, dynamic>> schools;
  final bool canChooseSchool;

  const ClassroomFormScreen({
    super.key,
    this.schools = const [],
    this.canChooseSchool = false,
  });

  @override
  State<ClassroomFormScreen> createState() => _ClassroomFormScreenState();
}

class _ClassroomFormScreenState extends State<ClassroomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late ApiClient _client;

  int? _schoolId;
  int? _streamId;
  List<Map<String, dynamic>> _streams = [];
  bool _loadingStreams = false;

  final _nameController = TextEditingController();
  late final _yearController =
      TextEditingController(text: '${DateTime.now().year}');
  String _status = 'Active';

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = ApiClient(context.read<AuthService>());
    if (!widget.canChooseSchool) {
      _loadStreams();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadStreams() async {
    setState(() {
      _loadingStreams = true;
      _streamId = null;
    });
    try {
      final streams = await _client.getClassroomStreams(schId: _schoolId);
      setState(() {
        _streams = streams;
        _loadingStreams = false;
      });
    } catch (e) {
      setState(() {
        _loadingStreams = false;
        _error = '$e';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _streamId == null) {
      if (_streamId == null) setState(() => _error = 'Please select a stream.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _client.createClassroom(
        streamId: _streamId!,
        className: _nameController.text.trim(),
        classYear: int.parse(_yearController.text.trim()),
        classStatus: _status,
        schId: widget.canChooseSchool ? _schoolId : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Classroom')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Color(0xFFF1416C))),
                const SizedBox(height: 12),
              ],
              if (widget.canChooseSchool) ...[
                DropdownButtonFormField<int>(
                  initialValue: _schoolId,
                  decoration: const InputDecoration(labelText: 'School'),
                  items: [
                    for (final s in widget.schools)
                      DropdownMenuItem(
                        value: (s['schId'] as num).toInt(),
                        child: Text('${s['schName'] ?? ''}'),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => _schoolId = v);
                    _loadStreams();
                  },
                  validator: (v) => v == null ? 'Please select a school' : null,
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<int>(
                initialValue: _streamId,
                decoration: InputDecoration(
                  labelText: 'Stream',
                  suffixIcon: _loadingStreams
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                items: [
                  for (final s in _streams)
                    DropdownMenuItem(
                      value: (s['stream_id'] as num).toInt(),
                      child: Text(
                        '${s['stream_name'] ?? ''}'
                        '${s['level_name'] != null ? ' (${s['level_name']})' : ''}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _streamId = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Class name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Class name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Year'),
                validator: (v) =>
                    (v == null || int.tryParse(v.trim()) == null) ? 'Enter a valid year' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                  DropdownMenuItem(value: 'Archived', child: Text('Archived')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'Active'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
