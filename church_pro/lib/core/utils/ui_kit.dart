import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Keeps content readable on wide Windows screens.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 1100});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

/// A band of small diamonds, inspired by East African cloth patterns.
/// Used sparingly: the signature of the app.
class PatternBand extends StatelessWidget {
  const PatternBand({super.key, this.height = 16, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _DiamondBandPainter(color ?? AppColors.gold.withValues(alpha: 0.8))),
      );
}

class _DiamondBandPainter extends CustomPainter {
  _DiamondBandPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = h * 1.25;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cy = h / 2;
    final r = h * 0.15;

    for (double x = 0; x < size.width + w; x += w) {
      final cx = x + w / 2;
      final diamond = Path()
        ..moveTo(cx, 1)
        ..lineTo(cx + w / 2 - 1, cy)
        ..lineTo(cx, h - 1)
        ..lineTo(cx - w / 2 + 1, cy)
        ..close();
      canvas.drawPath(diamond, outline);
      final dot = Path()
        ..moveTo(cx, cy - r)
        ..lineTo(cx + r, cy)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - r, cy)
        ..close();
      canvas.drawPath(dot, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _DiamondBandPainter old) => old.color != color;
}

/// Rounded-square initial, used instead of a plain circle.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key, this.size = 40, this.onDark = false});

  final String name;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onDark ? AppColors.gold : AppColors.forest,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: onDark ? AppColors.ink : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.44,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// The top of a page: a deep green panel with the cloth band along its foot.
class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.title, this.subtitle, this.pills = const [], this.child});

  final String title;
  final String? subtitle;
  final List<String> pills;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: AppColors.forestDeep,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.headlineSmall?.copyWith(color: Colors.white, fontSize: 26)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: t.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.78))),
                  ],
                  if (pills.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [for (final p in pills) _Pill(p)]),
                  ],
                  if (child != null) ...[const SizedBox(height: 16), child!],
                ],
              ),
            ),
            const PatternBand(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Section heading in plain sentence case.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ]),
      );
}

TextStyle? moneyStyle(BuildContext context, {Color? color}) => Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class Figure {
  const Figure(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;
}

/// Several numbers side by side in ONE panel, separated by hairlines.
class FigureStrip extends StatelessWidget {
  const FigureStrip({super.key, required this.figures});

  final List<Figure> figures;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < figures.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: scheme.outlineVariant),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(figures[i].label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: muted)),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(figures[i].value, style: moneyStyle(context, color: figures[i].color)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A row that tells the user what needs doing, with a coloured edge.
class AttentionRow extends StatelessWidget {
  const AttentionRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.62);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 5, color: color),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Icon(icon, color: color)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleSmall),
                        if (subtitle != null)
                          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
                      ],
                    ),
                  ),
                ),
                if (onTap != null)
                  Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.chevron_right, color: muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: muted),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(message, style: TextStyle(color: muted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
