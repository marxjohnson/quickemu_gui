import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;
import 'dart:io';
import 'dart:convert';

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

  void initState() {
    super.initState();
    WidgetsBinding.instance
        ?.addPostFrameCallback((_) => _getVms(context));
  }

  void _getVms(context) async {
    Directory currentDirectory = Directory.current;
    setState(() {
      _currentVms = [];
      _activeVms = [];
    });

    await for (var entity in
      currentDirectory.list(recursive: false, followLinks: true)) {
      if (entity.path.endsWith('.conf')) {
        String name = Path.basenameWithoutExtension(entity.path);
        setState(() {
          _currentVms.add(name);
        });
        ProcessResult runningCheck = await Process.run('ps', ['-C', name]);
        if (runningCheck.exitCode == 0) {
          setState(() {
            _activeVms.add(name);
          });
        }
      }
    }
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
    return ListView(
        padding: const EdgeInsets.all(16.0),
        children: _currentVms.map(
            (vm) {
              return _buildRow(vm);
            }).toList(),
    );
  }

  Widget _buildRow(String currentVm) {
    final active = _activeVms.contains(currentVm);
    return ListTile(
        title: Text(currentVm),
        trailing: IconButton(
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
                Process.run('quickemu', ['--vm', currentVm + '.conf']);
                setState(() {
                  _activeVms.add(currentVm);
                });
              }
            }
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

class _QuickgetFormState extends State<QuickgetForm> {
  //final _formKey = GlobalKey<FormState>();
  List<String> osSupport = [];
  List<String> releaseSupport = [];
  String? selectedOs;
  String? selectedRelease;
  _getOsSupport() {
    var result = Process.runSync('quickget', []);
    setState(() {
      osSupport = result.stdout.split("\n")[1].split(" ");
    });
  }
  _releaseSupport(String os) {
    var result = Process.runSync('quickget', [os]);
    setState(() {
      releaseSupport = result.stdout.split("\n")[1].split(" ");
    });
  }
  _quickget(String os, String release) async {
    showLoadingIndicator('Downloading');
    var process = await Process.start('quickget', [os, release]);
    //process.stderr.transform(utf8.decoder).forEach(print);
    await process.exitCode;
    hideOpenDialog();
    Navigator.of(context).pop();
  }
  @override
  Widget build(BuildContext context) {
    _getOsSupport();
    return Form(
     // key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField(
            value: selectedOs,
            items: osSupport.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value)
              );
            }).toList(),
            hint: const Text('Select OS'),
            onChanged: (String? newValue) {
              setState(() {
                selectedOs = newValue!;
                releaseSupport = [];
                selectedRelease = null;
              });
              if (selectedOs != null) {
                _releaseSupport(selectedOs!);
              }
            },
          ),
          DropdownButtonFormField(
            value: selectedRelease,
            items: releaseSupport.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value)
              );
            }).toList(),
            hint: const Text('Select release'),
            disabledHint: const Text('Select an OS first'),
            onChanged: (String? newValue) {
              setState(() {
                selectedRelease = newValue!;
              });
            },
          ),
          ElevatedButton(
            onPressed: () {
              _quickget(selectedOs!, selectedRelease!);
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
              content: LoadingIndicator(
                  text: text
              ),
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

