import 'dart:typed_data';

class ContentData {
  final Uint8List _bytes;
  final String _content;
  final String _mode;
  ContentData({String content, String mode, Uint8List bytes})
      : _content = content,
        _mode = mode,
        _bytes = bytes;

  Uint8List get bytes => _bytes;
  String get mode => _mode;
  String get content => _content;
}

double get padding => 25.0;
