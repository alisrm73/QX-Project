import '../models/qx_project.dart';
import 'workspace_store.dart';

class QxToolContext {
  const QxToolContext({
    required this.project,
    required this.workspaceStore,
  });

  final QxProject project;
  final WorkspaceStore workspaceStore;
}

class QxToolResult {
  const QxToolResult({
    required this.toolId,
    required this.success,
    required this.messageAr,
    required this.messageEn,
  });

  final String toolId;
  final bool success;
  final String messageAr;
  final String messageEn;
}

/// A registered QX tool. Implementations must declare their own bounded behavior.
abstract interface class QxTool {
  String get id;
  String get nameAr;
  String get nameEn;
  String get descriptionAr;
  Future<QxToolResult> run(QxToolContext context);
}

class QxToolRegistry {
  QxToolRegistry(Iterable<QxTool> tools) {
    for (final tool in tools) {
      if (tool.id.trim().isEmpty) {
        throw ArgumentError.value(tool.id, 'tool.id', 'Tool id cannot be empty.');
      }
      if (_tools.containsKey(tool.id)) {
        throw ArgumentError.value(tool.id, 'tool.id', 'Duplicate tool id.');
      }
      _tools[tool.id] = tool;
    }
  }

  final Map<String, QxTool> _tools = {};

  List<QxTool> get tools => List.unmodifiable(_tools.values);

  QxTool? toolById(String id) => _tools[id];

  Future<QxToolResult> run(String id, QxToolContext context) async {
    final tool = _tools[id];
    if (tool == null) {
      throw ArgumentError.value(id, 'id', 'Tool is not registered.');
    }
    return tool.run(context);
  }

  factory QxToolRegistry.standard() => QxToolRegistry([
        const WorkspaceAnalysisTool(),
      ]);
}

/// First built-in tool: read-only analysis of the selected local workspace.
class WorkspaceAnalysisTool implements QxTool {
  const WorkspaceAnalysisTool();

  @override
  String get id => 'workspace-analysis';

  @override
  String get nameAr => 'تحليل مساحة العمل';

  @override
  String get nameEn => 'Workspace analysis';

  @override
  String get descriptionAr => 'يفحص الملفات والمجلدات والامتدادات دون تعديلها.';

  @override
  Future<QxToolResult> run(QxToolContext context) async {
    final report = await context.workspaceStore.analyzeWorkspace(context.project);
    final extensionSummary = report.extensionCounts.isEmpty
        ? 'لا توجد امتدادات بعد'
        : report.extensionCounts.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('، ');
    return QxToolResult(
      toolId: id,
      success: true,
      messageAr: 'اكتمل التحليل: ${report.fileCount} ملف، '
          '${report.directoryCount} مجلد، ${report.totalBytes} بايت. '
          'الامتدادات: $extensionSummary.',
      messageEn: 'Analysis complete: ${report.fileCount} files, '
          '${report.directoryCount} folders, ${report.totalBytes} bytes. '
          'Extensions: ${report.extensionCounts.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ')}.',
    );
  }
}
