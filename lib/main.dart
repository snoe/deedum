// ignore: unused_import
import 'dart:developer';
import 'package:deedum/next/app.dart';
import 'package:deedum/shared.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

final GlobalKey appKey = GlobalKey();
final GlobalKey materialKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  database = await openDatabase(
    'deedum.db',
    onCreate: (db, version) {
      db.execute(
          "CREATE TABLE hosts(name TEXT PRIMARY KEY, hash BLOB, expires_at BLOB, created_at TEXT)");
      db.execute(
          "CREATE TABLE feeds(uri TEXT PRIMARY KEY, content TEXT, last_fetched_at TEXT, attempts INTEGER default 0)");
      db.execute(
          "CREATE TABLE identities(name TEXT PRIMARY KEY, cert TEXT, private_key TEXT)");
    },
    onUpgrade: (db, old, _new) {
      if (old == 1) {
        db.execute("DROP TABLE hosts");
        db.execute(
            "CREATE TABLE hosts(name TEXT PRIMARY KEY, hash BLOB, expires_at BLOB, created_at TEXT)");
      }
      if (old == 2) {
        db.execute(
            "CREATE TABLE feeds(uri TEXT PRIMARY KEY, content TEXT, last_fetched_at TEXT, attempts INTEGER default 0)");
      }
      if (old == 3) {
        db.execute(
            "CREATE TABLE identities(name TEXT PRIMARY KEY, cert TEXT, private_key TEXT)");
      }
    },
    version: 4,
  );

  runApp(const ProviderScope(child: App()));
}
