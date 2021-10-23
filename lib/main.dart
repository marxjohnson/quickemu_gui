import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quickemu',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Quickemu GUI'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  List<String> _currentVms = [];
  List<String> _activeVms = [];
  List<String> _spicyVms = [];
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        ?.addPostFrameCallback((_) => _getVms(context)); // Reload VM list when we enter the page.
    refreshTimer = Timer.periodic(Duration(seconds: 5), (Timer t) {
      _getVms(context);
    }); // Reload VM list every 15 seconds.
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  void _getVms(context) async {
    List<String> currentVms = [];
    List<String> activeVms = [];

    await for (var entity in
    Directory.current.list(recursive: false, followLinks: true)) {
      if (entity.path.endsWith('.conf')) {
        String name = Path.basenameWithoutExtension(entity.path);
        currentVms.add(name);
        File pidFile = File(name + '/' + name + '.pid');
        if (pidFile.existsSync()) {
          String pid = pidFile.readAsStringSync().trim();
          Directory procDir = Directory('/proc/' + pid);
          if (procDir.existsSync()) {
            activeVms.add(name);
          }
        }
      }
    }
    currentVms.sort();
    activeVms.sort();
    setState(() {
      _currentVms = currentVms;
      _activeVms = activeVms;
    });
  }


  void _showQuickgetForm() {
    Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (context) {
              return Scaffold(
                  appBar: AppBar(
                    title: const Text('New VM with Quickget'),
                  ),
                  body: const QuickgetForm()
              );
            }
        )
    ).then(
        (value) {
          _getVms(context);
        }
    );
  }

  Widget _buildVmList() {
    List<Widget> _widgetList = [];
    _widgetList.add(
      TextButton(
        onPressed: () async {
          String? result = await FilePicker.platform.getDirectoryPath();
          if (result != null) {
            Directory.current = result;
            _getVms(context);
          }
        },
        child: Text(Directory.current.path)
      )
    );
    _widgetList.addAll(
      _currentVms.map(
        (vm) {
          return _buildRow(vm);
        }
      ).toList()
    );
    return ListView(
        padding: const EdgeInsets.all(16.0),
        children: _widgetList,
    );
  }

  Widget _buildRow(String currentVm) {
    final active = _activeVms.contains(currentVm);
    final spicy = _spicyVms.contains(currentVm);
    return ListTile(
        title: Text(currentVm),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
                icon: Icon(
                  Icons.monitor,
                  color: spicy ? Colors.red : null,
                  semanticLabel: spicy ? 'Using SPICE display' : 'Click to use SPICE display'
                ),
                tooltip: spicy ? 'Using SPICE display' : 'Use SPICE display',
                onPressed: () {
                  if (spicy) {
                    setState(() {
                      _spicyVms.remove(currentVm);
                    });
                  } else {
                    setState(() {
                      _spicyVms.add(currentVm);
                    });
                  }
                }
            ),
            IconButton(
                icon: Icon(
                  active ? Icons.play_arrow : Icons.play_arrow_outlined,
                  color: active ? Colors.green : null,
                  semanticLabel: active ? 'Running' : 'Run',
                ),
                onPressed: () {
                  if (active) {
                    Process.run('killall', [currentVm]);
                    setState(() {
                      _activeVms.remove(currentVm);
                    });
                  } else {
                    List<String> args = ['--vm', currentVm + '.conf'];
                    if (spicy) {
                      args.addAll(['--display', 'spice']);
                    }
                    Process.run('quickemu', args);
                    setState(() {
                      _activeVms.add(currentVm);
                    });
                  }
                }
            )
          ],
        )

    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: _buildVmList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickgetForm,
        tooltip: 'Add VM with quickget',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class QuickgetForm extends StatefulWidget {
  const QuickgetForm({Key? key}) : super(key: key);

  @override
  _QuickgetFormState createState() => _QuickgetFormState();
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

class _QuickgetFormState extends State<QuickgetForm> {
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

