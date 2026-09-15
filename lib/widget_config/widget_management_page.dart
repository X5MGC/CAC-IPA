import 'package:flutter/material.dart';
import 'widget_data.dart';
import 'widget_editor_page.dart';

/// 小组件管理页 — 实时显示已创建的小组件slot
class WidgetManagementPage extends StatefulWidget {
  const WidgetManagementPage({super.key});

  @override
  State<WidgetManagementPage> createState() => _WidgetManagementPageState();
}

class _WidgetManagementPageState extends State<WidgetManagementPage> with WidgetsBindingObserver {
  List<SlotConfig> _widgets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final list = await WidgetData.getActiveWidgets();
    if (mounted) setState(() { _widgets = list; _loading = false; });
  }

  Future<void> _edit(SlotConfig w) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WidgetEditorPage(slot: w.slot, initialTitle: w.title, initialSize: w.size, initialButtons: w.buttons, initialPositions: w.positions),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete(SlotConfig w) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B3136),
        title: const Text('删除小组件', style: TextStyle(color: Colors.white)),
        content: const Text('桌面上的小组件也会被移除，确定？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await WidgetData.deleteSlot(w.slot);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('小组件已删除')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('小组件管理', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _widgets.isEmpty
              ? const Center(
                  child: Text('还没有小组件\n\n点击 "新建小组件" 创建',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 15)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _widgets.length,
                  itemBuilder: (context, index) {
                    final w = _widgets[index];
                    return Card(
                      color: const Color(0xFF2B3136),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(w.title,
                            style: const TextStyle(color: Colors.white, fontSize: 16)),
                        subtitle: Text(
                          '${w.size}  |  ${w.buttons.map((b) => _buttonLabel(b)).join(", ")}',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color(0xFF007AFF)),
                              onPressed: () => _edit(w),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _delete(w),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _buttonLabel(String id) {
    return WidgetData.findButton(id)?.label ?? id;
  }
}
