import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

// --- MOCK DATA & ASSETS (TIDAK BERUBAH) ---
class SvgAssets {
  static const String instagram = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M12 0C8.74 0 8.333.015 7.053.072C5.775.132 4.905.333 4.14.63c-.789.306-1.459.717-2.126 1.384S.935 3.35.63 4.14C.333 4.905.131 5.775.072 7.053C.012 8.333 0 8.74 0 12s.015 3.667.072 4.947c.06 1.277.261 2.148.558 2.913a5.885 5.885 0 0 0 1.384 2.126A5.868 5.868 0 0 0 4.14 23.37c.766.296 1.636.499 2.913.558C8.333 23.988 8.74 24 12 24s3.667-.015 4.947-.072c1.277-.06 2.148-.262 2.913-.558a5.898 5.898 0 0 0 2.126-1.384a5.86 5.86 0 0 0 1.384-2.126c.296-.765.499-1.636.558-2.913c.06-1.28.072-1.687.072-4.947s-.015-3.667-.072-4.947c-.06-1.277-.262-2.149-.558-2.913a5.89 5.89 0 0 0-1.384-2.126A5.847 5.847 0 0 0 19.86.63c-.765-.297-1.636-.499-2.913-.558C15.667.012 15.26 0 12 0zm0 2.16c3.203 0 3.585.016 4.85.071c1.17.055 1.805.249 2.227.415c.562.217.96.477 1.382.896c.419.42.679.819.896 1.381c.164.422.36 1.057.413 2.227c.057 1.266.07 1.646.07 4.85s-.015 3.585-.074 4.85c-.061 1.17-.256 1.805-.421 2.227a3.81 3.81 0 0 1-.899 1.382a3.744 3.744 0 0 1-1.38.896c-.42.164-1.065.36-2.235.413c-1.274.057-1.649.07-4.859.07c-3.211 0-3.586-.015-4.859-.074c-1.171-.061-1.816-.256-2.236-.421a3.716 3.716 0 0 1-1.379-.899a3.644 3.644 0 0 1-.9-1.38c-.165-.42-.359-1.065-.42-2.235c-.045-1.26-.061-1.649-.061-4.844c0-3.196.016-3.586.061-4.861c.061-1.17.255-1.814.42-2.234c.21-.57.479-.96.9-1.381c.419-.419.81-.689 1.379-.898c.42-.166 1.051-.361 2.221-.421c1.275-.045 1.65-.06 4.859-.06l.045.03zm0 3.678a6.162 6.162 0 1 0 0 12.324a6.162 6.162 0 1 0 0-12.324zM12 16c-2.21 0-4-1.79-4-4s1.79-4 4-4s4 1.79 4 4s-1.79 4-4 4zm7.846-10.405a1.441 1.441 0 0 1-2.88 0a1.44 1.44 0 0 1 2.88 0z"/></svg>''';
  static const String tiktok = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="currentColor" d="M20.357 7.75a.537.537 0 0 0-.495-.516a4.723 4.723 0 0 1-2.415-.938a4.85 4.85 0 0 1-1.887-3.3a.538.538 0 0 0-.517-.496h-2.108a.517.517 0 0 0-.517.527v12.59a2.794 2.794 0 0 1-2.974 2.762a2.815 2.815 0 0 1-2.51-3.711A2.836 2.836 0 0 1 9.93 12.78a.506.506 0 0 0 .558-.506V9.807s-.896-.063-1.202-.063a5.271 5.271 0 0 0-4.101 1.93a5.789 5.789 0 0 0-1.37 2.52a5.862 5.862 0 0 0 2.14 6.072A5.926 5.926 0 0 0 9.591 21.5a5.946 5.946 0 0 0 4.207-1.719a5.841 5.841 0 0 0 1.75-4.133V8.71a7.844 7.844 0 0 0 4.218 1.613a.517.517 0 0 0 .548-.527V7.751z"/></svg>''';
  static const String threads = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9.914 8.128c2.505-2.014 6.11-.94 6.536 2.372c.452 3.514-.45 6.3-3.95 6.3c-3.25 0-3.15-2.8-3.15-2.8c0-3 5.15-3.4 8.15-1.9C23 15.6 19 22 13 22c-4.97 0-9-2.5-9-10S8.03 2 13 2c3.508 0 6.672 1.807 7.835 5.42"/></svg>''';
  static const String youtube = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 384 488"><path fill="currentColor" d="M325 339h-25v-15q0-12 12-12h1q12 0 12 12v15zm-95-32q-12 0-12 10v71q0 10 12 10t12-10v-71q0-10-12-10zm154-40v136q0 25-18.5 42T321 462H63q-26 0-44.5-17T0 403V267q0-24 18.5-41.5T63 208h258q26 0 44.5 17.5T384 267zM80 418V275h32v-21l-85-1v21h26v144h27zm96-122h-27v95q-2 5-7 6.5t-8-5.5v-19l-1-77h-26v100q2 17 7 20q9 6 22.5.5T155 402v16h21V296zm85 88v-64q0-19-12-26t-30 7v-47h-27v163h22l2-11q21 18 33.5 10t11.5-32zm84-9h-20v14q0 11-11 11h-4q-11 0-11-11v-29h46v-17q0-26-1-33q-3-16-21.5-20t-30.5 5q-8 7-11 15q-3 10-3 27v38q0 37 28 43q24 5 35-16q7-11 4-27zM242 169q2 5 7 8q4 3 11 3q6 0 10-3t7-9v10h30V51h-24v99q0 10-10 10q-9 0-9-10V51h-25v86q0 18 1 22q0 4 2 10zm-90-71q0-18 3-29q3-9 11-16q8-6 20-6q11 0 18 4q7 3 11 10q4 5 6 13q1 5 1 21v32q0 20-1 26q-1 7-6 15q-3 5-11 11q-8 3-16 3q-10 0-18-3q-7-3-11-9q-4-8-5-14q-2-10-2-25V98zm23 50q0 5 3.5 9t8.5 4q12 0 12-13V81q0-13-12-13t-12 13v67zm-82 34h28V85l33-83h-30l-18 62L88 2H58l35 83v97z"/></svg>''';
  static const String facebook = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 224 488"><path fill="currentColor" d="M51 91v63H4v78h47v230h95V232h65q6-37 8-78h-72v-53q0-6 6.5-12.5T168 82h52V2h-71q-28 0-48.5 8.5T71 29.5T57 55t-5.5 21.5T51 91z"/></svg>''';
  static const String linkedin = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1025 1024"><path fill="currentColor" d="M896.428 1024h-768q-53 0-90.5-37.5T.428 896V128q0-53 37.5-90.5t90.5-37.5h768q53 0 90.5 37.5t37.5 90.5v768q0 53-37.5 90.5t-90.5 37.5zm-640-864q0-13-9.5-22.5t-22.5-9.5h-64q-13 0-22.5 9.5t-9.5 22.5v64q0 13 9.5 22.5t22.5 9.5h64q13 0 22.5-9.5t9.5-22.5v-64zm0 192q0-13-9.5-22.5t-22.5-9.5h-64q-13 0-22.5 9.5t-9.5 22.5v512q0 13 9.5 22.5t22.5 9.5h64q13 0 22.5-9.5t9.5-22.5V352zm640 160q0-80-56-136t-136-56q-44 0-96.5 14t-95.5 39v-21q0-13-9.5-22.5t-22.5-9.5h-64q-13 0-22.5 9.5t-9.5 22.5v512q0 13 9.5 22.5t22.5 9.5h64q13 0 22.5-9.5t9.5-22.5V576q0-53 37.5-90.5t90.5-37.5t90.5 37.5t37.5 90.5v288q0 13 9.5 22.5t22.5 9.5h64q13 0 22.5-9.5t9.5-22.5V512z"/></svg>''';
  static const String twitter = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path fill="currentColor" d="M12.6.75h2.454l-5.36 6.142L16 15.25h-4.937l-3.867-5.07l-4.425 5.07H.316l5.733-6.57L0 .75h5.063l3.495 4.633L12.601.75Zm-.86 13.028h1.36L4.323 2.145H2.865l8.875 11.633Z"/></svg>''';
}

class SocialLinkModel {
  final String name;
  final String svgAsset;
  final String url;
  final Color brandColor;

  SocialLinkModel(this.name, this.svgAsset, this.url, this.brandColor);
}

// --- UTILS & THEME ---
class AppColors {
  static const Color accent = Color(0xFFE5FF10);
}

// --- MAIN SCREEN ---
class LinkScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const LinkScreen({super.key, this.onNavigateToHome});

  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  // Data Links
  final List<SocialLinkModel> _socialLinks = [
    SocialLinkModel('Instagram', SvgAssets.instagram, 'https://www.instagram.com/owritedotid/', const Color(0xFFE1306C)),
    SocialLinkModel('TikTok', SvgAssets.tiktok, 'https://www.tiktok.com/@owritedotid', const Color(0xFF000000)),
    SocialLinkModel('Threads', SvgAssets.threads, 'https://www.threads.com/login/?next=https%3A%2F%2Fwww.threads.com%2F%40owritedotid%2F', const Color(0xFF000000)),
    SocialLinkModel('YouTube', SvgAssets.youtube, 'https://www.youtube.com/@owritedotid', const Color(0xFFFF0000)),
    SocialLinkModel('Facebook', SvgAssets.facebook, 'https://www.facebook.com/owritedotid', const Color(0xFF1877F2)),
    SocialLinkModel('LinkedIn', SvgAssets.linkedin, 'https://www.linkedin.com/company/owritemedia/', const Color(0xFF0A66C2)),
    SocialLinkModel('X (Twitter)', SvgAssets.twitter, 'https://x.com/owritedotid', const Color(0xFF1DA1F2)),
  ];

  Future<void> _handleLinkTap(String name, String url) async {
    try {
      final uri = Uri.parse(url);
      HapticFeedback.lightImpact();

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          HapticFeedback.mediumImpact();
          _showCustomSnackBar(context, "Tidak dapat membuka $name. Cek koneksi Anda.");
        }
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.mediumImpact();
        _showCustomSnackBar(context, "Gagal membuka $name. Cek koneksi Anda.");
      }
    }
  }

  void _showCustomSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.redAccent.shade700,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Responsive grid count
    int gridCount = 1;
    if (width > 600) gridCount = 2;
    if (width > 900) gridCount = 3;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: CustomScrollView(
        cacheExtent: 50.0,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. HERO HEADER SECTION with border bottom when appbar is collapsed (pinned)
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            surfaceTintColor: Colors.transparent,
            backgroundColor: themeProvider.backgroundColor,
            elevation: 0,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final collapsed = constraints.maxHeight <= kToolbarHeight + MediaQuery.of(context).padding.top;
                final double minFontSize = 24;
                final double maxFontSize = 36;
                final double expandedHeight = 180.0;
                final double collapsedHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
                final double t = (constraints.maxHeight - collapsedHeight) / (expandedHeight - collapsedHeight);
                // Clamp progress for robustness
                final double progress = t.clamp(0.0, 1.0);
                final double animatedFontSize = minFontSize + (maxFontSize - minFontSize) * progress;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: themeProvider.backgroundColor,
                      child: Stack(
                        children: [
                          Positioned(
                            right: -30,
                            top: -30,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent.withOpacity(0.1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Title with animated font size
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 16),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                              begin: minFontSize, end: animatedFontSize),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Text(
                              'Ikuti Kami',
                              style: TextStyle(
                                fontFamily: 'CrimsonPro',
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: value,
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Border Bottom ONLY VISIBLE when collapsed
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 1,
                        color: collapsed
                            ? (isDark ? Colors.grey[800] : Colors.grey[300])
                            : Colors.transparent,
                      ),
                    )
                  ],
                );
              },
            ),
          ),

          // 2. FEATURED WEBSITE CARD
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _WebsiteCard(
                isDark: isDark,
                onTap: () =>
                    _handleLinkTap("Website", "https://www.owrite.id/"),
              ),
            ),
          ),

          // 3. SOCIAL GRID TITLE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(width: 4, height: 24, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    "MEDIA SOSIAL",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. SOCIAL GRID
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: gridCount == 1 ? 3.2 : 2.5,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final link = _socialLinks[index];

                  return _AnimatedGridItem(
                    index: index,
                    child: _SocialCard(
                      link: link,
                      isDark: isDark,
                      onTap: () => _handleLinkTap(link.name, link.url),
                    ),
                  );
                },
                childCount: _socialLinks.length,
                addAutomaticKeepAlives: false,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class _AnimatedGridItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedGridItem({required this.index, required this.child});

  @override
  State<_AnimatedGridItem> createState() => _AnimatedGridItemState();
}

class _AnimatedGridItemState extends State<_AnimatedGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 500), // Durasi sedikit dipercepat agar snappy
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    int delay = 0;
    if (widget.index < 6) {
      delay = widget.index * 60;
    } else {
      delay = 0;
    }

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class _WebsiteCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _WebsiteCard({required this.isDark, required this.onTap});

  @override
  State<_WebsiteCard> createState() => _WebsiteCardState();
}

class _WebsiteCardState extends State<_WebsiteCard> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bgColor = themeProvider.backgroundColor;
    final textColor = widget.isDark ? Colors.white : Colors.black;

    final borderColor =
        widget.isDark ? AppColors.accent : Colors.black; // PURE black on light mode, accent on dark mode

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.accent.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                // Replace the icon with the official owrite.id image
                child: Image.asset(
                  'assets/images/icon-app.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "owrite.id",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "OFFICIAL",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Kunjungi website resmi kami",
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_outward_rounded,
                color: widget.isDark ? Colors.white : Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialCard extends StatelessWidget {
  final SocialLinkModel link;
  final bool isDark;
  final VoidCallback onTap;

  const _SocialCard({
    required this.link,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor =
        (link.name == 'TikTok' || link.name.contains('X') || link.name == 'Threads')
            ? (isDark ? Colors.white : Colors.black)
            : link.brandColor;

    final borderColor = isDark ? AppColors.accent : Colors.black; // PURE black on light mode, accent on dark mode

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: link.brandColor.withOpacity(0.1),
        highlightColor: link.brandColor.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent, // changed to transparent for all modes
                ),
                child: SvgPicture.string(
                  link.svgAsset,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      link.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Tap untuk membuka",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}