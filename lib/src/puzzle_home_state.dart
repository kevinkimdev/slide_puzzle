import 'dart:async';
import 'dart:math' as math;

import 'base_theme.dart';
import 'core/puzzle_animator.dart';
import 'flutter.dart';
import 'frame_nanny.dart';
import 'theme_plaster.dart';
import 'theme_seattle.dart';
import 'theme_simple.dart';

class _Shake extends Animatable<Offset> {
  const _Shake();

  @override
  Offset transform(double t) => Offset(0.01 * math.sin(t * math.pi * 3), 0);
}

class PuzzleHomeState extends State
    with TickerProviderStateMixin
    implements AppState {
  AnimationController _controller;
  Animation<Offset> _shuffleOffsetAnimation;

  @override
  Animation<Offset> get shuffleOffsetAnimation => _shuffleOffsetAnimation;

  @override
  final PuzzleAnimator puzzle;

  @override
  final animationNotifier = AnimationNotifier();

  final _nanny = FrameNanny();

  PuzzleTheme _currentTheme;

  @override
  PuzzleTheme get currentTheme => _currentTheme;

  @override
  set currentTheme(PuzzleTheme theme) {
    setState(() {
      _currentTheme = theme;
    });
  }

  Duration _tickerTimeSinceLastEvent = Duration.zero;
  Ticker _ticker;
  Duration _lastElapsed;
  StreamSubscription sub;

  @override
  bool autoPlay = false;

  PuzzleHomeState(this.puzzle) {
    sub = puzzle.onEvent.listen(_onPuzzleEvent);

    _themeDataCache = List.unmodifiable(
        [ThemeSimple(this), ThemeSeattle(this), ThemePlaster(this)]);

    _currentTheme = themeData.first;
  }

  List<PuzzleTheme> _themeDataCache;

  @override
  Iterable<PuzzleTheme> get themeData => _themeDataCache;

  @override
  void setAutoPlay(bool newValue) {
    if (newValue != autoPlay) {
      setState(() {
        // Only allow enabling autoPlay if the puzzle is not solved
        autoPlay = newValue && !puzzle.solved;
        if (autoPlay) {
          _ensureTicking();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker ??= createTicker(_onTick);
    _ensureTicking();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _shuffleOffsetAnimation = _controller.drive(const _Shake());
  }

  @override
  Widget build(BuildContext context) => _currentTheme.build(context);

  @override
  void dispose() {
    animationNotifier.dispose();
    _controller?.dispose();
    _ticker?.dispose();
    sub.cancel();
    super.dispose();
  }

  void _onPuzzleEvent(PuzzleEvent e) {
    _tickerTimeSinceLastEvent = Duration.zero;
    _ensureTicking();
    if (e == PuzzleEvent.noop) {
      assert(e == PuzzleEvent.noop);
      _controller.reset();
      _controller.forward();
    }
    setState(() {
      // noop
    });
  }

  void _ensureTicking() {
    if (!_ticker.isTicking) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (elapsed == Duration.zero) {
      _lastElapsed = elapsed;
    }
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;

    if (delta.inMilliseconds <= 0) {
      // `_delta` may be negative or zero if `elapsed` is zero (first tick)
      // or during a restart. Just ignore this case.
      return;
    }

    _tickerTimeSinceLastEvent += delta;
    puzzle.update(_nanny.tick(delta));

    if (!puzzle.stable) {
      animationNotifier.animate();
    } else {
      if (!autoPlay) {
        _ticker.stop();
        _lastElapsed = null;
      }
    }

    if (autoPlay &&
        _tickerTimeSinceLastEvent > const Duration(milliseconds: 200)) {
      puzzle.playRandom();

      if (puzzle.solved) {
        setAutoPlay(false);
      }
    }
  }
}
