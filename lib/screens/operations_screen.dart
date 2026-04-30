import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../network/network.dart';
import 'dart:async';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({Key? key}) : super(key: key);

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mesh = MeshManager.instance;
    final pending = mesh.pendingTransactions;
    final completed = mesh.completedTransactions;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('جميع العمليات'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (pending.isNotEmpty) ...[
                _buildSectionTitle('العمليات المعلّقة'),
                ...pending.map((txn) {
                  final isIn = txn.receiverId == mesh.userId;
                  return _buildItem(
                    isIn ? 'استقبال حوالة' : 'إرسال حوالة',
                    'قيد التنفيذ',
                    '${isIn ? "+" : "-"} ${txn.amount.toStringAsFixed(0)} ريال',
                    isIn ? AppTheme.primaryEmerald : Colors.orange,
                  );
                }),
              ],
              _buildSectionTitle('العمليات المكتملة'),
              if (completed.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('لا توجد عمليات مكتملة بعد', style: TextStyle(color: Colors.white38)),
                )
              else
                ...completed.map((txn) {
                  final isIn = txn.receiverId == mesh.userId;
                  return _buildItem(
                    isIn ? 'استقبال' : 'إرسال',
                    isIn ? 'تم استلام الحوالة ✅' : 'تم إرسال الحوالة ✅',
                    '${isIn ? "+" : "-"} ${txn.amount.toStringAsFixed(0)} ريال',
                    isIn ? AppTheme.primaryEmerald : Colors.white70,
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: AppTheme.primaryBlue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildItem(String title, String status, String amount, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: GlassCard(
        opacity: 0.05,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(
                  title.contains('إرسال') ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color, size: 20,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(status, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
