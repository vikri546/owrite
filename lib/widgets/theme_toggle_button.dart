import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({Key? key}) : super(key: key);

  static const String _lightSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="200" height="200"><g fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path stroke-linecap="round" d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></g></svg>
''';

  static const String _darkSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="200" height="200"><path fill="currentColor" d="M21 12.79A9 9 0 0 1 11.21 3a1 1 0 0 0-1.08-1.29A10 10 0 1 0 22.29 14.29a1 1 0 0 0-1.29-1.5Z"/></svg>
''';

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final bool isDark = themeProvider.isDarkMode;

        // DIMENSI BARU:
        // Track (belakang) dibuat lebih panjang dan kurus.
        // Thumb (lingkaran) dibuat lebih besar dari track height.
        final double trackWidth = 54; 
        final double trackHeight = 16; // Ukuran track dibuat "kurus"
        final double thumbSize = 30;   // Ukuran lingkaran "lebih besar"
        final double iconSize = 18;

        const Duration slowAnimation = Duration(milliseconds: 500);

        return GestureDetector(
          onTap: themeProvider.toggleTheme,
          child: SizedBox(
            width: trackWidth,
            height: thumbSize, // Tinggi container mengikuti lingkaran terbesar
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Track (Background Shape)
                AnimatedContainer(
                  duration: slowAnimation,
                  width: trackWidth,
                  height: trackHeight,
                  decoration: BoxDecoration(
                    // Warna Track: Abu gelap saat dark mode, abu terang saat light mode
                    color: isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(trackHeight / 2),
                  ),
                ),
                
                // Thumb (Lingkaran dengan Icon)
                AnimatedAlign(
                  duration: slowAnimation,
                  curve: Curves.easeInOut, // UBAH KE INI (Slide biasa, tidak membal)
                  alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      // Warna Lingkaran: Kuning saat Dark Mode, Putih saat Light Mode (sesuai gambar)
                      color: isDark ? const Color(0xFFE5FF10) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          // UBAH KE INI (Hapus RotationTransition, cukup Fade saja biar simpel)
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: SvgPicture.string(
                          isDark ? _darkSvg : _lightSvg,
                          // Key penting agar AnimatedSwitcher mendeteksi perubahan widget
                          key: ValueKey<bool>(isDark),
                          width: iconSize,
                          height: iconSize,
                          // Warna Icon tetap hitam di kedua mode sesuai gambar
                          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}