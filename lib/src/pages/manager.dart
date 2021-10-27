import 'dart:async';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickemu_gui/src/pages/downloader.dart';
import 'package:quickemu_gui/src/model/vminfo.dart';

/// VM manager page.
/// Displays a list of available VMs, running state and connection info,
/// with buttons to start and stop VMs.
class Manager extends StatefulWidget {
  const Manager({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<Manager> createState() => _ManagerState();
}

class _ManagerState extends State<Manager> {

  List<String> _currentVms = [];
  Map<String, VmInfo> _activeVms = {};
  List<String> _spicyVms = [];
  Timer? refreshTimer;
  static const String prefsWorkingDirectory = 'workingDirectory';

  @override
  void initState() {
    super.initState();
    _getCurrentDirectory();
    Future.delayed(Duration.zero, () => _getVms(context));// Reload VM list when we enter the page.
    refreshTimer = Timer.periodic(Duration(seconds: 5), (Timer t) {
      _getVms(context);
    }); // Reload VM list every 5 seconds.
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  void _saveCurrentDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(prefsWorkingDirectory, Directory.current.path);
  }

  void _getCurrentDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(prefsWorkingDirectory)) {
      setState(() {
        final directory = prefs.getString(prefsWorkingDirectory);
        if (directory != null) {
          Directory.current = directory;
        }
      });
    }
  }

  VmInfo _parseVmInfo(name) {
    String shellScript = File(name + '/' + name + '.sh').readAsStringSync();
    RegExpMatch? sshMatch = RegExp('hostfwd=tcp::(\\d+?)-:22').firstMatch(shellScript);
    RegExpMatch? spiceMatch = RegExp('-spice.+?port=(\\d+)').firstMatch(shellScript);
    VmInfo info = VmInfo();
    if (sshMatch != null) {
      info.sshPort = sshMatch.group(1);
    }
    if (spiceMatch != null) {
      info.spicePort = spiceMatch.group(1);
    }
    return info;
  }

  void _getVms(context) async {
    List<String> currentVms = [];
    Map<String, VmInfo> activeVms = {};

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
            if (_activeVms.containsKey(name)) {
              activeVms[name] = _activeVms[name]!;
            } else {
              activeVms[name] = _parseVmInfo(name);
            }

          }
        }
      }
    }
    currentVms.sort();
    setState(() {
      _currentVms = currentVms;
      _activeVms = activeVms;
    });
  }

  void _showDownloader() {
    Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (context) {
              return Scaffold(
                  appBar: AppBar(
                    title: const Text('New VM with Quickget'),
                  ),
                  body: const Downloader()
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
                _saveCurrentDirectory();
                _getVms(context);
              }
            },
            child: Text(Directory.current.path)
        )
    );
    List<List<Widget>> rows = _currentVms.map(
            (vm) {
          return _buildRow(vm);
        }
    ).toList();
    for (var row in rows) {
      _widgetList.addAll(row);
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: _widgetList,
    );
  }

  List<Widget> _buildRow(String currentVm) {
    final bool active = _activeVms.containsKey(currentVm);
    final bool spicy = _spicyVms.contains(currentVm);
    String connectInfo = '';
    if (active) {
      VmInfo vmInfo = _activeVms[currentVm]!;
      if (vmInfo.sshPort != null) {
        connectInfo += 'SSH port: ' + vmInfo.sshPort! + ' ';
      }
      if (vmInfo.spicePort != null) {
        connectInfo += 'SPICE port: ' + vmInfo.spicePort! + ' ';
      }
    }
    return <Widget>[
      ListTile(
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
                  onPressed: () async {
                    if (!active) {
                      Map<String, VmInfo> activeVms = _activeVms;
                      List<String> args = ['--vm', currentVm + '.conf'];
                      if (spicy) {
                        args.addAll(['--display', 'spice']);
                      }
                      await Process.start('quickemu', args);
                      VmInfo info = _parseVmInfo(currentVm);
                      activeVms[currentVm] = info;
                      setState(() {
                        _activeVms = activeVms;
                      });
                    }
                  }
              ),
              IconButton(
                icon: Icon(
                  active ? Icons.stop : Icons.stop_outlined,
                  color: active ? Colors.red : null,
                  semanticLabel: active ? 'Stop' : 'Not running',
                ),
                onPressed: () {
                  if (active) {
                    showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Stop The Virtual Machine?'),
                        content: Text(
                            'You are about to terminate the virtual machine $currentVm'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ).then((result) {
                      result = result ?? false;
                      if (result) {
                        Process.run('killall', [currentVm]);
                        setState(() {
                          _activeVms.remove(currentVm);
                        });
                      }
                    });
                  }
                },
              ),
            ],
          )
      ),
      if (connectInfo.isNotEmpty) ListTile(
        title: Text(connectInfo),
      ),
      const Divider()
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _buildVmList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDownloader,
        tooltip: 'Add VM with quickget',
        child: const Icon(Icons.add),
      ),
    );
  }
}