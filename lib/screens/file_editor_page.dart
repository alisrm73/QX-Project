import 'package:flutter/material.dart';

import '../models/qx_project.dart';
import '../services/workspace_store.dart';

class FileEditorPage extends StatefulWidget {
  const FileEditorPage({
    super.key,
    required this.project,
    required this.store,
    required this.fileName,
    required this.initialContent,
  });

  final QxProject project;
  final WorkspaceStore store;
  final String fileName;
  final String initialContent;

  @override
  State<FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends State<FileEditorPage> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.store.writeTextFile(
        widget.project,
        fileName: widget.fileName,
        content: _controller.text,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الملف محلياً / File saved on this device'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر حفظ الملف / Could not save the file'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          actions: [
            TextButton.icon(
              onPressed: _isSaving || !_isDirty ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('حفظ / Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF111722),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _controller,
              expands: true,
              minLines: null,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.55,
                color: Color(0xFFE2E5F0),
              ),
              decoration: const InputDecoration(
                hintText: 'اكتب الكود أو محتوى الملف هنا / Edit file content here',
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
              onChanged: (_) {
                if (!_isDirty) setState(() => _isDirty = true);
              },
            ),
          ),
        ),
      );
}
