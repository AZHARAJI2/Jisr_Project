import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SuccessScreen extends StatelessWidget {
  final String title;
  final String statusText;
  final String amount;
  final String recipient;

  const SuccessScreen({
    Key? key,
    this.title = 'إرسال حوالة',
    this.statusText = 'تمت العملية بنجاح!',
    this.amount = '',
    this.recipient = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: AppTheme.background),
        child: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryEmerald.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_outline, color: AppTheme.primaryEmerald, size: 50),
                  ),
                  const SizedBox(height: 20),
                  Text(statusText, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald)),
                  const SizedBox(height: 40),
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        children: [
                          if (amount.isNotEmpty) _buildRow(context, 'المبلغ:', amount, isHighlight: true),
                          if (recipient.isNotEmpty) ...[
                            const Divider(color: Colors.white10, height: 30),
                            _buildRow(context, 'إلى:', recipient),
                          ],
                          const Divider(color: Colors.white10, height: 30),
                          _buildRow(context, 'الطريقة:', 'شبكة Mesh', color: AppTheme.primaryBlue),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('العودة للرئيسية', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value, {bool isHighlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: TextStyle(
            color: color ?? (isHighlight ? AppTheme.primaryEmerald : Colors.white),
            fontWeight: FontWeight.bold, fontSize: isHighlight ? 18 : 14,
          )),
        ],
      ),
    );
  }
}
