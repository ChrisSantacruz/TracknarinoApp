import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OperationalSvgIcon extends StatelessWidget {
  final String icon;
  final Color color;
  final double size;
  final String? semanticsLabel;

  const OperationalSvgIcon(
    this.icon, {
    super.key,
    required this.color,
    this.size = 20,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      icon,
      width: size,
      height: size,
      color: color,
      semanticsLabel: semanticsLabel,
    );
  }
}

abstract final class OperationalSvgIcons {
  static const activity = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M22 12H18L15 21L9 3L6 12H2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const alertTriangle = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M10.3 4.1L2.8 17.1C2.1 18.3 3 20 4.5 20H19.5C21 20 21.9 18.3 21.2 17.1L13.7 4.1C13 2.9 11 2.9 10.3 4.1Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
  <path d="M12 9V13" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M12 17H12.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

  static const bell = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M18 8A6 6 0 0 0 6 8C6 15 3 16 3 16H21C21 16 18 15 18 8Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M13.7 21A2 2 0 0 1 10.3 21" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

  static const checkCircle = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M22 11.1V12A10 10 0 1 1 16.1 2.9" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M22 4L12 14.01L9 11.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const chevronRight = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M9 18L15 12L9 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const clock = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
  <path d="M12 6V12L16 14" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const cloudOff = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M2 2L22 22" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M10.6 5.1A7 7 0 0 1 19 12H20A4 4 0 0 1 21.2 19.8M16 19H7A5 5 0 0 1 5.1 9.4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const cloudUpload = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M16 16L12 12L8 16" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M12 12V21" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M20.4 18.4A5 5 0 0 0 18 9H16.7A8 8 0 1 0 4 16.3" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const database = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="12" cy="5" rx="9" ry="3" stroke="currentColor" stroke-width="2"/>
  <path d="M3 5V19C3 20.7 7 22 12 22C17 22 21 20.7 21 19V5" stroke="currentColor" stroke-width="2"/>
  <path d="M3 12C3 13.7 7 15 12 15C17 15 21 13.7 21 12" stroke="currentColor" stroke-width="2"/>
</svg>
''';

  static const logOut = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M9 21H5A2 2 0 0 1 3 19V5A2 2 0 0 1 5 3H9" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M16 17L21 12L16 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M21 12H9" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

  static const mapPin = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M20 10C20 15.5 12 22 12 22C12 22 4 15.5 4 10A8 8 0 1 1 20 10Z" stroke="currentColor" stroke-width="2"/>
  <circle cx="12" cy="10" r="3" stroke="currentColor" stroke-width="2"/>
</svg>
''';

  static const radio = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M4.9 19.1C1 15.2 1 8.8 4.9 4.9M19.1 4.9C23 8.8 23 15.2 19.1 19.1M8.5 15.5C6.6 13.6 6.6 10.4 8.5 8.5M15.5 8.5C17.4 10.4 17.4 13.6 15.5 15.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <circle cx="12" cy="12" r="1.8" fill="currentColor"/>
</svg>
''';

  static const refreshCw = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M21 2V8H15" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M3 12A9 9 0 0 1 18.4 5.6L21 8" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M3 22V16H9" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M21 12A9 9 0 0 1 5.6 18.4L3 16" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const route = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="6" cy="19" r="3" stroke="currentColor" stroke-width="2"/>
  <circle cx="18" cy="5" r="3" stroke="currentColor" stroke-width="2"/>
  <path d="M12 19H14A4 4 0 0 0 14 11H10A4 4 0 0 1 10 3H12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';

  static const shieldCheck = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 22C12 22 20 18 20 12V5L12 2L4 5V12C4 18 12 22 12 22Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
  <path d="M9 12L11 14L15.5 9.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

  static const truck = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M10 17H14V5H2V17H5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M14 8H18L22 12V17H20" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="7.5" cy="17.5" r="2.5" stroke="currentColor" stroke-width="2"/>
  <circle cx="17.5" cy="17.5" r="2.5" stroke="currentColor" stroke-width="2"/>
</svg>
''';

  static const wifiOff = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M2 2L22 22" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M8.5 16.5A5 5 0 0 1 15.5 16.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M5 13A10 10 0 0 1 12 10C14.1 10 16 10.6 17.6 11.7" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M2 8.5A15 15 0 0 1 12 5C16.1 5 19.8 6.6 22.5 9.2" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
  <path d="M12 20H12.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
</svg>
''';
}
