import 'dart:math' show pi, cos, sin, sqrt, atan2, min;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/contributor.dart';
import '../../logic/connections_models.dart';
import '../../logic/chordlink_graph_logic.dart';
import '../../logic/sankey_graph_logic.dart' show limitPersons, roleColor;

/// ChordLink circular diagram visualization for the "All Connections" tab.
class ConnectionsGraphView extends StatefulWidget {
  final List<UnfollowedPersonGroup> groups;
  final ConnectionsData? connectionsData;
  final List<Contributor>? contributors;

  const ConnectionsGraphView({
    super.key,
    required this.groups,
    this.connectionsData,
    this.contributors,
  });

  @override
  State<ConnectionsGraphView> createState() => _ConnectionsGraphViewState();
}

class _ConnectionsGraphViewState extends State<ConnectionsGraphView> {
  ChordLinkLayoutMode _layoutMode = ChordLinkLayoutMode.peopleAndWorks;
  String? _selectedNodeId;
  bool _legendExpanded = true;

  bool get _canUseFullBridge =>
      widget.connectionsData != null && widget.contributors != null;

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) {
      return const Center(
        child: Text('No unfollowed connections to visualize'),
      );
    }

    final limitedGroups = limitPersons(widget.groups, 25);
    if (limitedGroups.length < 2) {
      return const Center(
        child: Text('Not enough connections for a diagram view'),
      );
    }

    return Column(
      children: [
        _buildModeToggle(),
        _buildLimitLabels(),
        Expanded(child: _buildDiagram()),
        _buildLegend(),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SegmentedButton<ChordLinkLayoutMode>(
        segments: [
          const ButtonSegment(
            value: ChordLinkLayoutMode.peopleAndWorks,
            label: Text('People & Works'),
          ),
          ButtonSegment(
            value: ChordLinkLayoutMode.fullBridge,
            label: const Text('Full Bridge'),
            enabled: _canUseFullBridge,
          ),
        ],
        selected: {_layoutMode},
        onSelectionChanged: (selected) {
          setState(() {
            _layoutMode = selected.first;
            _selectedNodeId = null;
          });
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildLimitLabels() {
    final layout =
        buildChordLinkModeA(widget.groups, Theme.of(context).colorScheme);
    final labels = <String>[];
    if (layout.personsLimited) {
      labels.add('Showing top 25 of ${layout.totalPersons} people');
    }
    if (layout.worksLimited) {
      labels.add('Showing top 20 of ${layout.totalWorks} works');
    }
    if (labels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Text(
        labels.join(' · '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildDiagram() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colorScheme = Theme.of(context).colorScheme;

        try {
          final ChordLinkLayout layout;
          if (_layoutMode == ChordLinkLayoutMode.fullBridge &&
              _canUseFullBridge) {
            layout = buildChordLinkModeB(
              widget.groups,
              widget.connectionsData!,
              widget.contributors!,
              colorScheme,
            );
          } else {
            layout = buildChordLinkModeA(widget.groups, colorScheme);
          }

          if (layout.arcs.isEmpty) {
            return const Center(child: Text('No data to display'));
          }

          final radius = computeRadius(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          final size = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: GestureDetector(
              onTapUp: (details) {
                final center = Offset(size.width / 2, size.height / 2);
                final nodeId = hitTestNode(
                  details.localPosition,
                  layout,
                  center,
                  radius,
                );
                setState(() {
                  _selectedNodeId =
                      nodeId == _selectedNodeId ? null : nodeId;
                });
              },
              child: CustomPaint(
                size: size,
                painter: ChordLinkPainter(
                  layout: layout,
                  radius: radius,
                  selectedNodeId: _selectedNodeId,
                  brightness: Theme.of(context).brightness,
                ),
              ),
            ),
          );
        } catch (e) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 8),
                const Text('Unable to render diagram'),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildLegend() {
    final colorScheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      title: const Text('Legend'),
      initiallyExpanded: _legendExpanded,
      onExpansionChanged: (expanded) {
        setState(() => _legendExpanded = expanded);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legendItem('Director', roleColor(0)),
              _legendItem('Creator', roleColor(1)),
              _legendItem('Writer', roleColor(2)),
              _legendItem('Producer', roleColor(3)),
              _legendItem('Lead Cast', roleColor(4)),
              _legendItem('Cast', roleColor(5)),
              _legendItem('Composer', roleColor(6)),
              _legendItem('Crew', roleColor(7)),
              _legendItem('Movie', colorScheme.tertiary),
              _legendItem('TV Show', Colors.cyan),
              if (_layoutMode == ChordLinkLayoutMode.fullBridge)
                _legendItem('Contributor', colorScheme.primary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ChordLinkPainter — CustomPainter for the circular diagram
// ---------------------------------------------------------------------------

/// Arc thickness in logical pixels.
const arcThickness = 16.0;

class ChordLinkPainter extends CustomPainter {
  final ChordLinkLayout layout;
  final double radius;
  final String? selectedNodeId;
  final Brightness brightness;

  ChordLinkPainter({
    required this.layout,
    required this.radius,
    required this.selectedNodeId,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final hasSelection = selectedNodeId != null;

    // Collect nodeIds connected to the selected node.
    final connectedNodeIds = <String>{};
    if (hasSelection) {
      connectedNodeIds.add(selectedNodeId!);
      for (final chord in layout.chords) {
        if (chord.sourceNodeId == selectedNodeId ||
            chord.targetNodeId == selectedNodeId) {
          connectedNodeIds.add(chord.sourceNodeId);
          connectedNodeIds.add(chord.targetNodeId);
        }
      }
    }

    // Draw chords first (behind arcs).
    for (final chord in layout.chords) {
      final isConnected = !hasSelection ||
          chord.sourceNodeId == selectedNodeId ||
          chord.targetNodeId == selectedNodeId;
      final opacity = hasSelection ? (isConnected ? 0.6 : 0.05) : 0.4;

      final sourcePoint = _angleToPoint(chord.sourceAngle, radius, center);
      final targetPoint = _angleToPoint(chord.targetAngle, radius, center);

      // Cubic Bézier through center area.
      final controlStrength = radius * 0.3;
      final cp1 = Offset(
        center.dx + (sourcePoint.dx - center.dx) * 0.3,
        center.dy + (sourcePoint.dy - center.dy) * 0.3,
      );
      final cp2 = Offset(
        center.dx + (targetPoint.dx - center.dx) * 0.3,
        center.dy + (targetPoint.dy - center.dy) * 0.3,
      );

      final path = Path()
        ..moveTo(sourcePoint.dx, sourcePoint.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, targetPoint.dx,
            targetPoint.dy);

      // Gradient from source to target color.
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = min(chord.weight, 4.0)
        ..shader = ui.Gradient.linear(
          sourcePoint,
          targetPoint,
          [
            chord.sourceColor.withValues(alpha: opacity),
            chord.targetColor.withValues(alpha: opacity),
          ],
        );

      canvas.drawPath(path, paint);
    }

    // Draw arcs.
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    for (final arc in layout.arcs) {
      final isConnected =
          !hasSelection || connectedNodeIds.contains(arc.nodeId);
      final opacity = hasSelection ? (isConnected ? 1.0 : 0.1) : 1.0;

      final paint = Paint()
        ..color = arc.color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcThickness
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(arcRect, arc.startAngle, arc.sweepAngle, false, paint);
    }

    // Draw cluster labels outside the circle.
    final textColor = brightness == Brightness.dark
        ? Colors.white70
        : Colors.black87;
    for (final entry in layout.clusterSpans.entries) {
      final cluster = entry.key;
      final span = entry.value;
      final midAngle = span.startAngle + span.sweepAngle / 2;
      final labelRadius = radius + arcThickness + 16;
      final labelPoint = _angleToPoint(midAngle, labelRadius, center);

      final label = switch (cluster) {
        ClusterType.people => 'People',
        ClusterType.works => 'Works',
        ClusterType.contributors => 'Contributors',
      };

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: textColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        labelPoint - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // Draw selected node tooltip.
    if (selectedNodeId != null) {
      final selectedArcs =
          layout.arcs.where((a) => a.nodeId == selectedNodeId);
      final labeledArc = selectedArcs
          .cast<ChordLinkArc?>()
          .firstWhere((a) => a!.label != null, orElse: () => null);
      if (labeledArc != null && labeledArc.label != null) {
        final midAngle =
            labeledArc.startAngle + labeledArc.sweepAngle / 2;
        final tooltipRadius = radius + arcThickness + 30;
        final tooltipPoint =
            _angleToPoint(midAngle, tooltipRadius, center);

        final tp = TextPainter(
          text: TextSpan(
            text: labeledArc.label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // Background for readability.
        final bgRect = Rect.fromCenter(
          center: tooltipPoint,
          width: tp.width + 12,
          height: tp.height + 6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
          Paint()
            ..color = (brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white)
                .withValues(alpha: 0.8),
        );
        tp.paint(
          canvas,
          tooltipPoint - Offset(tp.width / 2, tp.height / 2),
        );
      }
    }
  }

  Offset _angleToPoint(double angle, double r, Offset center) {
    return Offset(
      center.dx + r * cos(angle),
      center.dy + r * sin(angle),
    );
  }

  @override
  bool shouldRepaint(ChordLinkPainter oldDelegate) =>
      layout != oldDelegate.layout ||
      selectedNodeId != oldDelegate.selectedNodeId ||
      radius != oldDelegate.radius;
}

// ---------------------------------------------------------------------------
// Hit testing
// ---------------------------------------------------------------------------

/// Given a tap position relative to the widget, determines which node (if any)
/// was tapped by checking if the tap falls within the arc ring and within
/// any arc's angular range.
String? hitTestNode(
  Offset tapPosition,
  ChordLinkLayout layout,
  Offset center,
  double radius,
) {
  final dx = tapPosition.dx - center.dx;
  final dy = tapPosition.dy - center.dy;
  final distance = sqrt(dx * dx + dy * dy);

  // Check if tap is within the arc ring.
  final innerRadius = radius - arcThickness / 2;
  final outerRadius = radius + arcThickness / 2;
  if (distance < innerRadius || distance > outerRadius) return null;

  // Compute tap angle (0 to 2π).
  var angle = atan2(dy, dx);
  if (angle < 0) angle += 2 * pi;

  // Find which arc contains this angle.
  for (final arc in layout.arcs) {
    var start = arc.startAngle % (2 * pi);
    if (start < 0) start += 2 * pi;
    final end = start + arc.sweepAngle;

    if (angle >= start && angle <= end) return arc.nodeId;
    // Handle wrap-around.
    if (end > 2 * pi && angle <= end - 2 * pi) return arc.nodeId;
  }

  return null;
}
