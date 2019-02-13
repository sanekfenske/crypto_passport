import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto_wallet/crypto/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

const masterKey = 'my32lengthsupersecretnooneknows1'; // 32 байт или 256 бит
const iv = '12345678';

class HomePage extends StatelessWidget {
  final _imageSubject = BehaviorSubject<File>();
  final _passwordSubject = BehaviorSubject<String>(seedValue: '');
  final _nameSubject = BehaviorSubject<String>(seedValue: '');

  Stream<File> get _image => _imageSubject.stream;

  Function(File) get _updateImage => _imageSubject.add;

  Function(String) get _updateName => _nameSubject.add;

  Future<String> get name async => _nameSubject.first;

  Function(String) get _updatePassword => _passwordSubject.add;

  Future<String> get encryptionKey async => _passwordSubject.first;

  @override
  Widget build(BuildContext context) {
    return _documentList(context);
  }

  AppBar _appBar(String title) {
    return AppBar(
      centerTitle: true,
      title: Text(title),
      backgroundColor: Colors.white,
      automaticallyImplyLeading: true,
    );
  }

  Widget _documentList(BuildContext context) {
    return Scaffold(
      appBar: _appBar('Зашифрованные документы'),
      floatingActionButton: _newDocumentButton(context),
      body: _documents(context),
    );
  }

  //Список с документами
  Widget _documents(BuildContext context) {
    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, dir) {
        if (dir.hasData) {
          return FutureBuilder<List<FileSystemEntity>>(
            future: dir.data.list().toList(),
            builder: (context, files) {
              if (files.hasData) {
                return Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Scrollbar(
                      child: ListView(
                    children: files.data
                        .map((e) => _fileName(e).contains('.encrypted')
                            ? _encryptedFileRow(e, context)
                            : Container())
                        .toList()
                        .reversed
                        .toList())));
              } else {
                return Center(child: CircularProgressIndicator());
              }
            });
        } else {
          return Center(child: CircularProgressIndicator());
        }
      });
  }
  // Зашифрованный файл из списка с документами

  InkWell _encryptedFileRow(FileSystemEntity e, BuildContext context) {
    return InkWell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
                padding: EdgeInsets.all(7),
                child: Text(_fileName(e))),
            Divider(),
          ],
        ),
        onTap: () async {
          showDialog(
              context: context,
              builder: (_) {
                return SimpleDialog(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(10),
                      child: TextField(
                        obscureText: true,
                        autofocus: true,
                        decoration: InputDecoration(
                            labelText: 'Пароль',
                            border:
                            OutlineInputBorder()),
                        onSubmitted: (password) async {
                          final encrypted = await File(e.path).readAsString();
                          final secretKey = getSecretKey(password);
                          final imageBase64 = Encrypter(Salsa20(secretKey, iv))
                              .decrypt(encrypted);
                          try {
                            final decodedImage = base64Decode(imageBase64);
                            openDocumentDialog(decodedImage, context);
                          } on FormatException {
                            showDialog(
                                context: context,
                                builder: (_) {
                                  return AlertDialog(
                                    title: Text('Ошибка'),
                                    content: Text('Неверный пароль'),
                                    actions: <Widget>[
                                      FlatButton(
                                          child: Text('OK'),
                                          onPressed:
                                              () {
                                            Navigator.of(context).pop();
                                          }),
                                    ]);
                                });
                          }
                        },
                      ),
                    ),
                  ]);
              });
        });
  }

  // Диалог с расшифрованным документом
  void openDocumentDialog(Uint8List image, context) {
    showDialog(
        context: context,
        builder: (context) {
          return SimpleDialog(
            children: [
              Image.memory(image),
              Padding(
                padding: EdgeInsets.all(10),
                child: RaisedButton(
                  child: Text('OK'),
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              )
            ],
          );
        });
  }

  String _fileName(FileSystemEntity e) {
    return Uri.file(e.path)
        .pathSegments[Uri.file(e.path).pathSegments.length - 1];
  }

  // Плавающая кнопка для шифрования нового документа
  FloatingActionButton _newDocumentButton(BuildContext context) {
    return FloatingActionButton(
        child: Icon(Icons.add),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => _addDocument(context))));
  }

  // Экран где шифруется новый документ
  Widget _addDocument(BuildContext context) {
    return Scaffold(
        appBar: _appBar('Новый документ'),
        body: Column(children: <Widget>[
          Flexible(fit: FlexFit.loose, flex: 3, child: _imageDisplay(context)),
          Flexible(fit: FlexFit.loose, flex: 2, child: _imageSelector(context)),
          Flexible(fit: FlexFit.loose, flex: 2, child: _nameSelector(context)),
          Flexible(fit: FlexFit.loose, flex: 2, child: _passwordSelector(context)),
          Flexible(fit: FlexFit.loose, child: _action(context))
        ]));
  }

  // Отображение картинки
  Widget _imageDisplay(BuildContext context) {
    return Container(
        color: new Color(0xffe9e9e9),
        child: Center(
            child: StreamBuilder(
          stream: _image,
          builder: (context, i) => i.hasData ? Image.file(i.data) : Container(),
        )));
  }

  // Кнопка выбора картинки
  Widget _imageSelector(BuildContext context) {
    return new Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
          padding: EdgeInsets.all(10.0),
          child: FloatingActionButton(
              shape: BeveledRectangleBorder(),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: selectGalleryImage,
              heroTag: "gallery0",
              tooltip: 'Pick Image from gallery',
              child: Icon(Icons.photo_library))),
    ]);
  }

  selectGalleryImage() {
    selectImage(ImageSource.gallery);
  }

  Future<void> selectImage(ImageSource source) async {
    final image = await ImagePicker.pickImage(source: source, maxWidth: 500.0);
    if (image != null) {
      _updateImage(image);
    }
  }


  final keyController = TextEditingController();

  // Поле для выбора названия зашифрованного файла
  Widget _nameSelector(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: EdgeInsets.all(10.0),
        child: TextField(
          onChanged: (name) => _updateName(name),
          decoration: InputDecoration(
              labelText: 'Название файла', border: OutlineInputBorder()),
        ),
        width: 200,
      ),
    ]);
  }

  // Поле для выбора пароля
  Widget _passwordSelector(BuildContext context) {
    return new Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: EdgeInsets.all(10.0),
        child: TextField(
          obscureText: true,
          onChanged: (password) => _updatePassword(password),
          decoration: InputDecoration(
              labelText: 'Пароль', border: OutlineInputBorder()),
        ),
        width: 200,
      ),
    ]);
  }

  // Кнопка ЗАШИФРОВАТЬ
  Widget _action(BuildContext context) {
    return RaisedButton(
        child: Text(
          'ЗАШИФРОВАТЬ',
          style: TextStyle(fontSize: 15.0),
        ),
        onPressed: () async {
          final image = _imageSubject.value;
          if (image == null) {
            showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: Text('Ошибка'),
                    content: Text('Выберите документ'),
                    actions: <Widget>[
                      FlatButton(
                          child: Text('OK'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          }),
                    ],
                  );
                });
            return;
          }

          final filename = await name;
          if (filename == '') {
            showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: Text('Ошибка'),
                    content: Text('Выберите название файла'),
                    actions: <Widget>[
                      FlatButton(
                          child: Text('OK'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          }),
                    ],
                  );
                });
            return;
          }

          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          final password = await _passwordSubject.first;
          if (password == '') {
            showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: Text('Ошибка'),
                    content: Text('Выберите пароль'),
                    actions: <Widget>[
                      FlatButton(
                          child: Text('OK'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          }),
                    ],
                  );
                });
            return;
          }

          final secretKey = getSecretKey(password);
          final encryptedImage =
              Encrypter(Salsa20(secretKey, iv)).encrypt(base64Image);

          final file = await _localFileName(filename);
          file.writeAsString(encryptedImage);
          Navigator.of(context).pop();
        });
  }

  Future<File> _localFileName(String filename) async {
    final appDirectory = (await getApplicationDocumentsDirectory()).path;
    final path = '$appDirectory/$filename.encrypted';
    return File(path);
  }

  // Формирование ключа шифрования из пароля и мастер ключа
  String getSecretKey(String password) =>
      (password + masterKey).substring(0, 32);
}
