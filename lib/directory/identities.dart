import 'package:deedum/models/app_state.dart';
import 'package:deedum/browser_tab/client_cert.dart';
import 'package:deedum/directory/directory_element.dart';
import 'package:deedum/directory/gem_item.dart';
import 'package:deedum/next/app.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Identities extends DirectoryElement {
  const Identities({
    Key? key,
  }) : super(key: key);

  @override
  String get title => [
        "██╗██████╗ ███████╗███╗   ██╗████████╗██╗████████╗██╗███████╗███████╗",
        "██║██╔══██╗██╔════╝████╗  ██║╚══██╔══╝██║╚══██╔══╝██║██╔════╝██╔════╝",
        "██║██║  ██║█████╗  ██╔██╗ ██║   ██║   ██║   ██║   ██║█████╗  ███████╗",
        "██║██║  ██║██╔══╝  ██║╚██╗██║   ██║   ██║   ██║   ██║██╔══╝  ╚════██║",
        "██║██████╔╝███████╗██║ ╚████║   ██║   ██║   ██║   ██║███████╗███████║",
        "╚═╝╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝   ╚═╝   ╚═╝╚══════╝╚══════╝",
      ].join("\n");

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            color: Theme.of(context).buttonTheme.colorScheme!.primary,
            child: ListTile(
              onTap: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return ClientCertAddAlert(
                          createIdentity: appState.createIdentity);
                    });
              },
              leading: const Icon(Icons.person_add, color: Colors.white),
              title: const Text("Add new identity",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          for (final identity in appState.identities)
            Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.person), onPressed: () {}),
                        Expanded(
                            flex: 1,
                            child: ListTile(
                                contentPadding: const EdgeInsets.only(left: 20),
                                dense: true,
                                title: Text(identity.name,
                                    style: const TextStyle(fontSize: 14)),
                                subtitle: Text("${identity.subject}"))),
                        IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () {
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                        title: Column(children: [
                                          TextButton(
                                              child: const Text("Copy cert"),
                                              onPressed: () async {
                                                await Clipboard.setData(
                                                    ClipboardData(
                                                        text: identity
                                                            .certString));
                                                const snackBar = SnackBar(
                                                    content: Text(
                                                        'Copied to Clipboard'));
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(snackBar);
                                              }),
                                          TextButton(
                                              child: const Text(
                                                  "Copy private key"),
                                              onPressed: () async {
                                                await Clipboard.setData(
                                                    ClipboardData(
                                                        text: identity
                                                            .privateKeyString));
                                                const snackBar = SnackBar(
                                                    content: Text(
                                                        'Copied to Clipboard'));
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(snackBar);
                                              }),
                                        ]),
                                        scrollable: true,
                                        content: Column(children: [
                                          SelectableText(identity.certString),
                                          SelectableText(
                                              identity.privateKeyString),
                                        ]),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Close'),
                                          ),
                                        ]);
                                  });
                            }),
                        IconButton(
                            onPressed: () {
                              appState.removeIdentity(identity);
                            },
                            icon: const Icon(Icons.delete)),
                      ],
                    ),
                  ),
                ),
                for (var page in identity.pages)
                  Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: GemItem(
                        title: const Text(""),
                        onSelect: () {
                          appState.onNewTab(page);
                          Navigator.pop(navigatorKey.currentContext!);
                        },
                        showDelete: true,
                        onDelete: () {
                          appState.onIdentity(identity, Uri.parse(page));
                        },
                        url: toSchemelessString(Uri.parse(page)),
                      ))
              ],
            )
        ],
      ),
    );
  }
}
