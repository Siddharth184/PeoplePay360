import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppLogoIcon extends StatelessWidget {
  final double size;
  const AppLogoIcon({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _buildFallbackVectorIcon(size),
    );
  }

  Widget _buildFallbackVectorIcon(double s) {
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(
        painter: _PeoplePayLogoPainter(),
      ),
    );
  }
}

class _PeoplePayLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    // Teal Outer Interlaced Loops
    final tealPaint = Paint()
      ..color = const Color(0xFF00696E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;

    final path1 = Path();
    path1.addOval(Rect.fromCircle(center: Offset(center.dx - radius * 0.15, center.dy), radius: radius * 0.7));
    canvas.drawPath(path1, tealPaint);

    final path2 = Path();
    path2.addOval(Rect.fromCircle(center: Offset(center.dx + radius * 0.15, center.dy), radius: radius * 0.7));
    canvas.drawPath(path2, tealPaint);

    // Purple P
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'P',
        style: GoogleFonts.outfit(
          fontSize: size.width * 0.52,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF57344F),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showText;
  final Color? textColor;

  const AppLogo({
    super.key,
    this.iconSize = 36,
    this.fontSize = 20,
    this.showText = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppLogoIcon(size: iconSize),
        if (showText) ...[
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'PeoplePay',
                  style: GoogleFonts.outfit(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: textColor ?? const Color(0xFF57344F),
                    letterSpacing: -0.3,
                  ),
                ),
                TextSpan(
                  text: '360',
                  style: GoogleFonts.outfit(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00696E),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
