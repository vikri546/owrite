import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Full-page Contact Screen untuk menampilkan informasi kontak
class ContactScreen extends StatelessWidget {
  const ContactScreen({Key? key}) : super(key: key);

  static const Color _accentColor = Color(0xFFCCFF00);

  // Contact information - edit sesuai kebutuhan
  static const String _email = 'info@owrite.id';
  static const String _phone = '+62 812 3456 7890';
  static const String _whatsapp = '+62 812 3456 7890';
  static const String _website = 'https://owrite.id';
  static const String _address =
      'Jl. Sultan Iskandar Muda No. 5, RT.9/RW.1, Kebayoran Lama Utara, Jakarta Selatan, 12230';

  // Koordinat lokasi - Jl. Sultan Iskandar Muda, Kebayoran Lama
  static const double _latitude = -6.238060361170324;
  static const double _longitude = 106.78359364643468;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    final uri = Uri(scheme: 'mailto', path: _email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: _phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp() async {
    final whatsappUrl =
        'https://wa.me/${_whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}';
    await _launchUrl(whatsappUrl);
  }

  Future<void> _openMaps() async {
    // Buka Google Maps dengan koordinat
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude';
    await _launchUrl(googleMapsUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'OWRITE MEDIA',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title - Tentang Owrite
              Text(
                'Tentang OWRITE',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),

              // Description paragraphs
              Text(
                'Di dunia yang penuh kebisingan, kejernihan adalah kemewahan. Dan kami hadir untuk memberikannya.',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Selamat datang di OWRITE Media. Kami bukan sekadar media baru. Kami adalah standar baru. Lahir pada Oktober 2025, kami ada untuk satu alasan: mendefinisikan ulang apa arti jurnalisme berkualitas di era digital.',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kami di sini untuk mengurai kompleksitas, bukan menambah keriuhan. Kami percaya Anda pantas mendapatkan lebih dari sekadar clickbait atau berita basi.',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Gaya kami? Kami berbicara dengan bahasa Anda, mengikuti denyut tren terkini. Tapi kami tidak pernah bermain-main dengan fakta.',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bagi kami, etika dan kaidah jurnalistik adalah harga mati. Kami menyajikan apa yang relevan, tanpa pernah mengorbankan kebenaran.',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kami di sini untuk memberi konteks pada dunia yang bergerak cepat. Kami OWRITE.',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 28),

              // Section title - Primary Contact
              Text(
                'Kontak Utama',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),

              // Email Card - Premium Design
              Builder(
                builder: (context) {
                  // Use black in light mode, accent color in dark mode
                  final emailAccentColor = isDark ? _accentColor : Colors.black;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _launchEmail,
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: emailAccentColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Icon Container with gradient background
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    emailAccentColor.withOpacity(0.15),
                                    emailAccentColor.withOpacity(0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: emailAccentColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.email_rounded,
                                color: emailAccentColor,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 18),
                            // Text content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email',
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Inter',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _email,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Arrow icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: emailAccentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: emailAccentColor,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Section title - Address with Map
              Text(
                'Alamat',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),

              // Interactive Map Panel with Address
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Interactive Map Panel
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(5),
                        topRight: Radius.circular(5),
                      ),
                      child: SizedBox(
                        height: 300,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            // FlutterMap - Interactive OpenStreetMap
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(_latitude, _longitude),
                                initialZoom: 15.0,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all &
                                      ~InteractiveFlag.rotate,
                                ),
                              ),
                              children: [
                                // OpenStreetMap Tiles (free, no API key)
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.medias.owrite',
                                ),
                                // Location Marker
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(_latitude, _longitude),
                                      width: 180,
                                      height: 60,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(width: 20),
                                          // Label "OWRITE MEDIA"
                                          Stack(
                                            children: [
                                              // Outline putih
                                              Text(
                                                'OWRITE MEDIA',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Inter',
                                                  letterSpacing: 0.5,
                                                  foreground: Paint()
                                                    ..style =
                                                        PaintingStyle.stroke
                                                    ..strokeWidth = 2
                                                    ..color = Colors.white,
                                                ),
                                              ),
                                              // Isi teks hitam
                                              Text(
                                                'OWRITE MEDIA',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Inter',
                                                  letterSpacing: 0.5,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Overlay button to open in external Maps
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _openMaps,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.open_in_new,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Buka di Google Maps',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Address below map
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kantor Pusat',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _address,
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Copyright
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    '© ${DateTime.now().year} OWRITE. All Rights Reserved.',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (iconColor ?? _accentColor).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? _accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: subtitleColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the triangle/arrow pointing down on the marker
class _TrianglePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;

  _TrianglePainter({
    required this.color,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    // Draw border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Draw fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
