import 'dart:io' show Platform;

bool get isNativeDesktopPlatform => Platform.isMacOS || Platform.isWindows;
