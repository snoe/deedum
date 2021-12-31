// ignore: unused_import
import 'dart:developer';

import 'package:deedum/models/app_state.dart';
import 'package:deedum/models/identity.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/material.dart';
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

class ClientCertAddAlert extends ConsumerWidget {
  final void Function(String,
      {Uri? uri,
      String? existingCertString,
      String? existingPrivateKeyString}) createIdentity;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState> nameKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> certKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> privateKeyKey = GlobalKey<FormFieldState>();

  ClientCertAddAlert({Key? key, required this.createIdentity})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    return AlertDialog(
      title: const Text('Create identity'),
      scrollable: true,
      content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.always,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  key: nameKey,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a name';
                    } else if (appState.identities
                            .firstOrNull((p0) => p0.name == value) !=
                        null) {
                      return "Name must be unique";
                    }
                    return null;
                  },
                  decoration: const InputDecoration(hintText: 'Name'),
                ),
                Column(
                  children: [
                    TextFormField(
                      key: certKey,
                      decoration:
                          const InputDecoration(hintText: 'Certificate'),
                      keyboardType: TextInputType.multiline,
                      maxLines: 3,
                      validator: (certString) {
                        var privateKeyString =
                            privateKeyKey.currentState!.value;
                        var privateKeyEmpty = privateKeyString == null ||
                            privateKeyString.isEmpty;
                        var certEmpty =
                            certString == null || certString.isEmpty;
                        if (!privateKeyEmpty && certEmpty) {
                          return 'Enter cert or clear private key';
                        } else if (!privateKeyEmpty &&
                            !certEmpty &&
                            !Identity.validateCert(certString)) {
                          return "Bad cert";
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      key: privateKeyKey,
                      keyboardType: TextInputType.multiline,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(hintText: 'Private Key'),
                      validator: (privateKeyString) {
                        var certString = certKey.currentState!.value;
                        var certEmpty =
                            certString == null || certString.isEmpty;
                        var privateKeyEmpty = privateKeyString == null ||
                            privateKeyString.isEmpty;
                        if (!certEmpty && privateKeyEmpty) {
                          return 'Enter private key or clear cert';
                        } else if (!certEmpty &&
                            !privateKeyEmpty &&
                            !Identity.validatePrivateKey(privateKeyString)) {
                          return "Bad RSA private key";
                        }
                        return null;
                      },
                    )
                  ],
                )
              ])),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                createIdentity(nameKey.currentState!.value,
                    existingCertString: trimToNull(certKey.currentState!.value),
                    existingPrivateKeyString:
                        trimToNull(privateKeyKey.currentState?.value));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Submit')),
      ],
    );
  }
}
