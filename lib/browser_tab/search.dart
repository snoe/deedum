import 'dart:convert';
// ignore: unused_import
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class SearchAlert extends StatefulWidget {
  final void Function(Uri) onLocation;

  final String prompt;
  final Uri uri;

  final TextEditingController searchController = TextEditingController();

  SearchAlert(
      {Key? key,
      required this.prompt,
      required this.uri,
      required this.onLocation})
      : super(key: key);

  @override
  SearchAlertState createState() => SearchAlertState();
}

class SearchAlertState extends State<SearchAlert> {
  bool _inputError = false;
  int _inputLength = 0;
  Uri? _newLocation;

  _inputSubmitted(value) {
    if (!_inputError) {
      widget.onLocation(_newLocation!);
      Navigator.of(context).pop();
    }
  }

  _inputChanged(value) {
    String? encodedSearch;
    if (value != null) {
      encodedSearch = Uri.encodeComponent(value);
    }

    Uri u = Uri(
        scheme: widget.uri.scheme,
        host: widget.uri.host,
        port: widget.uri.port,
        path: widget.uri.path,
        query: encodedSearch);

    var bytes = const Utf8Encoder().convert(u.toString());
    var length = bytes.lengthInBytes;
    setState(() {
      _inputError = length > 1024;
      _newLocation = u;
      _inputLength = length;
    });
  }

  @override
  void initState() {
    super.initState();
    _inputChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    var focusNode = FocusNode();
    focusNode.requestFocus();
    return AlertDialog(
      title: const Text('Input requested'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(widget.prompt),
            DecoratedBox(
              decoration:
                  BoxDecoration(color: _inputError ? Colors.deepOrange : null),
              child: TextField(
                  focusNode: focusNode,
                  controller: widget.searchController,
                  onChanged: _inputChanged,
                  onSubmitted: _inputSubmitted),
            ),
            Text(_inputError
                ? "Input too long by ${_inputLength - 1024} bytes."
                : "${1024 - _inputLength} bytes remaining."),
          ]),
      actions: <Widget>[
        TextButton(
            onPressed: () {
              _inputSubmitted(widget.searchController.text);
            },
            child: const Text('Submit')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
