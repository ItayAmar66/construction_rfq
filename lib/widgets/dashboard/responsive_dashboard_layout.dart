import 'package:flutter/material.dart';

/// Breakpoints and compact grid metrics (RTL-safe).
class DashboardLayoutMetrics {
  DashboardLayoutMetrics._({
    required this.crossAxisCount,
    required this.spacing,
    required this.kpiCellHeight,
    required this.fullWidthKpiHeight,
    required this.chartPlotHeight,
    required this.pieChartHeight,
    required this.horizontalPadding,
  });

  final int crossAxisCount;
  final double spacing;
  final double kpiCellHeight;
  final double fullWidthKpiHeight;
  final double chartPlotHeight;
  final double pieChartHeight;
  final double horizontalPadding;

  static const double _narrowBreakpoint = 360;
  static const double _spacing = 10;

  factory DashboardLayoutMetrics.fromWidth(double width) {
    final padding = width < _narrowBreakpoint ? 12.0 : 16.0;
    final contentWidth = width - padding * 2;
    final crossAxisCount = contentWidth < _narrowBreakpoint ? 1 : 2;
    final cellWidth = crossAxisCount == 1
        ? contentWidth
        : (contentWidth - _spacing) / 2;

    // Fixed row height — avoids aspect-ratio overflow in KPI grid.
    final kpiCellHeight = _kpiHeightForWidth(cellWidth, hasSubtitle: false);
    final fullWidthKpiHeight = _kpiHeightForWidth(contentWidth, hasSubtitle: true);

    final chartPlotHeight = (contentWidth * 0.26).clamp(96.0, 120.0);
    final pieChartHeight = (contentWidth * 0.24).clamp(88.0, 112.0);

    return DashboardLayoutMetrics._(
      crossAxisCount: crossAxisCount,
      spacing: _spacing,
      kpiCellHeight: kpiCellHeight,
      fullWidthKpiHeight: fullWidthKpiHeight,
      chartPlotHeight: chartPlotHeight,
      pieChartHeight: pieChartHeight,
      horizontalPadding: padding,
    );
  }

  /// Compact but tall enough for readable KPI type (+ subtitle when needed).
  static double _kpiHeightForWidth(double width, {required bool hasSubtitle}) {
    if (hasSubtitle) {
      return 88.0;
    }
    return (width * 0.50).clamp(92.0, 104.0);
  }
}

class ResponsiveKpiGrid extends StatelessWidget {
  const ResponsiveKpiGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = DashboardLayoutMetrics.fromWidth(constraints.maxWidth);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.crossAxisCount,
            crossAxisSpacing: metrics.spacing,
            mainAxisSpacing: metrics.spacing,
            mainAxisExtent: metrics.kpiCellHeight,
          ),
          itemCount: children.length,
          itemBuilder: (_, i) => children[i],
        );
      },
    );
  }
}

class ResponsiveKpiRow extends StatelessWidget {
  const ResponsiveKpiRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = DashboardLayoutMetrics.fromWidth(constraints.maxWidth);

        if (metrics.crossAxisCount == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: metrics.spacing),
                SizedBox(
                  height: metrics.fullWidthKpiHeight,
                  child: children[i],
                ),
              ],
            ],
          );
        }

        final rowHeight = metrics.kpiCellHeight < metrics.fullWidthKpiHeight
            ? metrics.fullWidthKpiHeight
            : metrics.kpiCellHeight;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: metrics.spacing),
              Expanded(
                child: SizedBox(
                  height: rowHeight,
                  child: children[i],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class ResponsiveFullWidthKpi extends StatelessWidget {
  const ResponsiveFullWidthKpi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = DashboardLayoutMetrics.fromWidth(constraints.maxWidth);
        return SizedBox(
          height: metrics.fullWidthKpiHeight,
          child: child,
        );
      },
    );
  }
}

class DashboardScrollBody extends StatelessWidget {
  const DashboardScrollBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = DashboardLayoutMetrics.fromWidth(constraints.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            metrics.horizontalPadding,
            10,
            metrics.horizontalPadding,
            metrics.horizontalPadding >= 16 ? 24 : 96,
          ),
          children: children,
        );
      },
    );
  }
}
