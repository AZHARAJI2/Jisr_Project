import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../network/network.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mesh = MeshManager.instance;
    final userId = mesh.userId;
    final peers = mesh.connectedCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('استقبال حوالة'),
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
                Text(
                  peers > 0 ? 'جاهز للاستقبال!' : 'في انتظار اتصال قريب...',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                  'تأكد من تفعيل WiFi و Bluetooth للبحث عن الأجهزة القريبة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 50),
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('معرّفك الفريد:', style: TextStyle(color: Colors.white70)),
                            Text(userId, style: const TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('وضع الاكتشاف:', style: TextStyle(color: Colors.white70)),
                            Text(
                              peers > 0 ? 'متصل ($peers أجهزة)' : 'نشط (عبر Mesh)',
                              style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الرصيد الحالي:', style: TextStyle(color: Colors.white70)),
                            Text(
                              '${mesh.getBalance().toStringAsFixed(0)} ريال',
                              style: const TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'شارك معرّفك مع المرسل ليتمكن من إرسال الحوالة إليك',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
