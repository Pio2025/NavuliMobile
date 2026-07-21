import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class NoticeFormScreen extends StatefulWidget {
  final Map<String, dynamic>? notice;
  final bool canPin;
  final int? schoolId;

  const NoticeFormScreen({super.key, this.notice, this.canPin = false, this.schoolId});

  @override
  State<NoticeFormScreen> createState() => _NoticeFormScreenState();
}

class _NoticeFormScreenState extends State<NoticeFormScreen> {
  static const int _maxContentLength = 250;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late String _priority;
  late String _audience;
  bool _isPinned = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.notice != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.notice?['title'] ?? '');
    _contentCtrl = TextEditingController(text: widget.notice?['content'] ?? '');
    _priority = '${widget.notice?['priority'] ?? 'Normal'}';
    _audience = '${widget.notice?['audience'] ?? 'All'}';
    final pinned = widget.notice?['isPinned'];
    _isPinned = pinned == true || pinned == 1;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final client = ApiClient(context.read<AuthService>());
    try {
      if (_isEdit) {
        await client.updateNotice(
          (widget.notice!['id'] as num).toInt(),
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          priority: _priority,
          audience: _audience,
          isPinned: _isPinned,
        );
      } else {
        await client.createNotice(
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          priority: _priority,
          audience: _audience,
          isPinned: _isPinned,
          schoolId: widget.schoolId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Notice' : 'New Notice')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFF1416C))),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  helperText:
                      'Longer messages should be posted as an Announcement instead.',
                  helperMaxLines: 2,
                ),
                maxLength: _maxContentLength,
                maxLines: 5,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Content is required';
                  if (v.trim().length > _maxContentLength) {
                    return 'Content must be $_maxContentLength characters or fewer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'Important', child: Text('Important')),
                  DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'Normal'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Teachers', child: Text('Teachers')),
                  DropdownMenuItem(value: 'Students', child: Text('Students')),
                  DropdownMenuItem(value: 'Parents', child: Text('Parents')),
                ],
                onChanged: (v) => setState(() => _audience = v ?? 'All'),
              ),
              if (widget.canPin) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pin this notice'),
                  value: _isPinned,
                  onChanged: (v) => setState(() => _isPinned = v ?? false),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEdit ? 'Save Changes' : 'Post Notice'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
