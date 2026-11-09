import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/project_store.dart';

class ProjectEditorPage extends StatefulWidget {
  const ProjectEditorPage({
    super.key,
    required this.project,
    this.store,
  });

  final QxProject project;
  final ProjectStore? store;

  @override
  State<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends State<ProjectEditorPage> {
  static const _projectTypes = <String>[
    'مشروع عام / General project',
    'تطبيق / App',
    'موقع إلكتروني / Website',
    'أداة / Tool',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _projectType;
  bool _isSaving = false;
  String? _errorMessage;

  ProjectStore get _store => widget.store ?? ProjectStore();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _descriptionController =
        TextEditingController(text: widget.project.description);
    _projectType = widget.project.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedProject = await _store.updateProject(
        QxProject(
          id: widget.project.id,
          name: _nameController.text.trim(),
          type: _projectType,
          description: _descriptionController.text.trim(),
          createdAt: widget.project.createdAt,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updatedProject);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage =
            'تعذّر حفظ التعديلات / Could not save changes. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('فتح المشروع / Open project'),
          backgroundColor: const Color(0xFF0B0D13),
        ),
        backgroundColor: const Color(0xFF0B0D13),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151923),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .07),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تفاصيل المشروع / Project details',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nameController,
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'اسم المشروع / Project name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'أدخل اسم المشروع / Enter a project name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _projectTypes.contains(_projectType)
                            ? _projectType
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'نوع المشروع / Project type',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          if (!_projectTypes.contains(_projectType))
                            DropdownMenuItem(
                              value: _projectType,
                              child: Text(_projectType),
                            ),
                          ..._projectTypes.map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _projectType = value);
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_isSaving,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText:
                              'وصف المشروع / Project description (optional)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _isSaving
                                ? 'جارٍ الحفظ / Saving'
                                : 'حفظ التعديلات / Save changes',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
