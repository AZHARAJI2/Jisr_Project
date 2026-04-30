import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../network/network.dart';
import 'success_screen.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({Key? key}) : super(key: key);

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to = _recipientController.text.trim();
    final amt = double.tryParse(_amountController.text);
    if (to.isEmpty || amt == null || amt <= 0) return;

    setState(() => _isSending = true);
    final mesh = MeshManager.instance;
    final txn = await mesh.createAndSendTransaction(receiverId: to, amount: amt);
    setState(() => _isSending = false);

    if (!mounted) return;
    if (txn != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SuccessScreen(
          title: 'إرسال حوالة',
          statusText: 'تم الإرسال بنجاح!',
          amount: '${amt.toStringAsFixed(0)} ريال',
          recipient: to,
        )),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ رصيد غير كافٍ'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('إرسال حوالة'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('المستلم:'),
                      _buildInput('معرّف المستلم (user_...)', Icons.person, controller: _recipientController),
                      const SizedBox(height: 25),
                      _buildLabel('المبلغ:'),
                      _buildInput('المبلغ بالريال', Icons.attach_money, keyboardType: TextInputType.number, controller: _amountController),
                      const SizedBox(height: 30),
                      _buildOptimalPath(),
                      
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: _isSending ? null : _send,
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryEmerald.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isSending
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text(
                                    'إرسال الآن',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
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
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInput(String hint, IconData icon, {TextInputType keyboardType = TextInputType.text, TextEditingController? controller}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppTheme.primaryBlue, size: 20),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildModeItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildOptimalPath() {
    final peers = MeshManager.instance.connectedCount;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route, color: AppTheme.primaryBlue, size: 18),
              SizedBox(width: 8),
              Text('أفضل مسار متاح:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            peers > 0 ? 'أنت → شبكة Mesh → المستلم' : 'لا توجد أجهزة متصلة حالياً',
            style: TextStyle(
              color: peers > 0 ? AppTheme.primaryEmerald : Colors.orange,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$peers أجهزة متصلة',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
