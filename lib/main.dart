import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart';
import 'package:prompt_dialog/prompt_dialog.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _last = "";

  void _readKeyword() async {
    var availability = await FlutterNfcKit.nfcAvailability;
    if (availability != NFCAvailability.available) {
      return;
    }

    var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Scan your tag");

    if (tag.ndefAvailable == true) {
      try {
        for (var record in await FlutterNfcKit.readNDEFRecords(cached: false)) {
          if (record is TextRecord) {
            if (record.text != null && record.text!.length > 0) {
              var keyword = Uri.encodeComponent(record.text!);
              var url = "https://duckduckgo.com/?q=" +
                  keyword +
                  "&t=h_&iax=images&ia=images";
              print(url);
              if (!await launchUrl(Uri.parse(url))) {
                print('Could not launch $url');
              }
              setState(() {
                _last = record.text!;
              });
              return;
            }
          }
        }
      } catch (e) {
        setState(() {
          _last = e.toString();
        });
      }
    }
  }

  void _writeKeyword() async {
    var text = await prompt(context);
    if (text == null || text.length == 0) {
      return;
    }

    var availability = await FlutterNfcKit.nfcAvailability;
    if (availability != NFCAvailability.available) {
      return;
    }

    var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Scan your tag");

    if (tag.ndefWritable == true) {
      try {
        await FlutterNfcKit.writeNDEFRecords(
            [TextRecord(text: text, language: "ko")]);

        setState(() {
          _last = "$text 쓰기 완료!";
        });
      } catch (e) {
        setState(() {
          _last = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                '뭐든지 자판기',
                style: TextStyle(fontSize: 60),
              ),
              Text(_last),
            ],
          ),
        ),
        floatingActionButton: Stack(children: <Widget>[
          Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                onPressed: _readKeyword,
                tooltip: 'Read',
                child: const Icon(Icons.event_note),
              )),
          Align(
              alignment: Alignment.bottomLeft,
              child: FloatingActionButton(
                onPressed: _writeKeyword,
                tooltip: 'Write',
                child: const Icon(Icons.add),
              )),
        ]));
  }
}
