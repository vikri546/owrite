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

        // Match the tiny rounded switch style in the image
        final double trackWidth = 48;
        final double trackHeight = 22;
        final double thumbSize = 28;
        final double iconSize = 18;

        // Change animation duration to slower (e.g. 520ms)
        const Duration slowAnimation = Duration(milliseconds: 520);

        return GestureDetector(
          onTap: themeProvider.toggleTheme,
          child: SizedBox(
            width: trackWidth,
            height: trackHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Track
                AnimatedContainer(
                  duration: slowAnimation,
                  width: trackWidth,
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    borderRadius: BorderRadius.circular(trackHeight / 2),
                  ),
                ),
                // Thumb with icon and animated fade for icon
                AnimatedAlign(
                  duration: slowAnimation,
                  curve: Curves.easeInOut,
                  alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 340),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: SvgPicture.string(
                          isDark ? _darkSvg : _lightSvg,
                          width: iconSize,
                          height: iconSize,
                          colorFilter: ColorFilter.mode(Colors.black, BlendMode.srcIn),
                          key: ValueKey<bool>(isDark),
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
