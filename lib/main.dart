// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import './types/file_info.dart';

void main() {
  runApp(const FyrFilesApp());
}

Widget greenDot() {
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: Colors.green,
      shape: BoxShape.circle,
    ),
  );
}

Widget blueDot() {
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: Colors.blue,
      shape: BoxShape.circle,
    ),
  );
}

Widget purpleDot() {
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: Colors.deepPurple,
      shape: BoxShape.circle,
    ),
  );
}

Widget greyDot() {
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: Colors.grey,
      shape: BoxShape.circle,
    ),
  );
}

Widget getDotByTag(String tag) {
  Color dotColor;

  switch (tag) {
    case 'purple':
      return purpleDot();
      break;
    case 'green':
      return greenDot();
      break;
    case 'blue':
      return blueDot();
      break;
    default:
      return greyDot();
      break;
  }
}

class FileInfo {
  final String filePath;
  String? tag; // This could be 'red', 'blue', 'green', etc.

  FileInfo({required this.filePath, this.tag});

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'tag': tag,
    };
  }

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      filePath: json['filePath'] as String,
      tag: json['tag'] as String?,
    );
  }
}

class FyrFilesApp extends StatelessWidget {
  const FyrFilesApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light, // Light mode
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark, // Dark mode
      ),
      home: FyrFiles(),
    );
  }
}

class FyrFiles extends StatefulWidget {
  const FyrFiles({super.key});

  @override
  State<FyrFiles> createState() => _FyrFilesState();
}

class _FyrFilesState extends State<FyrFiles> {
  /* 
    'late' is similar to declaring a variable with ! in typescript.
    Means the value will be non-null at the time it's used
  */
  late List<FileSystemEntity> files;
  late Directory currentDir;
  FileSystemEntity? copiedEntity;
  bool isFileContextMenuShown = false;
  bool showHiddenFiles = false;
  List<FileInfo> fileInfoList = [];
  late String tagsFilePath;
  String? selectedTag;

  Stream<List<FileSystemEntity>> watchDirectory() async* {
    List<FileSystemEntity> previousFiles = [];
    bool isFirstRun = true;

    while (true) {
      final currentFiles = selectedTag == null
          ? currentDir.listSync()
          : fileInfoList
              .where((info) => info.tag == selectedTag)
              .map((info) => FileSystemEntity.isDirectorySync(info.filePath)
                  ? Directory(info.filePath)
                  : File(info.filePath))
              .toList();

      final filteredFiles = showHiddenFiles
          ? currentFiles
          : currentFiles
              .where((file) => !p.basename(file.path).startsWith('.'))
              .toList();

      // Check if it's the first run or the list has changed.
      if (isFirstRun || !listEquals(previousFiles, filteredFiles)) {
        yield filteredFiles;
        previousFiles = filteredFiles;
        isFirstRun = false;
      }

      await Future.delayed(Duration(seconds: 1));
    }
  }

  // called after constructor, think useEffect/ngOnInit/onMounted
  @override
  void initState() {
    super.initState();
    final homeDirectory = Platform.environment['HOME'];
    if (homeDirectory == null) {
      return;
    }
    tagsFilePath = '$homeDirectory/.fyr/files/tags.json';
    checkAndCreateFile();
    readTagsFromFile(tagsFilePath).then((loadedFileInfo) {
      setState(() {
        fileInfoList = loadedFileInfo;
        currentDir = Directory.current;
        files = currentDir.listSync();
      });
    });
  }

  String displayText(
      Directory dir, Directory currentDir, bool isColorFiltered) {
    if (isColorFiltered) {
      return '';
    }

    if (dir.path == '/' && dir != currentDir) {
      return 'root > ';
    } else if (dir.path == '/' && dir == currentDir) {
      return 'root';
    } else if (dir != currentDir) {
      return '${dir.path.split('/').last} > ';
    } else {
      return dir.path.split('/').last;
    }
  }

  String formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  Map<String, dynamic> fileStatToMap(FileStat fileStat, String filePath) {
    return {
      'filename': filePath.split('/').last,
      'mode': fileStat.mode.toString(),
      'modified': fileStat.modified.toString(),
      'accessed': fileStat.accessed.toString(),
      'changed': fileStat.changed.toString(),
      'size': formatBytes(fileStat.size, 2),
      'type': fileStat.type.toString(),
    };
  }

  Map<String, dynamic> dirStatToMap(FileStat dirStat, String dirPath) {
    return {
      'directory': dirPath,
      'mode': dirStat.mode.toString(),
      'modified': dirStat.modified.toString(),
      'accessed': dirStat.accessed.toString(),
      'changed': dirStat.changed.toString(),
      'type': dirStat.type.toString(),
    };
  }

  Future<void> checkAndCreateFile() async {
    try {
      // Get the home directory path from the 'HOME' environment variable

      final file = File(tagsFilePath);

      // Check if the file exists
      if (await file.exists()) {
        print("File exists.");
      } else {
        print("File does not exist. Creating file.");

        // Initialize with empty data or whatever your initial state should be
        Map<String, List<String>> initialData = {};

        // Write to the file
        await file.writeAsString(jsonEncode(initialData));
      }
    } catch (e) {
      print("An error occurred: $e");
    }
  }

  void openDirectory(Directory directory) {
    print(directory);
    // setState notifies framework that variables have changed
    setState(() {
      selectedTag = null;
      currentDir = directory;
      files = directory.listSync().where((file) {
        String fileName = p.basename(file.path);
        return showHiddenFiles || !fileName.startsWith('.');
      }).toList();
    });
  }

  bool hasChildDirectories(Directory directory) {
    var entities = directory.listSync(followLinks: false);
    return entities.any((entity) => entity is Directory);
  }

  Future<void> createFile(Directory directory, String fileName) async {
    final newFile = File('${directory.path}/$fileName');
    await newFile.create();
  }

  Future<void> createDir(Directory directory, String newDirName) async {
    final newDir = Directory('${directory.path}/$newDirName');
    await newDir.create();
  }

  List<Directory> getParentDirectories(Directory currDir) {
    List<Directory> parents = [];
    Directory? dir = currDir;
    while (dir?.path != dir?.parent.path) {
      if (dir != null) {
        parents.add(dir);
      }
      dir = dir?.parent;
    }
    // Add the root directory
    if (dir != null && dir.path == dir.parent.path) {
      parents.add(dir);
    }
    return parents.reversed.toList();
  }

  Future<bool> isClipboardDataAvailable() async {
    ClipboardData? clipboardData = await Clipboard.getData('text/plain');
    String? path = clipboardData?.text;

    if (path != null && path.isNotEmpty) {
      return FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
    }

    return false;
  }

  String formatPath(String path) {
    List<String> segments = path.split('/');
    return segments.where((seg) => seg.isNotEmpty).join(' > ');
  }

  Future<void> pasteFile(Directory targetDir) async {
    try {
      ClipboardData data =
          await Clipboard.getData('text/plain') as ClipboardData;
      String path = data.text ?? '';
      if (FileSystemEntity.isFileSync(path)) {
        File sourceFile = File(path);
        String fileName = sourceFile.uri.pathSegments.last;
        await sourceFile.copy('${targetDir.path}/$fileName');
        setState(() {}); // trigger a rebuild
      }
    } catch (err) {
      print(err);
    }
  }

  Future<void> writeTagsToFile(
      List<FileInfo> fileInfos, String filePath) async {
    final json = jsonEncode(fileInfos.map((e) => e.toJson()).toList());
    final file = File(filePath);
    await file.writeAsString(json);
  }

  Future<List<FileInfo>> readTagsFromFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      final json = await file.readAsString();
      final list = jsonDecode(json) as List;
      return list
          .map((e) => FileInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  void showPropertiesDialog(
      BuildContext context, Map<String, dynamic> properties) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("File Properties"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: properties.entries.map((entry) {
                return Text('${entry.key}: ${entry.value}');
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // Template for UI
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    Stream<List<FileSystemEntity>> fileStream = watchDirectory();

    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true, // To ensure it gets focus
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
              event.logicalKey == LogicalKeyboardKey.controlRight) {
            // Control key is down
            // You can listen for other keys here if needed
          } else if (event.logicalKey == LogicalKeyboardKey.keyH &&
              event.isControlPressed) {
            // Ctrl + H is pressed
            setState(() {
              showHiddenFiles = !showHiddenFiles;
              if (selectedTag == null) {
                openDirectory(currentDir); // Refresh the directory
              }
            });
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 30,
          leading: currentDir.path != currentDir.parent.path
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (selectedTag != null) {
                      setState(() {
                        selectedTag = null;
                      });
                    } else {
                      openDirectory(currentDir.parent);
                    }
                  },

                  //onPressed: () {
                  //  openDirectory(currentDir.parent);
                  //},
                  iconSize: 24.0,
                )
              : null,
          backgroundColor: Colors.transparent,
          flexibleSpace: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  SizedBox(width: 75),
                  IconButton(
                    icon: Icon(Icons.circle, color: Colors.purple),
                    onPressed: () {
                      setState(() {
                        selectedTag = 'purple';
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.circle, color: Colors.green),
                    onPressed: () {
                      setState(() {
                        selectedTag = 'green';
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.circle, color: Colors.blue),
                    onPressed: () {
                      setState(() {
                        selectedTag = 'blue';
                      });
                    },
                  ),
                ],
              ),
              Align(
                alignment: Alignment.center,
                child: RichText(
                  text: TextSpan(
                    children: getParentDirectories(currentDir).map((dir) {
                      return TextSpan(
                        text: displayText(dir, currentDir, selectedTag != null),
                        style: TextStyle(
                          color: MediaQuery.of(context).platformBrightness ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            selectedTag = null;
                            openDirectory(dir);
                          },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: StreamBuilder<List<FileSystemEntity>>(
          stream: fileStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              files = snapshot.data as List<FileSystemEntity>;
              return Stack(
                children: [
                  GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: (width / 120).floor()),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      var file = files[index];
                      var isDir = FileSystemEntity.isDirectorySync(file.path);

                      FileInfo? currentFileInfo = fileInfoList.firstWhere(
                        (info) => info.filePath == file.path,
                        orElse: () => FileInfo(filePath: file.path),
                      );
                      return Listener(
                          onPointerDown: (PointerDownEvent event) {
                            if (event.kind == PointerDeviceKind.mouse &&
                                event.buttons == kSecondaryMouseButton) {
                              isFileContextMenuShown = true;
                              showMenu(
                                context: context,
                                position: RelativeRect.fromLTRB(
                                    event.position.dx,
                                    event.position.dy,
                                    event.position.dx,
                                    event.position.dy),
                                items: [
                                  PopupMenuItem(
                                    child: ListTile(
                                      leading: Icon(Icons.copy),
                                      title: Text('Copy'),
                                      onTap: () {
                                        Clipboard.setData(
                                            ClipboardData(text: file.path));
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                  PopupMenuItem(
                                    child: ListTile(
                                      leading: Icon(Icons.edit),
                                      title: Text('Rename'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        TextEditingController renameController =
                                            TextEditingController(
                                                text:
                                                    file.uri.pathSegments.last);
                                        await showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Rename File'),
                                            content: TextField(
                                              controller: renameController,
                                            ),
                                            actions: [
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () {
                                                  String newName =
                                                      renameController.text;
                                                  String newPath = p.join(
                                                      p.dirname(file.path),
                                                      newName);
                                                  file.renameSync(newPath);
                                                  Navigator.pop(context);
                                                },
                                                child: Text('Rename'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  PopupMenuItem(
                                    child: ListTile(
                                      leading: Icon(Icons.delete),
                                      title: Text('Delete'),
                                      onTap: () {
                                        // Deleting the file
                                        file.deleteSync();
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                  PopupMenuItem(
                                    child: Column(
                                      children: [
                                        ListTile(
                                          leading: Icon(Icons.info),
                                          title: Text('Properties'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            var fileStat = file.statSync();
                                            var properties = fileStatToMap(
                                                fileStat, file.path);
                                            showPropertiesDialog(
                                                context, properties);
                                          },
                                        ),
                                      ], //PopupMenuItem children
                                    ), // Column
                                  ), //PopupMenuItem

                                  PopupMenuItem(
                                    child: GestureDetector(
                                        onTap: () async {
                                          FileInfo currentFileInfo =
                                              fileInfoList.firstWhere(
                                            (info) =>
                                                info.filePath == file.path,
                                            orElse: () =>
                                                FileInfo(filePath: file.path),
                                          );

                                          currentFileInfo.tag = 'purple';

                                          fileInfoList.removeWhere((info) =>
                                              info.filePath == file.path);

                                          fileInfoList.add(currentFileInfo);

                                          await writeTagsToFile(
                                              fileInfoList, tagsFilePath);

                                          Navigator.pop(context);
                                        },
                                        child: Row(
                                          children: [
                                            purpleDot(),
                                            SizedBox(width: 8),
                                            Text("Creativity"),
                                          ],
                                        )),
                                  ), // Color PopupMenuItem

                                  PopupMenuItem(
                                    child: GestureDetector(
                                        onTap: () async {
                                          FileInfo currentFileInfo =
                                              fileInfoList.firstWhere(
                                            (info) =>
                                                info.filePath == file.path,
                                            orElse: () =>
                                                FileInfo(filePath: file.path),
                                          );

                                          currentFileInfo.tag = 'green';

                                          fileInfoList.removeWhere((info) =>
                                              info.filePath == file.path);

                                          fileInfoList.add(currentFileInfo);

                                          await writeTagsToFile(
                                              fileInfoList, tagsFilePath);

                                          Navigator.pop(context);
                                        },
                                        child: Row(
                                          children: [
                                            greenDot(),
                                            SizedBox(width: 8),
                                            Text("Important"),
                                          ],
                                        )),
                                  ), // Color PopupMenuItem

                                  PopupMenuItem(
                                    child: GestureDetector(
                                        onTap: () async {
                                          FileInfo currentFileInfo =
                                              fileInfoList.firstWhere(
                                            (info) =>
                                                info.filePath == file.path,
                                            orElse: () =>
                                                FileInfo(filePath: file.path),
                                          );

                                          currentFileInfo.tag = 'blue';

                                          fileInfoList.removeWhere((info) =>
                                              info.filePath == file.path);

                                          fileInfoList.add(currentFileInfo);

                                          await writeTagsToFile(
                                              fileInfoList, tagsFilePath);

                                          Navigator.pop(context);
                                        },
                                        child: Row(
                                          children: [
                                            blueDot(),
                                            SizedBox(width: 8),
                                            Text("Development"),
                                          ],
                                        )),
                                  ), // Color PopupMenuItem
                                ],
                              ).then((value) => isFileContextMenuShown = false);
                            }
                          },
                          child: Material(
                            child: InkWell(
                              onDoubleTap: () async {
                                if (isDir) {
                                  openDirectory(file as Directory);
                                } else {
                                  var filePath = file.path;
                                  var result =
                                      await Process.run('xdg-open', [filePath]);
                                  if (result.exitCode != 0) {
                                    print(
                                        'Could not open $filePath: ${result.stderr}');
                                  }
                                }
                              },
                              child:
                                  Stack(alignment: Alignment.center, children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isDir ? Icons.folder : Icons.file_copy,
                                      size: 48.0,
                                      color: Colors.deepPurple,
                                    ),
                                    Text(
                                      isDir
                                          ? file.path.split('/').last
                                          : file.uri.pathSegments.last,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                                if (currentFileInfo?.tag != null)
                                  Positioned(
                                      top: 24,
                                      left: 24,
                                      child:
                                          getDotByTag(currentFileInfo!.tag!)),
                              ]),
                            ),
                          ));
                    },
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTapDown: (TapDownDetails details) async {
                      if (!isFileContextMenuShown) {
                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          ),
                          items: [
                            PopupMenuItem(
                              child: ListTile(
                                leading: Icon(Icons.create),
                                title: Text('Create File'),
                                onTap: () {
                                  Navigator.pop(
                                      context); // Close the context menu
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      TextEditingController fileNameController =
                                          TextEditingController();
                                      return AlertDialog(
                                        title: Text('Enter File Name'),
                                        content: TextField(
                                          controller: fileNameController,
                                          decoration: InputDecoration(
                                              hintText: "File name"),
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              if (fileNameController
                                                  .text.isNotEmpty) {
                                                await createFile(currentDir,
                                                    fileNameController.text);
                                                Navigator.pop(context);
                                              }
                                            },
                                            child: Text('Create'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            PopupMenuItem(
                              child: ListTile(
                                leading: Icon(Icons.create),
                                title: Text('Create Directory'),
                                onTap: () {
                                  Navigator.pop(
                                      context); // Close the context menu
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      TextEditingController dirNameController =
                                          TextEditingController();
                                      return AlertDialog(
                                        title: Text('Enter Directory Name'),
                                        content: TextField(
                                          controller: dirNameController,
                                          decoration: InputDecoration(
                                              hintText: "Directory name"),
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              if (dirNameController
                                                  .text.isNotEmpty) {
                                                await createDir(currentDir,
                                                    dirNameController.text);
                                                Navigator.pop(context);
                                              }
                                            },
                                            child: Text('Create'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            PopupMenuItem(
                              enabled: await isClipboardDataAvailable(),
                              child: ListTile(
                                leading: Icon(Icons.paste),
                                title: Text('Paste'),
                                onTap: () async {
                                  await pasteFile(currentDir);
                                  Navigator.pop(
                                      context); // Close the context menu
                                },
                              ),
                            ),
                            PopupMenuItem(
                              child: ListTile(
                                leading: Icon(Icons.info),
                                title: Text('Properties'),
                                onTap: () {
                                  Navigator.pop(
                                      context); // Close the context menu
                                  var dirStat = currentDir.statSync();
                                  var properties =
                                      dirStatToMap(dirStat, currentDir.path);
                                  showPropertiesDialog(context, properties);
                                },
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              );
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}
