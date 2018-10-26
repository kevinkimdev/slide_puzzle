import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'src/puzzle.dart';
import 'src/puzzle_animator.dart';

void main() => runApp(PuzzleApp(4, 4));

class PuzzleApp extends StatelessWidget {
  final int rows, columns;

  PuzzleApp(this.rows, this.columns);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '${rows * columns - 1} Puzzle',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: _PuzzleHome(rows, columns),
      );
}

class _PuzzleHome extends StatefulWidget {
  final int _rows, _columns;

  const _PuzzleHome(this._rows, this._columns, {Key key}) : super(key: key);

  @override
  _PuzzleHomeState createState() => _PuzzleHomeState(Puzzle(_columns, _rows));
}

class _PuzzleHomeState extends State<_PuzzleHome>
    with SingleTickerProviderStateMixin {
  static const _textScaleFactor = 2.0;
  final Puzzle _puzzle;
  final PuzzleAnimator _puzzleAnimator;

  Ticker _ticker;
  Duration _lastElapsed;
  Duration _delta;

  _PuzzleHomeState(this._puzzle) : _puzzleAnimator = PuzzleAnimator(_puzzle);

  @override
  void initState() {
    assert(_ticker == null);
    _ticker = createTicker(_onTick)..start();
    super.initState();
  }

  void _onTick(Duration elapsed) {
    if (elapsed == Duration.zero) {
      elapsed = const Duration(milliseconds: 17);
    }
    if (_lastElapsed != null && elapsed > _lastElapsed) {
      _delta = elapsed - _lastElapsed;
    } else {
      _delta = const Duration(milliseconds: 17);
    }
    _lastElapsed = elapsed;

    _puzzleAnimator.update(_delta);

    if (!_puzzleAnimator.stable) {
      setState(() {
        // noop – just ping the engine!
      });
    } else {
      _ticker.stop();
      _lastElapsed = null;
    }
  }

  void _click(int value) {
    final validClick = _puzzle.clickValue(value);
    if (!validClick) {
      _puzzleAnimator.shake(value);
    }
    setState(() {
      // noop
    });
  }

  void _reset() {
    setState(_puzzle.reset);
  }

  @override
  void setState(fn) {
    if (!_ticker.isTicking) {
      _ticker.start();
    }
    super.setState(fn);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('15 Puzzle'),
      ),
      body: MediaQuery(
        data: const MediaQueryData(textScaleFactor: _textScaleFactor),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Clicks: ${_puzzle.clickCount}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Tiles left: ${_puzzle.incorrectTiles}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                        child: RaisedButton(
                      onPressed: _reset,
                      child: const Text(
                        'New game...',
                      ),
                    ))
                  ],
                ),
              ),
              Expanded(
                child: Flow(
                    delegate: _PuzzleDelegate(_puzzleAnimator),
                    children: List<Widget>.generate(_puzzle.length, (i) {
                      Widget child;
                      if (i == 0) {
                        child = const Center(
                            child: Text(
                          '🦋',
                          style: TextStyle(),
                          textScaleFactor: _textScaleFactor * 2.5,
                        ));
                      } else {
                        final correctPosition = _puzzle.isCorrectPosition(i);
                        child = RaisedButton(
                            child: Text(
                              i.toString(),
                              textScaleFactor: _textScaleFactor *
                                  (correctPosition ? 1.5 : 1),
                              style: TextStyle(
                                  color: correctPosition
                                      ? Colors.blue
                                      : Colors.black,
                                  fontWeight: correctPosition
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                            ),
                            onPressed: () => _click(i));
                      }

                      return Padding(
                        padding: const EdgeInsets.all(6),
                        child: child,
                      );
                    })),
              ),
            ],
          ),
        ),
      ));
}

class _PuzzleDelegate extends FlowDelegate {
  final PuzzleAnimator _puzzleAnimator;

  Puzzle get _puzzle => _puzzleAnimator.puzzle;

  _PuzzleDelegate(this._puzzleAnimator);

  @override
  Size getSize(BoxConstraints constraints) {
    final minSquareSize = math.min(constraints.maxWidth / _puzzle.width,
        constraints.maxHeight / _puzzle.height);

    return Size(minSquareSize * _puzzle.width, minSquareSize * _puzzle.height);
  }

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    final minSquareSize = math.min(constraints.maxWidth / _puzzle.width,
        constraints.maxHeight / _puzzle.height);

    return BoxConstraints.tightFor(width: minSquareSize, height: minSquareSize);
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final minSquareSize = math.min(context.size.width / _puzzle.width,
        context.size.height / _puzzle.height);

    final delta = ((context.size -
            Offset(minSquareSize * _puzzle.width,
                minSquareSize * _puzzle.height)) as Size) *
        0.5;

    final tileSize = context.getChildSize(0);
    for (var i = 0; i < _puzzle.length; i++) {
      final tileLocation = _puzzleAnimator.location(i);
      context.paintChild(i,
          transform: Matrix4.translationValues(
              tileLocation.x * tileSize.width + delta.width,
              tileLocation.y * tileSize.height + delta.height,
              i.toDouble()));
    }
  }

  @override
  bool shouldRepaint(covariant _PuzzleDelegate oldDelegate) => true;
}
