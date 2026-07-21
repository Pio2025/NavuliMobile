import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AnnouncementFormScreen extends StatefulWidget {
  final Map<String, dynamic>? announcement;
  final int? schoolId;

  const AnnouncementFormScreen({super.key, this.announcement, this.schoolId});

  @override
  State<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late String _priority;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.announcement?['title'] ?? '');
    _contentCtrl = TextEditingController(text: widget.announcement?['content'] ?? '');
    _priority = '${widget.announcement?['priority'] ?? 'Info'}';
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
        await client.updateAnnouncement(
          (widget.announcement!['id'] as num).toInt(),
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          priority: _priority,
        );
      } else {
        await client.createAnnouncement(
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          priority: _priority,
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit Announcement' : 'New Announcement')),
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
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 8,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Content is required' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'Info', child: Text('Info')),
                  DropdownMenuItem(value: 'Important', child: Text('Important')),
                  DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'Info'),
              ),
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
                      : Text(_isEdit ? 'Save Changes' : 'Publish Announcement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
