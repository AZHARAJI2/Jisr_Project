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
import '../network/network.dart';
import 'dart:async';

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

  // ── بيانات الشبكة الحقيقية ──
  final MeshManager _mesh = MeshManager.instance;
  int _connectedPeers = 0;
  double _balance = 0;
  StreamSubscription<int>? _peersSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));
    _entranceController.forward();

    // استمع لعدد الأجهزة المتصلة
    _peersSub = _mesh.peersStream.listen((count) {
      if (mounted) setState(() => _connectedPeers = count);
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _balance = _mesh.getBalance();
          _connectedPeers = _mesh.connectedCount;
        });
      }
    });
    _balance = _mesh.getBalance();
    _connectedPeers = _mesh.connectedCount;
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _peersSub?.cancel();
    _refreshTimer?.cancel();
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
                            const Center(child: JisrLogo(size: 50)),
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
            // أيقونة بدل الصورة
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 28),
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
                    Text(
                      _connectedPeers > 0 ? 'متصل' : 'يبحث...',
                      style: TextStyle(
                        color: _connectedPeers > 0 ? AppTheme.primaryEmerald : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _connectedPeers > 0 ? AppTheme.primaryEmerald : Colors.orange,
                        shape: BoxShape.circle,
                      ),
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
          child: Row(
            children: [
              Icon(Icons.devices, color: AppTheme.primaryEmerald, size: 16),
              const SizedBox(width: 4),
              Text('$_connectedPeers جهاز', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                'الرصيد الحالي',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Text(
                '${_balance.toStringAsFixed(0)} ريال',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Text('SAR', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(
                    _connectedPeers > 0 ? Icons.wifi : Icons.wifi_find,
                    color: _connectedPeers > 0 ? AppTheme.primaryEmerald : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _connectedPeers > 0 ? '$_connectedPeers أجهزة متصلة' : 'جاري البحث...',
                    style: TextStyle(
                      color: _connectedPeers > 0 ? AppTheme.primaryEmerald : Colors.orange,
                      fontSize: 14,
                    ),
                  ),
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
            child: SizedBox(
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
    final peers = _mesh.connectedDevices;
    final bestPeer = _mesh.peerTelemetry.isEmpty ? null : _mesh.peerTelemetry.first.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الخريطة العامة للشبكة',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white60),
        ),
        const SizedBox(height: 4),
        Text(
          'تعرض الأجهزة القريبة بشكل عام. التفاصيل داخل تبويب "الشبكة".',
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 15),
        GlassCard(
          child: Container(
            height: 220,
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            child: CustomPaint(
              size: Size.infinite,
              painter: WorldMapPainter(
                peers: peers,
                bestPeer: bestPeer,
              ),
            ),
          ),
        ),
        if (peers.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'قريبون الآن: ${peers.join(' • ')}',
            style: const TextStyle(color: AppTheme.primaryEmerald, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildRecentActivity() {
    final completed = _mesh.completedTransactions;
    final pending = _mesh.pendingTransactions;
    final allTxns = [...completed, ...pending];
    allTxns.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'النشاط الأخير',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white60),
        ),
        const SizedBox(height: 15),
        if (allTxns.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('لا توجد حوالات بعد', style: TextStyle(color: Colors.white38, fontSize: 14)),
            ),
          )
        else
          ...allTxns.take(5).map((txn) {
            final isIn = txn.receiverId == _mesh.userId;
            return _buildTransactionItem({
              'name': isIn ? 'من: ${txn.senderId}' : 'إلى: ${txn.receiverId}',
              'amount': '${isIn ? "+" : "-"}${txn.amount.toStringAsFixed(0)} ريال',
              'time': _timeAgo(txn.timestamp),
              'type': isIn ? 'in' : 'out',
            });
          }).toList(),
      ],
    );
  }

  String _timeAgo(int timestamp) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
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
