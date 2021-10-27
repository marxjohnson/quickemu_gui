import 'dart:convert';
import 'dart:core';
import 'package:flutter/material.dart';
import 'dart:io';

class Downloader extends StatefulWidget {
  const Downloader({Key? key}) : super(key: key);

  @override
  _DownloaderState createState() => _DownloaderState();
}

class SupportedOs {
  String name = '';
  String prettyName = '';
  Map<String, OsRelease> releases = {};

  SupportedOs(this.name, this.prettyName);

  addRelease(OsRelease release) {
    releases[release.name] = release;
  }
}

class OsRelease {
  String name = '';
  List<String> options = [];

  OsRelease(this.name);

  addOption(String option) {
    options.add(option);
  }
}

class _DownloaderState extends State<Downloader> {
  //final _formKey = GlobalKey<FormState>();
  Map<String, SupportedOs> _osSupport = {};
  String? selectedOs;
  String? selectedRelease;
  String? selectedOption;
  List<DropdownMenuItem<String>> osOptions = [];
  List<DropdownMenuItem<String>> releaseOptions = [];
  List<DropdownMenuItem<String>> optionOptions = [];

  _getOsSupport() {
    var result = Process.runSync('quickget', ['list']);
    Map<String, SupportedOs> osSupport = {};
    List<String> lines = result.stdout.split('\n');
    lines.removeAt(0);
    for (String line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      List<String> field = line.split(',');
      String prettyName = field[0];
      String name = field[1];
      String releaseName = field[2];
      String option = field[3];

      SupportedOs os = osSupport[name] ?? SupportedOs(name, prettyName);
      OsRelease release = os.releases[releaseName] ?? OsRelease(releaseName);

      if (option != '' && ! release.options.contains(option)) {
        release.addOption(option);
      }

      os.releases[releaseName] = release;
      osSupport[name] = os;

    }
    setState(() => {
      _osSupport = osSupport
    });
  }
  _quickget(String os, String release, String? option) async {
    showLoadingIndicator('Downloading');
    List<String> args = [os, release];
    if (option != null) {
      args.add(option);
    }
    var process = await Process.start('quickget', args);
    process.stderr.transform(utf8.decoder).forEach(print);
    await process.exitCode;
    hideOpenDialog();
    Navigator.of(context).pop();
  }
  @override
  Widget build(BuildContext context) {
    _getOsSupport();

    List<DropdownMenuItem<String>> newOsOptions = [];
    _osSupport.forEach((name, os) {
      newOsOptions.add(DropdownMenuItem<String>(
          value: name,
          child: Text(os.prettyName)
      ));
    });
    setState(() => {
      osOptions = newOsOptions
    });

    return Form(
      // key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField(
              value: selectedOs,
              items: osOptions,
              hint: const Text('Select OS'),
              onChanged: (String? newValue) {
                List<DropdownMenuItem<String>> newReleaseOptions = [];

                if (newValue != null) {
                  _osSupport[newValue]?.releases.forEach((name, release) {
                    newReleaseOptions.add(DropdownMenuItem<String>(
                        value: name,
                        child: Text(name)
                    ));
                  });
                }
                setState(() {
                  selectedOs = newValue!;
                  selectedRelease = null;
                  selectedOption = null;
                  releaseOptions = newReleaseOptions;
                });
              },
            ),
            DropdownButtonFormField(
              value: selectedRelease,
              items: releaseOptions,
              hint: const Text('Select release'),
              disabledHint: const Text('Select an OS first'),
              onChanged: (String? newValue) {
                List<DropdownMenuItem<String>> newOptionOptions = [];
                if (newValue != null) {
                  _osSupport[selectedOs]?.releases[newValue]?.options.forEach((option) {
                    newOptionOptions.add(DropdownMenuItem<String>(
                        value: option,
                        child: Text(option)
                    ));
                  });
                }
                setState(() {
                  selectedRelease = newValue!;
                  selectedOption = null;
                  optionOptions = newOptionOptions;
                });
              },
            ),
            DropdownButtonFormField(
              value: selectedOption,
              items: optionOptions,
              hint: const Text('Select options'),
              disabledHint: const Text('No options for selected OS'),
              onChanged: (String? newValue) {
                setState(() {
                  selectedOption = newValue!;
                });
              },
            ),
            ElevatedButton(
              onPressed: () {
                _quickget(selectedOs!, selectedRelease!, selectedOption);
              },
              child: const Text('Quick, get!'),
            )
          ],

        )
    );
  }
  void showLoadingIndicator([String text = '']) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8.0))
              ),
              backgroundColor: Colors.black87,
              content: LoadingIndicator(),
            )
        );
      },
    );
  }

  void hideOpenDialog() {
    Navigator.of(context).pop();
  }
}


class LoadingIndicator extends StatelessWidget{
  LoadingIndicator({this.text = ''});

  final String text;
  double? progress;

  @override
  Widget build(BuildContext context) {
    var displayedText = text;

    return Container(
        padding: EdgeInsets.all(16),
        color: Colors.black87,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _getLoadingIndicator(),
              _getHeading(context),
              _getText(displayedText)
            ]
        )
    );
  }

  Padding _getLoadingIndicator() {
    return Padding(
        child: Container(
            child: CircularProgressIndicator(
                strokeWidth: 3,
                value: progress
            ),
            width: 32,
            height: 32
        ),
        padding: EdgeInsets.only(bottom: 16)
    );
  }

  Widget _getHeading(context) {
    return
      Padding(
          child: Text(
            'Please wait …',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16
            ),
            textAlign: TextAlign.center,
          ),
          padding: EdgeInsets.only(bottom: 4)
      );
  }

  Text _getText(String displayedText) {
    return Text(
      displayedText,
      style: TextStyle(
          color: Colors.white,
          fontSize: 14
      ),
      textAlign: TextAlign.center,
    );
  }

  void setProgress(double? progress) {
    progress = progress;
  }
}
