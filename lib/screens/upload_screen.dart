import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_store_upload/screens/gallery_screen.dart';
import 'package:flutter/material.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  List<UploadTask> uploadedTask = [];

  List<File> selectedFiles = [];

  fileToUploadStorage(File file) {
    UploadTask task = _firebaseStorage
        .ref()
        .child('images/${DateTime.now().toString()}')
        .putFile(file);

    return task;
  }

  writeImageUrlToFirestore(imageUrl) {
    _firebaseFirestore.collection('images').add({'url': imageUrl}).whenComplete(
      () => ('$imageUrl is saved in firestore'),
    );
  }

  saveImageToFirebase(UploadTask task) {
    task.snapshotEvents.listen((snapShot) {
      if (snapShot.state == TaskState.success) {
        snapShot.ref
            .getDownloadURL()
            .then((imageUrl) => writeImageUrlToFirestore(imageUrl));
      }
    });
  }

  Future fileToUpload() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result == null) {
        selectedFiles.clear();

        for (var selecetFile in result!.files) {
          File file = File(selecetFile.path!);
          selectedFiles.add(file);
        }

        for (var file in selectedFiles) {
          final UploadTask task = fileToUploadStorage(file);
          saveImageToFirebase(task);
          setState(() {
            uploadedTask.add(task);
          });
        }
      } else {
        ('User has cancelled the selection');
      }
    } catch (e) {
      (e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery App'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GalleryScreen(),
              ),
            ),
            icon: const Icon(Icons.photo),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          fileToUpload();
        },
        child: const Icon(Icons.add),
      ),
      body: uploadedTask.isEmpty
          ? const Center(
              child: Text('Please tap the add button to upload images'))
          : ListView.separated(
              itemBuilder: (context, index) {
                return StreamBuilder<TaskSnapshot>(
                    builder: (context, snapShot) {
                  return snapShot.connectionState == ConnectionState.waiting
                      ? const CircularProgressIndicator()
                      : snapShot.hasError
                          ? const Text('Error processing data')
                          : snapShot.hasData
                              ? ListTile(
                                  title: Text(
                                      '${snapShot.data?.bytesTransferred}/${snapShot.data?.totalBytes} ${snapShot.data?.state == TaskState.success ? 'Completed' : snapShot.data?.state == TaskState.running ? 'In progress' : 'Error'}'),
                                )
                              : Container();
                },
                stream: uploadedTask[index].snapshotEvents,
                );
              },
              separatorBuilder: (context, index) => const Divider(),
              itemCount: uploadedTask.length),
    );
  }
}
