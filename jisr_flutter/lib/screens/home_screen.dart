import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'send_screen.dart';
import 'receive_screen.dart';
import 'network_screen.dart';
import 'operations_screen.dart';
import '../widgets/jisr_logo.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/world_map_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomNav(),
      body: _selectedIndex == 1 
          ? const NetworkScreen() 
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D1226), AppTheme.background],
                ),
              ),
              child: SafeArea(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(context),
                            const SizedBox(height: 20),
                            const Center(child: JisrLogo(size: 60)),
                            const SizedBox(height: 10),
                            _buildBalanceCard(),
                            const SizedBox(height: 30),
                            _buildActionButtons(),
                            const SizedBox(height: 40),
                            _buildMeshMapSection(),
                            const SizedBox(height: 40),
                            _buildRecentActivity(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final userName = context.watch<UserProvider>().userName;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=alex'),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('متصل', style: TextStyle(color: AppTheme.primaryEmerald, fontSize: 12)),
                    const SizedBox(width: 5),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppTheme.primaryEmerald, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(Icons.bolt, color: AppTheme.primaryEmerald, size: 16),
              SizedBox(width: 4),
              Text('14ms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Hero(
      tag: 'balanceCard',
      child: GlassCard(
        borderColor: AppTheme.primaryEmerald.withOpacity(0.3),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الرصيد الرقمي الرئيسي',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                '\$ 84,210.65',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Text('USD', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Icon(Icons.trending_up, color: AppTheme.primaryEmerald, size: 18),
                  const SizedBox(width: 5),
                  const Text('+12.4% (24h)', style: TextStyle(color: AppTheme.primaryEmerald, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionItem('إرسال', FontAwesomeIcons.arrowUp, AppTheme.primaryBlue, 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SendScreen()))),
        _buildActionItem('استقبال', FontAwesomeIcons.arrowDown, AppTheme.primaryEmerald, 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReceiveScreen()))),
        _buildActionItem('العمليات', FontAwesomeIcons.listCheck, Colors.white, 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OperationsScreen()))),
      ],
    );
  }

  Widget _buildActionItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          GlassCard(
            opacity: 0.08,
            borderRadius: 15,
            child: Container(
              width: 60,
              height: 60,
              child: Icon(icon, color: color, size: 22),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildMeshMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'خريطة الشبكة (Mesh Network Map)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white60),
        ),
        const SizedBox(height: 15),
        GlassCard(
          child: Container(
            height: 220,
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            child: CustomPaint(
              size: Size.infinite,
              painter: WorldMapPainter(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final transactions = [
      {'name': 'ج. تشن', 'amount': '+\$340.50', 'time': 'منذ 3 دقائق', 'type': 'in'},
      {'name': 'Node Server', 'amount': '-\$1,120.00', 'time': 'منذ 12 دقيقة', 'type': 'out'},
      {'name': 'و. سميث', 'amount': '+\$5,000.00', 'time': 'منذ 45 دقيقة', 'type': 'in'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('النشاط الأخير', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white60)),
        const SizedBox(height: 15),
        ...transactions.map((tx) => _buildTransactionItem(tx)).toList(),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, String> tx) {
    bool isIncoming = tx['type'] == 'in';
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isIncoming ? AppTheme.primaryEmerald : AppTheme.primaryBlue).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncoming ? AppTheme.primaryEmerald : AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(tx['time']!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Text(
            tx['amount']!,
            style: TextStyle(
              color: isIncoming ? AppTheme.primaryEmerald : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.8),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_filled, 'الرئيسية'),
            _buildNavItem(1, Icons.language, 'الشبكة'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.primaryEmerald : Colors.white54,
            shadows: isSelected ? [const Shadow(color: AppTheme.primaryEmerald, blurRadius: 10)] : null,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryEmerald : Colors.white54,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AppTheme.primaryEmerald.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintNode = Paint()
      ..color = AppTheme.primaryEmerald
      ..style = PaintingStyle.fill;

    // Draw some nodes and lines
    final p1 = Offset(size.width * 0.2, size.height * 0.3);
    final p2 = Offset(size.width * 0.7, size.height * 0.2);
    final p3 = Offset(size.width * 0.4, size.height * 0.7);
    final p4 = Offset(size.width * 0.8, size.height * 0.6);

    canvas.drawLine(p1, p2, paintLine);
    canvas.drawLine(p2, p4, paintLine);
    canvas.drawLine(p1, p3, paintLine);
    canvas.drawLine(p3, p4, paintLine);

    canvas.drawCircle(p1, 3, paintNode);
    canvas.drawCircle(p2, 3, paintNode);
    canvas.drawCircle(p3, 3, paintNode);
    canvas.drawCircle(p4, 3, paintNode);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
