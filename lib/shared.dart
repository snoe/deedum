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

extension CollectionUtil<T> on Iterable<T>  {

  Iterable<E> mapIndexed<E, T>(E Function(int index, T item) transform) sync* {
    var index = 0;

    for (final item in this) {
      yield transform(index, item as T);
      index++;
    }
  }
}