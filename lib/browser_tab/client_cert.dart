// ignore: unused_import
import 'dart:developer';

import 'package:deedum/app_state.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClientCertAlert extends ConsumerStatefulWidget {
  final String prompt;
  final Uri uri;

  final TextEditingController searchController = TextEditingController();

  ClientCertAlert({Key? key, required this.prompt, required this.uri})
      : super(key: key);

  @override
  ClientCertAlertState createState() => ClientCertAlertState();
}

class ClientCertAlertState extends ConsumerState<ClientCertAlert> {
  Identity? selectedIdentity;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var focusNode = FocusNode();
    focusNode.requestFocus();
    var appState = ref.watch(appStateProvider);
    return AlertDialog(
      title: const Text('Input requested'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(widget.prompt),
            DropdownButton(
                value: selectedIdentity,
                icon: const Icon(Icons.keyboard_arrow_down),
                onChanged: (Identity? e) {
                  setState(() {
                    selectedIdentity = e;
                  });
                },
                items: appState.identities.map((Identity id) {
                  return DropdownMenuItem(
                    value: id,
                    child: Text(id.name),
                  );
                }).toList())
          ]),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
            onPressed: selectedIdentity != null
                ? () {
                    Navigator.of(context).pop(selectedIdentity);
                  }
                : null,
            child: const Text('Submit')),
      ],
    );
  }
}

class ClientCertAddAlert extends StatelessWidget {
  final void Function(String, {Uri? uri}) createIdentity;
  final TextEditingController controller = TextEditingController();

  ClientCertAddAlert({Key? key, required this.createIdentity})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Input requested'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(controller: controller),
          ]),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
            onPressed: () {
              createIdentity(controller.text);

              Navigator.of(context).pop();
            },
            child: const Text('Submit')),
      ],
    );
  }
}
