import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'amplifyconfiguration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();
  runApp(const FilePickingApp());
}

Future<void> _configureAmplify() async {
  try {
    await Amplify.addPlugin(AmplifyStorageS3());
    await Amplify.addPlugin(AmplifyAuthCognito());
    await Amplify.configure(amplifyconfig);
    safePrint('Successfully configured');
  } on Exception catch (e) {
    safePrint('Error configuring Amplify: $e');
  }
}

class FilePickingApp extends StatelessWidget {
  const FilePickingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Authenticator(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: Authenticator.builder(),
        home: Builder(builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('File Picking'),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return const ListPreviousFilesView();
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt),
                ),
                IconButton(
                  onPressed: () {
                    Amplify.Auth.signOut();
                  },
                  icon: const Icon(Icons.exit_to_app),
                ),
              ],
            ),
            body: const FilePickingView(),
          );
        }),
      ),
    );
  }
}

class ListPreviousFilesView extends StatefulWidget {
  const ListPreviousFilesView({Key? key}) : super(key: key);

  @override
  State<ListPreviousFilesView> createState() => _ListPreviousFilesViewState();
}

class _ListPreviousFilesViewState extends State<ListPreviousFilesView> {
  final items = <StorageItem>[];

  Future<void> listAlbum() async {
    try {
      final result = await Amplify.Storage.list().result;

      items
        ..clear()
        ..addAll(result.items);

      safePrint('Listed items: ${result.items}');
    } on StorageException catch (e) {
      safePrint(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Previous Uploads')),
      body: FutureBuilder<void>(
        future: listAlbum(),
        builder: ((context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(items[index].key));
              },
            );
          }
        }),
      ),
    );
  }
}

class FilePickingView extends StatefulWidget {
  const FilePickingView({Key? key}) : super(key: key);

  @override
  State<FilePickingView> createState() => _FilePickingViewState();
}

class _FilePickingViewState extends State<FilePickingView> {
  PlatformFile? _selectedFile;
  double _uploadedPercentage = 0;

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      uploadExampleData(result.files.first);
    }
  }

  Future<void> uploadExampleData(PlatformFile file) async {
    try {
      setState(() {
        _selectedFile = file;
      });

      final result = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(
          file.path!,
        ),
        key: file.name,
        onProgress: (progress) {
          setState(() {
            _uploadedPercentage = progress.fractionCompleted;
          });
        },
      ).result;

      safePrint('Uploaded data to location: ${result.uploadedItem.key}');
      _deselectFile();
    } on StorageException catch (e) {
      safePrint(e.message);
    }
  }

  void _deselectFile() {
    setState(() {
      _selectedFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFileSelected = _selectedFile != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isFileSelected
                ? 'You selected a file at path ${_selectedFile?.path}'
                : 'Click the button below to select a file.',
          ),
          if (isFileSelected)
            CircularProgressIndicator(
              value: _uploadedPercentage,
            ),
          ElevatedButton(
            onPressed: isFileSelected ? _deselectFile : _selectFile,
            child: Text(isFileSelected ? 'Deselect File' : 'Select File'),
          )
        ],
      ),
    );
  }
}
