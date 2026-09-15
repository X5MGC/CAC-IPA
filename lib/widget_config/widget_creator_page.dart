import 'package:flutter/material.dart';
import 'widget_data.dart';

/// 新建小组件页
class WidgetCreatorPage extends StatefulWidget {
  const WidgetCreatorPage({super.key});

  @override
  State<WidgetCreatorPage> createState() => _WidgetCreatorPageState();
}

class _WidgetCreatorPageState extends State<WidgetCreatorPage> {
  String _size = '1x1';
  bool _customSize = false;
  int _customCols = 4;
  int _customRows = 2;
  List<String> _buttons = [];
  Map<String, Offset> _positions = {};
  int _nextPosIndex = 0;

  String get _effectiveSize =>
      _customSize ? WidgetData.formatSize(_customCols, _customRows) : _size;

  int get _capacity {
    final p = WidgetData.parseSize(_effectiveSize);
    return p[0] * p[1];
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  int _blankCounter = 0;

  /// 添加按钮时自动分配初始位置
  void _onButtonAdded(String id) {
    if (_buttons.length >= _capacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('当前尺寸最多 $_capacity 项，请改大尺寸或先移除')),
      );
      return;
    }
    setState(() {
      final actualId = id == 'info_blank' ? 'info_blank_${_blankCounter++}' : id;
      _buttons.add(actualId);
      final idx = _nextPosIndex++;
      final parts = WidgetData.parseSize(_effectiveSize);
      final cols = parts[0];
      final rows = parts[1];
      final col = idx % cols;
      final row = idx ~/ cols;
      _positions[actualId] = Offset(
        (col + 0.5) / cols,
        (row + 0.5) / rows,
      );
    });
  }

  void _onButtonRemoved(String id) {
    setState(() {
      _buttons.remove(id);
      _positions.remove(id);
    });
  }

  Future<void> _create() async {
    if (_buttons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个内容')),
      );
      return;
    }
    final slot = await WidgetData.createWidget(
      title: '小组件',
      size: _effectiveSize,
      buttons: _buttons,
      positions: _positions,
    );
    if (mounted) {
      if (slot > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('小组件 #$slot 已添加到桌面')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('小组件数量已满（最多20个）')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('新建小组件', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 尺寸选择（横向滑动 + 自定义）
            const Text('选择尺寸', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: WidgetData.sizes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final size = WidgetData.sizes[index];
                  final isCustom = size == 'custom';
                  final selected = isCustom ? _customSize : (!_customSize && _size == size);
                  return ChoiceChip(
                    label: Text(isCustom
                        ? '自定义${_customSize ? ' ${_customCols}x$_customRows' : ''}'
                        : size),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      if (isCustom) {
                        _customSize = true;
                      } else {
                        _customSize = false;
                        _size = size;
                      }
                      _rearrangePositions();
                    }),
                    selectedColor: const Color(0xFF007AFF),
                    backgroundColor: const Color(0xFF2B3136),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                    ),
                  );
                },
              ),
            ),
            if (_customSize) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('宽', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _customCols.toDouble(),
                      min: 1,
                      max: WidgetData.maxCustomCols.toDouble(),
                      divisions: WidgetData.maxCustomCols - 1,
                      label: '$_customCols',
                      onChanged: (v) => setState(() {
                        _customCols = v.round();
                        _rearrangePositions();
                      }),
                    ),
                  ),
                  Text('$_customCols',
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(width: 12),
                  const Text('高', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _customRows.toDouble(),
                      min: 1,
                      max: WidgetData.maxCustomRows.toDouble(),
                      divisions: WidgetData.maxCustomRows - 1,
                      label: '$_customRows',
                      onChanged: (v) => setState(() {
                        _customRows = v.round();
                        _rearrangePositions();
                      }),
                    ),
                  ),
                  Text('$_customRows',
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              Text('最多 ${_customCols}x$_customRows = ${_customCols * _customRows} 项',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
            const SizedBox(height: 20),

            // 控制类
            const Text('控制类', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            _buildChipGrid(WidgetData.controlButtons),
            const SizedBox(height: 16),

            // 信息类
            const Text('信息类', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            _buildChipGrid(WidgetData.infoButtons),
            const SizedBox(height: 16),

            // 已选内容排序
            const Text('已选内容（上下拖动调整顺序）',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            _buildSelectedList(),
            const SizedBox(height: 16),

            // 网格预览（按顺序）
            const Text('预览（按选择顺序）', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            _buildPreview(),
            const SizedBox(height: 16),

            // 创建按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('添加到桌面',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 尺寸变化时重新排列已有按钮
  void _rearrangePositions() {
    final parts = WidgetData.parseSize(_effectiveSize);
    final cols = parts[0];
    final rows = parts[1];
    int idx = 0;
    for (final id in _buttons) {
      final col = idx % cols;
      final row = idx ~/ cols;
      _positions[id] = Offset(
        (col + 0.5) / cols,
        (row + 0.5) / rows,
      );
      idx++;
    }
  }

  Widget _buildChipGrid(List<WidgetButtonDef> items) {
    final isControl = items.isNotEmpty && items.first.icon != null;
    if (isControl) {
      // 控制类：圆形图标按钮，与APP风格一致
      return SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final btn = items[index];
            final selected = btn.id != 'info_blank' && _buttons.any((b) => b == btn.id || b.startsWith('${btn.id}_'));
            return GestureDetector(
              onTap: () {
                if (btn.id == 'info_blank') {
                  _onButtonAdded(btn.id);
                } else if (selected) {
                  _onButtonRemoved(_buttons.firstWhere((b) => b == btn.id || b.startsWith('${btn.id}_')));
                } else {
                  _onButtonAdded(btn.id);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF007AFF).withValues(alpha: 0.7)
                          : const Color(0xFF2B3136),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? const Color(0xFF007AFF) : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Image.asset(
                        btn.icon!,
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    btn.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white60,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    // 信息类：FilterChip文字标签
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final btn = items[index];
          final selected = _buttons.contains(btn.id);
          return FilterChip(
            label: Text(btn.label),
            selected: selected,
            onSelected: (v) {
              if (v) {
                _onButtonAdded(btn.id);
              } else {
                _onButtonRemoved(btn.id);
              }
            },
            selectedColor: const Color(0xFF007AFF),
            backgroundColor: const Color(0xFF2B3136),
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 13,
            ),
          );
        },
      ),
    );
  }

  /// 已选内容列表：拖动排序
  Widget _buildSelectedList() {
    if (_buttons.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2B3136),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '尚未选择内容',
          style: TextStyle(color: Colors.white38),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: _buttons.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final id = _buttons.removeAt(oldIndex);
          _buttons.insert(newIndex, id);
          _rearrangePositions();
        });
      },
      itemBuilder: (context, index) {
        final id = _buttons[index];
        final btn = WidgetData.findButton(id);
        final isCtrl = btn?.icon != null;
        return ListTile(
          key: ValueKey('${id}_$index'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          tileColor: const Color(0xFF2B3136),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: isCtrl
              ? Image.asset(btn!.icon!, width: 24, height: 24)
              : const Icon(Icons.info_outline, color: Colors.white70, size: 20),
          title: Text(
            btn?.label ?? id,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: Colors.white38),
          ),
        );
      },
    );
  }

  /// 网格预览：按顺序填格，不支持自由拖
  Widget _buildPreview() {
    final parts = WidgetData.parseSize(_effectiveSize);
    final cols = parts[0];
    final rows = parts[1];
    const cell = 56.0;
    final capacity = cols * rows;
    final show = _buttons.take(capacity).toList();

    return Center(
      child: Container(
        width: cols * cell,
        height: rows * cell,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF28293D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
          ),
          itemCount: capacity,
          itemBuilder: (context, i) {
            if (i >= show.length) {
              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }
            final btn = WidgetData.findButton(show[i]);
            final isCtrl = btn?.icon != null;
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF2B3136),
                borderRadius: BorderRadius.circular(isCtrl ? 100 : 6),
              ),
              child: Center(
                child: isCtrl
                    ? Image.asset(btn!.icon!, width: 22, height: 22)
                    : Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text(
                          btn?.label ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
