import 'package:flutter/material.dart';

/// Custom text widget that creates wide, spaced text while ensuring
/// the parent component recognizes the actual transformed width
class WideText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double letterSpacing;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;
  final double? scaleX; // Optional horizontal scaling

  const WideText({
    Key? key,
    required this.text,
    required this.style,
    this.letterSpacing = 2.0,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign = TextAlign.left,
    this.scaleX,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If we have horizontal scaling, we need to account for it in our layout calculations
        final effectiveMaxWidth = scaleX != null 
            ? constraints.maxWidth / scaleX! 
            : constraints.maxWidth;
        
        // Create the text style with letter spacing
        final effectiveStyle = style.copyWith(letterSpacing: letterSpacing);
        
        // Measure the text with the applied transformations
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
          textAlign: textAlign,
        );
        
        // Layout with the effective width (accounting for scaling)
        textPainter.layout(maxWidth: effectiveMaxWidth);
        
        // Calculate actual final width including horizontal scaling
        final baseWidth = textPainter.width;
        final scaledWidth = scaleX != null ? baseWidth * scaleX! : baseWidth;
        final finalWidth = scaledWidth.clamp(0.0, constraints.maxWidth);
        
        // Use CustomPaint to properly render scaled text within constraints
        return SizedBox(
          width: finalWidth,
          height: textPainter.height,
          child: CustomPaint(
            painter: WideTextPainter(
              text: text,
              style: effectiveStyle,
              scaleX: scaleX ?? 1.0,
              maxWidth: effectiveMaxWidth,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: textAlign,
            ),
            size: Size(finalWidth, textPainter.height),
          ),
        );
      },
    );
  }
}

/// Extension for easier wide text creation
extension TextStyleWide on TextStyle {
  /// Creates a WideText widget with this style
  WideText wide(
    String text, {
    double letterSpacing = 2.0,
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
    TextAlign textAlign = TextAlign.left,
    double? scaleX,
  }) {
    return WideText(
      text: text,
      style: this,
      letterSpacing: letterSpacing,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      scaleX: scaleX,
    );
  }
}

/// Constraint-aware text widget that properly measures transformed text
class ConstraintAwareText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double letterSpacing;
  final double? scaleX;
  final double? scaleY;
  final int? maxLines;
  final TextOverflow overflow;

  const ConstraintAwareText({
    Key? key,
    required this.text,
    required this.style,
    this.letterSpacing = 0.0,
    this.scaleX,
    this.scaleY,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: ConstraintAwareTextPainter(
            text: text,
            style: style.copyWith(letterSpacing: letterSpacing),
            constraints: constraints,
            scaleX: scaleX ?? 1.0,
            scaleY: scaleY ?? 1.0,
            maxLines: maxLines,
          ),
          size: _calculateSize(constraints),
        );
      },
    );
  }

  Size _calculateSize(BoxConstraints constraints) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(letterSpacing: letterSpacing)),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );
    
    textPainter.layout(maxWidth: constraints.maxWidth);
    
    double width = textPainter.width * (scaleX ?? 1.0);
    double height = textPainter.height * (scaleY ?? 1.0);
    
    return Size(
      width.clamp(0.0, constraints.maxWidth),
      height.clamp(0.0, constraints.maxHeight),
    );
  }
}

/// Custom painter for constraint-aware text rendering
class ConstraintAwareTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final BoxConstraints constraints;
  final double scaleX;
  final double scaleY;
  final int? maxLines;

  ConstraintAwareTextPainter({
    required this.text,
    required this.style,
    required this.constraints,
    required this.scaleX,
    required this.scaleY,
    this.maxLines,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );

    textPainter.layout(maxWidth: constraints.maxWidth / scaleX);

    canvas.save();
    canvas.scale(scaleX, scaleY);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! ConstraintAwareTextPainter ||
        oldDelegate.text != text ||
        oldDelegate.style != style ||
        oldDelegate.scaleX != scaleX ||
        oldDelegate.scaleY != scaleY;
  }
}

/// Custom painter for WideText that properly handles scaling within constraints
class WideTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final double scaleX;
  final double maxWidth;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  WideTextPainter({
    required this.text,
    required this.style,
    required this.scaleX,
    required this.maxWidth,
    this.maxLines,
    required this.overflow,
    required this.textAlign,
  });

  @override
  void paint(Canvas canvas, Size size) {
    String displayText = text;
    
    // Test if the full text fits within the constraints
    final testPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      textAlign: textAlign,
    );
    testPainter.layout(maxWidth: maxWidth);
    
    // Check if text overflows after scaling
    bool needsEllipsis = testPainter.didExceedMaxLines || 
                        (testPainter.width * scaleX > size.width);
    
    if (needsEllipsis && overflow == TextOverflow.ellipsis) {
      // Find the maximum text that fits with ellipsis using multi-line layout
      final ellipsisWidth = _measureText('...', style);
      
      // Binary search to find the longest text that fits
      int start = 0;
      int end = text.length;
      String bestFit = '';
      
      while (start <= end) {
        int mid = (start + end) ~/ 2;
        String candidate = text.substring(0, mid) + '...';
        
        final candidatePainter = TextPainter(
          text: TextSpan(text: candidate, style: style),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
          textAlign: textAlign,
        );
        candidatePainter.layout(maxWidth: maxWidth);
        
        // Check if it fits both in lines and width after scaling
        bool fits = !candidatePainter.didExceedMaxLines && 
                   (candidatePainter.width * scaleX <= size.width);
        
        if (fits) {
          bestFit = text.substring(0, mid);
          start = mid + 1;
        } else {
          end = mid - 1;
        }
      }
      
      displayText = bestFit + '...';
    }

    final textPainter = TextPainter(
      text: TextSpan(text: displayText, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      textAlign: textAlign,
    );

    // Layout with the effective width (pre-scaling)
    textPainter.layout(maxWidth: maxWidth);

    // Apply scaling and paint
    canvas.save();
    canvas.scale(scaleX, 1.0);
    
    // Handle text alignment within the scaled space
    double xOffset = 0.0;
    if (textAlign == TextAlign.center) {
      xOffset = (maxWidth - textPainter.width) / 2;
    } else if (textAlign == TextAlign.right) {
      xOffset = maxWidth - textPainter.width;
    }
    
    textPainter.paint(canvas, Offset(xOffset, 0));
    canvas.restore();
  }
  
  double _measureText(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.width;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! WideTextPainter ||
        oldDelegate.text != text ||
        oldDelegate.style != style ||
        oldDelegate.scaleX != scaleX ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.maxLines != maxLines ||
        oldDelegate.overflow != overflow ||
        oldDelegate.textAlign != textAlign;
  }
}