import 'dart:io';

/// True for a dart:io socket failure (mobile and desktop builds).
bool isSocketException(Object error) => error is SocketException;
