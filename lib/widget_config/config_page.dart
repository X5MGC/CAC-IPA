import 'package:flutter/material.dart';
import 'widget_management_page.dart';
import 'widget_creator_page.dart';

/// 小组件定制入口页
class WidgetConfigPage extends StatelessWidget {
  const WidgetConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('小组件定制', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCard(
              context,
              icon: Icons.add_circle_outline,
              title: '新建小组件',
              subtitle: '选择尺寸、配置内容，一键添加到桌面',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WidgetCreatorPage()),
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              context,
              icon: Icons.dashboard_customize,
              title: '管理小组件',
              subtitle: '查看、编辑、删除已添加到桌面的小组件',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WidgetManagementPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2B3136),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF007AFF), size: 36),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
