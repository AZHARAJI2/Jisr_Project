import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

import 'success_screen.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('استقبال تحويل', style: TextStyle(fontFamily: 'Tajawal')),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sensors, color: AppTheme.primaryEmerald, size: 80),
                const SizedBox(height: 20),
                const Text(
                  'في انتظار اتصال قريب...',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                  'تأكد من تفعيل WiFi و Bluetooth للبحث عن العقد القريبة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 50),
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('معرفك الفريد:', style: TextStyle(color: Colors.white70)),
                            Text('JISR-8842-ALEX', style: TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('وضع الاكتشاف:', style: TextStyle(color: Colors.white70)),
                            Text('نشط (عبر Mesh)', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SuccessScreen(
                                  title: 'استقبال تحويل',
                                  statusText: 'تم الاستقبال بنجاح!',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('محاكاة الاستقبال (معاينة)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryEmerald.withOpacity(0.2),
                            foregroundColor: AppTheme.primaryEmerald,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
