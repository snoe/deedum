import 'package:flutter/material.dart';

abstract class DirectoryElement extends StatelessWidget {
  String get title;

  const DirectoryElement({Key key}) : super(key: key);
}
