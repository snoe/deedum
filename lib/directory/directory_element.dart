import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class DirectoryElement extends ConsumerWidget {
  String get title;

  const DirectoryElement({Key? key}) : super(key: key);
}
