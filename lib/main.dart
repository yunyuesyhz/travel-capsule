import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'data/controller.dart';
import 'features/home.dart';

const ink = Color(0xFF35251E),
    paper = Color(0xFFFFFAF3),
    ocean = Color(0xFFD97730),
    muted = Color(0xFF817269),
    sky = Color(0xFFF0E9FF),
    seafoam = Color(0xFFEBF3D8),
    sun = Color(0xFFFFC76F),
    accent = Color(0xFF7452D1),
    coral = Color(0xFFC84F45),
    line = Color(0xFFF0E6DB),
    peach = Color(0xFFFFE6CE),
    leaf = Color(0xFF729C37),
    buttonOrange = Color(0xFFB85A22);

ButtonStyle glassFilledButtonStyle({
  Color fill = buttonOrange,
  Color foreground = Colors.white,
  Size minimumSize = const Size(48, 54),
  double fillOpacity = .88,
}) => ButtonStyle(
  backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  foregroundColor: WidgetStatePropertyAll(foreground),
  minimumSize: WidgetStatePropertyAll(minimumSize),
  elevation: const WidgetStatePropertyAll(0),
  animationDuration: const Duration(milliseconds: 220),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  overlayColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.pressed)
        ? Colors.white.withValues(alpha: .14)
        : Colors.transparent,
  ),
  backgroundBuilder: (context, states, child) => _glassButtonLayer(
    states,
    child,
    borderRadius: BorderRadius.circular(20),
    tint: fill,
    opacity: fillOpacity,
    borderColor: Colors.white,
    borderOpacity: .24,
  ),
);

ButtonStyle glassOutlinedButtonStyle({
  Color tint = Colors.white,
  Color foreground = accent,
  Color borderColor = line,
  double fillOpacity = .5,
}) => ButtonStyle(
  backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  foregroundColor: WidgetStatePropertyAll(foreground),
  minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
  elevation: const WidgetStatePropertyAll(0),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
  backgroundBuilder: (context, states, child) => _glassButtonLayer(
    states,
    child,
    borderRadius: BorderRadius.circular(20),
    tint: tint,
    opacity: fillOpacity,
    borderColor: borderColor,
    borderOpacity: .62,
  ),
);

Widget _glassButtonLayer(
  Set<WidgetState> states,
  Widget? child, {
  required BorderRadius borderRadius,
  required Color tint,
  required double opacity,
  required Color borderColor,
  required double borderOpacity,
}) {
  final isDisabled = states.contains(WidgetState.disabled);
  final isPressed = states.contains(WidgetState.pressed);
  final alpha = isDisabled ? opacity * .5 : (isPressed ? .96 : opacity);
  return PressBounce(
    enabled: !isDisabled,
    child: ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: alpha),
            borderRadius: borderRadius,
            border: Border.all(
              color: borderColor.withValues(alpha: borderOpacity),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.tint = Colors.white,
    this.opacity = .68,
    this.blurSigma = 14,
    this.gradient,
    this.borderColor = line,
    this.borderOpacity = .62,
    this.shadows = const [
      BoxShadow(color: Color(0x105B3623), blurRadius: 18, offset: Offset(0, 7)),
    ],
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color tint;
  final double opacity;
  final double blurSigma;
  final Gradient? gradient;
  final Color borderColor;
  final double borderOpacity;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
    child: ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: gradient == null ? tint.withValues(alpha: opacity) : null,
            gradient: gradient,
            borderRadius: borderRadius,
            border: Border.all(
              color: borderColor.withValues(alpha: borderOpacity),
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class PressBounce extends StatefulWidget {
  const PressBounce({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressBounce> createState() => _PressBounceState();
}

class _PressBounceState extends State<PressBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  Timer? _releaseTimer;
  int? _pointer;
  Offset? _downPosition;
  bool _dragged = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _scale = Tween<double>(begin: 1, end: .96).animate(_controller);
  }

  void _press(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    _releaseTimer?.cancel();
    _pointer = event.pointer;
    _downPosition = event.position;
    _dragged = false;
    _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
    );
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer || _dragged || _downPosition == null) return;
    if ((event.position - _downPosition!).distance > 12) {
      _dragged = true;
      _release(spring: false);
    }
  }

  void _end(int pointer, {bool cancelled = false}) {
    if (_pointer != pointer) return;
    _pointer = null;
    _downPosition = null;
    if (cancelled || _dragged) {
      _release(spring: false);
    } else {
      _releaseTimer?.cancel();
      _releaseTimer = Timer(const Duration(milliseconds: 65), () {
        if (mounted) _release(spring: true);
      });
    }
  }

  void _release({required bool spring}) {
    _releaseTimer?.cancel();
    _releaseTimer = null;
    _controller.animateBack(
      0,
      duration: Duration(milliseconds: spring ? 420 : 140),
      curve: spring ? Curves.elasticOut : Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(PressBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _pointer = null;
      _downPosition = null;
      _release(spring: false);
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _press,
    onPointerMove: _move,
    onPointerUp: (event) => _end(event.pointer),
    onPointerCancel: (event) => _end(event.pointer, cancelled: true),
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}

OverlayEntry? _activeAppNoticeEntry;
GlobalKey<_AnimatedAppNoticeState>? _activeAppNoticeKey;

void showAppNotice(BuildContext context, String text, {bool isError = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final previousState = _activeAppNoticeKey?.currentState;
  if (previousState != null) {
    previousState.dismiss();
  } else {
    _activeAppNoticeEntry?.remove();
  }

  final key = GlobalKey<_AnimatedAppNoticeState>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AnimatedAppNotice(
      key: key,
      text: text,
      isError: isError,
      onDismissed: () {
        if (identical(_activeAppNoticeEntry, entry)) {
          _activeAppNoticeEntry = null;
          _activeAppNoticeKey = null;
        }
        entry.remove();
      },
    ),
  );
  _activeAppNoticeEntry = entry;
  _activeAppNoticeKey = key;
  overlay.insert(entry);
}

class _AnimatedAppNotice extends StatefulWidget {
  const _AnimatedAppNotice({
    super.key,
    required this.text,
    required this.isError,
    required this.onDismissed,
  });

  final String text;
  final bool isError;
  final VoidCallback onDismissed;

  @override
  State<_AnimatedAppNotice> createState() => _AnimatedAppNoticeState();
}

class _AnimatedAppNoticeState extends State<_AnimatedAppNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      reverseDuration: const Duration(milliseconds: 300),
    );
    final eased = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = eased;
    _scale = Tween<double>(begin: .94, end: 1).animate(eased);
    _slide = Tween<Offset>(
      begin: const Offset(0, .55),
      end: Offset.zero,
    ).animate(eased);
    _controller.forward();
    _timer = Timer(const Duration(seconds: 3), dismiss);
  }

  Future<void> dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned(
      left: 18,
      right: 18,
      bottom: media.viewInsets.bottom + media.padding.bottom + 104,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  alignment: Alignment.bottomCenter,
                  scale: _scale,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 19,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: .78),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .25),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x36000000),
                                blurRadius: 26,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.isError
                                    ? Icons.info_outline_rounded
                                    : Icons.check_rounded,
                                color: widget.isError
                                    ? sun
                                    : const Color(0xFFBCE5A5),
                                size: 21,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  widget.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.4,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  try {
    final controller = await CapsuleController.open();
    runApp(
      ProviderScope(
        overrides: [controllerProvider.overrideWith((ref) => controller)],
        child: const CapsuleApp(),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_off_outlined, size: 52),
                  const SizedBox(height: 24),
                  const Text(
                    '本地资料暂时没有打开',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '请检查手机剩余空间，然后重新打开应用。已有资料不会因此被清空。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CapsuleApp extends StatefulWidget {
  const CapsuleApp({super.key});
  @override
  State<CapsuleApp> createState() => _CapsuleAppState();
}

class _CapsuleAppState extends State<CapsuleApp> {
  late final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    ],
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: '旅途胶囊',
    debugShowCheckedModeBanner: false,
    routerConfig: router,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: const ColorScheme.light(
        primary: ocean,
        onPrimary: Colors.white,
        primaryContainer: peach,
        onPrimaryContainer: ink,
        secondary: accent,
        onSecondary: Colors.white,
        secondaryContainer: sky,
        onSecondaryContainer: ink,
        tertiary: leaf,
        onTertiary: ink,
        tertiaryContainer: seafoam,
        onTertiaryContainer: ink,
        error: coral,
        onError: Colors.white,
        surface: paper,
        onSurface: ink,
        outline: line,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: paper,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accent, width: 1.8),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(style: glassFilledButtonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: glassOutlinedButtonStyle(),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: const WidgetStatePropertyAll(accent),
          minimumSize: const WidgetStatePropertyAll(Size(48, 42)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          backgroundBuilder: (context, states, child) => _glassButtonLayer(
            states,
            child,
            borderRadius: BorderRadius.circular(16),
            tint: paper,
            opacity: .42,
            borderColor: Colors.white,
            borderOpacity: .58,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: const WidgetStatePropertyAll(ink),
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          shape: const WidgetStatePropertyAll(CircleBorder()),
          backgroundBuilder: (context, states, child) => _glassButtonLayer(
            states,
            child,
            borderRadius: BorderRadius.circular(100),
            tint: Colors.white,
            opacity: .56,
            borderColor: line,
            borderOpacity: .7,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: buttonOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        shape: StadiumBorder(),
      ),
      cardTheme: CardThemeData(
        color: Color(0xC8FFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: sky,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: line,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: line),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ocean,
        height: 70,
        elevation: 0,
        shadowColor: const Color(0x1A5B3623),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? ink : muted,
            size: states.contains(WidgetState.selected) ? 25 : 23,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? ink : muted,
          ),
        ),
      ),
    ),
  );
}
