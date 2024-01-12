import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show Uint8List, rootBundle;
import 'package:http/http.dart' as http;

import '../generated/bindings.dart';

class Dylib {
  static Map<String, dynamic>? _config;
  static String get libName => "unittest.bdk.${_config!['TAG_VERSION']}";
  static String get remoteUrl =>
      "${_config!['REPOSITORY_URL']}${_config!['TAG_VERSION']}/$libName.zip";
  static Future<void> _loadJsonAsset() async {
    final String content = await rootBundle
        .loadString("packages/bdk_flutter/assets/release.config.txt");
    Map<String, dynamic> configMap = {};
    List<String> lines = content.split('\n');

    for (String line in lines) {
      List<String> keyVal = line.split('=');
      if (keyVal.length == 2) {
        String key = keyVal[0].trim();
        dynamic value = keyVal[1].trim();
        configMap[key] = value;
      }
    }
    _config = configMap;
  }

  static Future<void> downloadUnitTestDylib(String currentDirectory) async {
    await _loadJsonAsset();
    final assetsDir = '$currentDirectory/build/unit_test_assets';
    if (!(await Directory('$assetsDir/$libName').exists())) {
      try {
        final response = await http.get(Uri.parse(remoteUrl));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final archive = ZipDecoder().decodeBytes(Uint8List.fromList(bytes));
          for (final file in archive) {
            final filename = '$assetsDir/${file.name}';
            if (file.isFile) {
              final fileContent = await File(filename).create(recursive: true);
              await fileContent.writeAsBytes(file.content);
            } else {
              await Directory(filename).create(recursive: true);
            }
          }
        } else {
          print('Download failed: status code ${response.statusCode}!');
        }
      } catch (e) {
        print(e.toString());
      }
    }
  }

  static String _getUniTestDylibDir(Directory currentDirectory) {
    final assetsDir = '${currentDirectory.path}/build/unit_test_assets';

    if (Platform.isMacOS) {
      return "$assetsDir/$libName/macos/librust_bdk_ffi.dylib";
    } else {
      throw Exception("not support platform:${Platform.operatingSystem}");
    }
  }

  static DynamicLibrary getDylib() {
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      try {
        DynamicLibrary.open(_getUniTestDylibDir(Directory.current));
      } catch (e) {
        throw Exception("Unable to open the unit test dylib!");
      }
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.executable();
    } else if (Platform.isAndroid) {
      return DynamicLibrary.open("librust_bdk_ffi.so");
    } else {
      throw Exception("not support platform:${Platform.operatingSystem}");
    }
  }
}

final bdkFfi = RustBdkFfiImpl(Dylib.getDylib());
