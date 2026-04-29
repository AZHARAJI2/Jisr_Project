import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class OperationsScreen extends StatelessWidget {
  const OperationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('جميع العمليات', style: TextStyle(fontFamily: 'Tajawal')),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSectionTitle('العمليات المعلقة'),
              _buildOperationItem('استقبال حوالة', 'قيد التنفيذ', '+ 5,000 ريال', AppTheme.primaryEmerald),
              const SizedBox(height: 30),
              _buildSectionTitle('العمليات المكتملة'),
              _buildOperationItem('إرسال حوالة', 'مكتملة', '- 1,200 ريال', Colors.white70),
              _buildOperationItem('استقبال حوالة', 'مكتملة', '+ 450 ريال', AppTheme.primaryEmerald),
              _buildOperationItem('إرسال حوالة', 'مكتملة', '- 3,000 ريال', Colors.white70),
              _buildOperationItem('استقبال حوالة', 'مكتملة', '+ 10,000 ريال', AppTheme.primaryEmerald),
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

  Widget _buildOperationItem(String title, String status, String amount, Color amountColor) {
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
                decoration: BoxDecoration(color: amountColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(title.contains('إرسال') ? Icons.arrow_upward : Icons.arrow_downward, color: amountColor, size: 20),
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
              Text(amount, style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
