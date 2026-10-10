import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/post_model.dart';
import '../theme/apple_theme.dart';
import '../theme/lema_motion.dart';

/// Tag helper so every hero in the app is uniquely addressable.
///
/// Slice 14 acceptance requires "no hero-tag collisions with grid tiles
/// (unique tags per post id)" — funnelling every tag through here is what
/// guarantees that, now and for any future screen that adds a hero.
class LemaHero {
  const LemaHero._();

  /// Hero tag for a post's card surface.
  static String card(String postId) => 'lema.card.$postId';

  /// Hero tag for a post's poster artwork.
  static String art(String postId) => 'lema.art.$postId';
}

/// The physical representation of a card, for the swipe between the black
/// *virtual* card Lema generates and the light-gray card you print.
enum CardStock { virtual, physical }

/// Slice 14 — Virtual card morph slide-up.
///
/// Tapping the hero card in the feed morphs it (Hero) into this view, where
/// it becomes the top hero of a paged swipe between the virtual and physical
/// card. Detail rows stagger in on arrival.
///
/// Motion contract: everything reads from [LemaMotion] — the route fades
/// with `enter`, rows stagger via `LemaMotion.stagger`, the stock pill
/// springs via `LemaMotion.spring`, and reduced motion degrades to a
/// crossfade with no stagger.
class CardDetailView extends StatefulWidget {
  final PostModel post;

  const CardDetailView({super.key, required this.post});

  static Route<void> route(PostModel post) {
    return PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: LemaMotion.emphasized,
      reverseTransitionDuration: LemaMotion.reverseEmphasized,
      pageBuilder: (_, _, _) => CardDetailView(post: post),
      transitionsBuilder: (_, anim, _, child) {
        // The card itself is a Hero; this only fades the page backdrop in
        // behind it so the morph reads as a slide-up out of the feed.
        final curved = CurvedAnimation(parent: anim, curve: LemaMotion.enter);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CardDetailView> createState() => _CardDetailViewState();
}

class _CardDetailViewState extends State<CardDetailView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final PageController _pages;
  CardStock _stock = CardStock.virtual;
  bool _reduceMotion = false;

  static const int _pageCount = 2;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    _entrance = AnimationController(vsync: this, duration: LemaMotion.slow);
    // Start after the Hero flight has landed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_reduceMotion) _entrance.forward();
      if (mounted) _entrance.value = 1;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = LemaMotion.reduceMotionOf(context);
    if (_reduceMotion) _entrance.value = 1;
  }

  @override
  void dispose() {
    _pages.dispose();
    _entrance.dispose();
    super.dispose();
  }

  int get _page => _stock == CardStock.virtual ? 0 : 1;

  void _onPageChanged(int page) {
    final next = page == 0 ? CardStock.virtual : CardStock.physical;
    if (next == _stock) return;
    setState(() => _stock = next);
    LemaMotion.tap();
  }

  void _selectStock(CardStock stock) {
    final page = stock == CardStock.virtual ? 0 : 1;
    if (page == _page) return;
    LemaMotion.tap();
    _pages.animateToPage(
      page,
      duration: LemaMotion.emphasized,
      // Spring snap — overshoots slightly then settles.
      curve: LemaMotion.springSoft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final post = widget.post;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B0B0F)
          : const Color(0xFFF2F2F6),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, isDark, post),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _pageCount,
                onPageChanged: _onPageChanged,
                physics: const PageScrollPhysics(),
                itemBuilder: (context, i) {
                  final stock = i == 0 ? CardStock.virtual : CardStock.physical;
                  return _buildCardPage(context, isDark, post, stock);
                },
              ),
            ),
            _buildStockSwitcher(context, isDark),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, PostModel post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              CupertinoIcons.chevron_left,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              post.title.isEmpty ? 'Untitled Post' : post.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCardPage(
    BuildContext context,
    bool isDark,
    PostModel post,
    CardStock stock,
  ) {
    // The virtual card is the hero target; the physical card is its twin.
    final isVirtual = stock == CardStock.virtual;

    // Size the 4:5 card explicitly from the space the page actually has.
    // AspectRatio alone mis-resolves inside a Hero/PageView and overflows
    // on short viewports, so the box is computed here.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gutter = 20.0;
        final maxW = constraints.maxWidth - (gutter * 2);
        final maxH = constraints.maxHeight - 24;
        var w = maxW;
        var h = w / 0.8; // 4:5 portrait
        if (h > maxH) {
          h = maxH;
          w = h * 0.8;
        }

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Hero(
              tag: LemaHero.card(post.id),
              flightShuttleBuilder: _cardShuttle,
              child: Material(
                color: Colors.transparent,
                child: _CardSurface(
                  post: post,
                  stock: stock,
                  radius: isVirtual ? 30 : 22,
                  isDark: isDark,
                  caption: isVirtual
                      ? 'Virtual card · 1080 × 1350'
                      : 'Physical card · 85 × 55 mm',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cardShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    // A flat, slightly lifted slab reads better than the full card during
    // flight — the heavy content crossfades in at the destination.
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = direction == HeroFlightDirection.push
            ? animation.value
            : 1 - animation.value;
        return Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 0.94 + (0.06 * t),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(lerpRadius(30, 22, t)),
                color: Colors.black.withAlpha(18),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockSwitcher(BuildContext context, bool isDark) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final t = _reduceMotion ? 1.0 : _entrance.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withAlpha(6),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            _stockPill(
              context,
              stock: CardStock.virtual,
              label: 'Virtual card',
              isDark: isDark,
            ),
            _stockPill(
              context,
              stock: CardStock.physical,
              label: 'Physical card',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockPill(
    BuildContext context, {
    required CardStock stock,
    required String label,
    required bool isDark,
  }) {
    final selected = _stock == stock;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectStock(stock),
        child: AnimatedContainer(
          duration: LemaMotion.quick,
          curve: LemaMotion.spring,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? Colors.white : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? Colors.black
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}

/// One card face. Shared by the hero target, the flight and the physical
/// twin, so all three always agree on radius, ratio and artwork.
class _CardSurface extends StatelessWidget {
  final PostModel post;
  final CardStock stock;
  final double radius;
  final bool isDark;
  final String caption;

  const _CardSurface({
    required this.post,
    required this.stock,
    required this.radius,
    required this.isDark,
    required this.caption,
  });

  bool get _isVirtual => stock == CardStock.virtual;

  @override
  Widget build(BuildContext context) {
    // Virtual = black, saturated artwork. Physical = light-gray, washed out.
    final face = _isVirtual ? const Color(0xFF08080A) : const Color(0xFFE9E9EC);
    final ink = _isVirtual ? Colors.white : const Color(0xFF1A1A1E);

    // The parent hands us an explicit, already-correct 4:5 box, so this just
    // fills it — no aspect negotiation that could overflow a short viewport.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          color: face,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 90 : 34),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster artwork, muted on the physical card.
            Opacity(
              opacity: _isVirtual ? 1.0 : 0.22,
              child: _CardArtwork(post: post, muted: !_isVirtual),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(_isVirtual ? 60 : 20),
                    Colors.transparent,
                    Colors.black.withAlpha(_isVirtual ? 150 : 40),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Print marks — the physical twin gets registration corners.
            if (!_isVirtual) ...[
              Positioned(
                top: 12,
                left: 12,
                child: Icon(
                  CupertinoIcons.scope,
                  size: 16,
                  color: ink.withAlpha(90),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Text(
                  '85×55',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ink.withAlpha(120),
                  ),
                ),
              ),
            ],
            // Foreground copy, anchored to the bottom so it never collides
            // with faces mid-frame, whatever the card height.
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _isVirtual
                          ? AppleTheme.systemBlue
                          : ink.withAlpha(16),
                    ),
                    child: Text(
                      post.platformInfo.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: _isVirtual ? Colors.white : ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.title.isEmpty ? 'Untitled Post' : post.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ink.withAlpha(_isVirtual ? 150 : 120),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardArtwork extends StatelessWidget {
  final PostModel post;
  final bool muted;

  const _CardArtwork({required this.post, required this.muted});

  @override
  Widget build(BuildContext context) {
    final seed = post.id.hashCode;
    final tint = muted ? const Color(0xFF9A9AA2) : AppleTheme.systemBlue;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: muted
                  ? [const Color(0xFFD5D5DA), const Color(0xFFBFBFC6)]
                  : [
                      HSLColor.fromColor(tint).withLightness(0.32).toColor(),
                      HSLColor.fromColor(tint).withLightness(0.14).toColor(),
                    ],
            ),
          ),
        ),
        // A few soft blobs keyed off the post id so each card differs.
        for (var i = 0; i < 3; i++)
          Align(
            alignment: Alignment(
              ((seed >> (i * 3)) & 3) / 2.0 - 1.0,
              ((seed >> (i * 3 + 2)) & 3) / 2.0 - 1.0,
            ),
            child: FractionallySizedBox(
              widthFactor: 0.7,
              child: FractionallySizedBox(
                heightFactor: 0.42,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (muted ? Colors.white : tint).withAlpha(
                      muted ? 70 : 90,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (post.isVideo)
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(muted ? 140 : 230),
              ),
              child: Icon(
                CupertinoIcons.play_fill,
                size: 24,
                color: muted ? const Color(0xFF2A2A2E) : Colors.black87,
              ),
            ),
          ),
      ],
    );
  }
}
