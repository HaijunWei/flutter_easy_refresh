part of easyrefresh;

/// Spring used by bezier curves.
SpringDescription kBezierSpringBuilder({
  required IndicatorMode mode,
  required double offset,
  required double actualTriggerOffset,
  required double velocity,
}) {
  double mass = 6 + (offset - actualTriggerOffset) / 36;
  double damping = 0.75 + velocity.abs() / 10000;
  double stiffness = 1000 + velocity.abs() / 6;
  return SpringDescription(
    mass: mass,
    stiffness: stiffness,
    damping: damping,
  );
}

/// Friction factor used by bezier curves.
double kBezierFrictionFactor(double overscrollFraction) =>
    0.4 * math.pow(1 - overscrollFraction, 2);

/// Bezier curve background.
class BezierBackground extends StatefulWidget {
  /// Indicator properties and state.
  final IndicatorState state;

  /// Background color.
  final Color? color;

  /// Use animation with [IndicatorNotifier.createBallisticSimulation].
  final bool useAnimation;

  /// True for up and left.
  /// False for down and right.
  final bool reverse;

  const BezierBackground({
    Key? key,
    required this.state,
    required this.reverse,
    this.useAnimation = true,
    this.color,
  }) : super(key: key);

  @override
  State<BezierBackground> createState() => _BezierBackgroundState();
}

class _BezierBackgroundState extends State<BezierBackground>
    with SingleTickerProviderStateMixin {
  IndicatorNotifier get _notifier => widget.state.notifier;

  double get _offset => widget.state.offset;

  Axis get _axis => widget.state.axis;

  double get _actualTriggerOffset => widget.state.actualTriggerOffset;

  /// Get background color.
  Color get _color => widget.color ?? Theme.of(context).primaryColor;

  /// Animation controller.
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController.unbounded(vsync: this);
    _animationController.addListener(() {
      setState(() {});
    });
    widget.state.notifier.addModeChangeListener(_onModeChange);
    widget.state.userOffsetNotifier.addListener(_onUserOffset);
  }

  @override
  void dispose() {
    _animationController.dispose();
    widget.state.notifier.removeModeChangeListener(_onModeChange);
    widget.state.userOffsetNotifier.removeListener(_onUserOffset);
    super.dispose();
  }

  @override
  void didUpdateWidget(BezierBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  /// Mode change listener.
  void _onModeChange(IndicatorMode mode, double offset) {
    if (mode == IndicatorMode.ready) {
      if (widget.useAnimation) {
        _startAnimation();
      }
    } else if (mode == IndicatorMode.done || mode == IndicatorMode.inactive) {
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
    }
  }

  /// User offset.
  void _onUserOffset() {
    final state = widget.state;
    if (state.userOffsetNotifier.value && _animationController.isAnimating) {
      _animationController.stop();
    }
  }

  /// Start animation.
  void _startAnimation() {
    final simulation = _notifier.createBallisticSimulation(
        _notifier.position, _notifier.velocity);
    if (simulation != null) {
      _animationController.animateWith(simulation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reboundOffset = _animationController.isAnimating
        ? _notifier.calculateOffsetWithPixels(
            _notifier.position, _animationController.value)
        : null;
    double offset = _offset;
    if (reboundOffset != null) {
      offset = math.max(offset, reboundOffset);
    }
    return ClipPath(
      clipper: _BezierPainter(
        axis: _axis,
        reverse: widget.reverse,
        offset: _offset,
        actualTriggerOffset: _actualTriggerOffset,
        reboundOffset: reboundOffset,
      ),
      child: Container(
        width: _axis == Axis.horizontal ? offset : double.infinity,
        height: _axis == Axis.vertical ? offset : double.infinity,
        clipBehavior: Clip.none,
        decoration: BoxDecoration(
          color: _color,
        ),
      ),
    );
  }
}

/// Bezier curve painter.
class _BezierPainter extends CustomClipper<Path> {
  /// [Scrollable] axis.
  final Axis axis;

  /// True for up and left.
  /// False for down and right.
  final bool reverse;

  /// Overscroll offset.
  final double offset;

  /// Actual trigger offset.
  final double actualTriggerOffset;

  /// Rebound offset.
  final double? reboundOffset;

  _BezierPainter({
    required this.axis,
    required this.reverse,
    required this.offset,
    required this.actualTriggerOffset,
    this.reboundOffset,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final height = size.height;
    final width = size.width;
    if (axis == Axis.vertical) {
      if (reverse) {
        // Top
        final startHeight = reboundOffset == null
            ? height > actualTriggerOffset
                ? height - actualTriggerOffset
                : 0.0
            : height - actualTriggerOffset;
        path.moveTo(width, startHeight);
        path.lineTo(width, height);
        path.lineTo(0, height);
        path.lineTo(0, startHeight);
        if (reboundOffset != null) {
          path.quadraticBezierTo(
            width / 2,
            startHeight - (reboundOffset! - actualTriggerOffset) * 2,
            width,
            startHeight,
          );
        } else if (height <= actualTriggerOffset) {
          path.lineTo(width, startHeight);
        } else {
          path.quadraticBezierTo(
            width / 2,
            -(height - actualTriggerOffset),
            width,
            startHeight,
          );
        }
      } else {
        // Bottom
        final startHeight = reboundOffset == null
            ? math.min(height, actualTriggerOffset)
            : actualTriggerOffset;
        path.moveTo(width, startHeight);
        path.lineTo(width, 0);
        path.lineTo(0, 0);
        path.lineTo(0, startHeight);
        if (reboundOffset != null) {
          path.quadraticBezierTo(
            width / 2,
            (reboundOffset! - actualTriggerOffset) * 2 + actualTriggerOffset,
            width,
            startHeight,
          );
        } else if (height <= actualTriggerOffset) {
          path.lineTo(width, startHeight);
        } else {
          path.quadraticBezierTo(
            width / 2,
            height + (height - actualTriggerOffset),
            width,
            startHeight,
          );
        }
      }
    } else {
      if (reverse) {
        // Left
        final startWidth =
            width > actualTriggerOffset ? width - actualTriggerOffset : 0.0;
        path.moveTo(startWidth, 0);
        path.lineTo(width, 0);
        path.lineTo(width, height);
        path.lineTo(startWidth, height);
        if (reboundOffset != null) {
          path.quadraticBezierTo(
            startWidth - (reboundOffset! - actualTriggerOffset) * 2,
            height / 2,
            startWidth,
            0,
          );
        } else if (width <= actualTriggerOffset) {
          path.lineTo(startWidth, 0);
        } else {
          path.quadraticBezierTo(
            -(width - actualTriggerOffset),
            height / 2,
            startWidth,
            0,
          );
        }
      } else {
        // Right
        final startWidth = math.min(width, actualTriggerOffset);
        path.moveTo(startWidth, 0);
        path.lineTo(0, 0);
        path.lineTo(0, height);
        path.lineTo(startWidth, height);
        if (reboundOffset != null) {
          path.quadraticBezierTo(
            (reboundOffset! - actualTriggerOffset) * 2 + actualTriggerOffset,
            height / 2,
            startWidth,
            0,
          );
        } else if (width <= actualTriggerOffset) {
          path.lineTo(startWidth, 0);
        } else {
          path.quadraticBezierTo(
            width + (width - actualTriggerOffset),
            height / 2,
            startWidth,
            0,
          );
        }
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return oldClipper != this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BezierPainter &&
          runtimeType == other.runtimeType &&
          axis == other.axis &&
          reverse == other.reverse &&
          offset == other.offset &&
          actualTriggerOffset == other.actualTriggerOffset &&
          reboundOffset == other.reboundOffset;

  @override
  int get hashCode =>
      axis.hashCode ^
      reverse.hashCode ^
      offset.hashCode ^
      actualTriggerOffset.hashCode ^
      reboundOffset.hashCode;
}
