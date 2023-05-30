import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'company_contact.dart';

final port = 8080;

/// Log that is only stored locally.
Map<DateTime, String> log = {};

/// The model for the response query.
class ResponseModel {
  final int totalRows;
  final List<CompanyContact> rows;

  ResponseModel(this.totalRows, this.rows);

  Map<String, dynamic> toJson() {
    return {'totalRows': totalRows, 'rows': rows.map((e) => e.toJson()).toList()};
  }
}

/// Can do JSON fetching with query parameters.
int sortContacts(CompanyContact a, CompanyContact b, int sortIndex, bool asc) {
  late int result;
  switch (sortIndex) {
    case 1:
      result = a.id.compareTo(b.id);
      break;
    case 2:
      result = a.companyName.compareTo(b.companyName);
      break;
    case 3:
      result = a.firstName.compareTo(b.firstName);
      break;
    case 4:
      result = a.lastName.compareTo(b.lastName);
      break;
    case 5:
      result = a.phone.compareTo(b.phone);
      break;
    default:
      result = a.id.compareTo(b.id);
      break;
  }
  if (!asc) result *= -1;
  return result;
}

/// Gets the JSON-file path.
String getPath(String path) {
  if (path.contains('.dart_tool\\pub\\bin\\server')) {
    return path.replaceAll('.dart_tool\\pub\\bin\\server', '\\bin');
  } else {
    return 'asd';
  }
}

/// Adds a text to the local log.
void addLog(String text) {
  log.addAll({DateTime.now(): text});
}

/// Main function that starts the backend.
Future main() async {
  // Fetching the data from JSON.
  // JSON File is stored as clear text locally.
  // Anyone can access the file.
  // To fix this, it should be at least crypted and the access should only come with the password.
  final context = path.Context(style: path.Style.windows);
  final targetFile = File(context.normalize(path.join(getPath(path.dirname(Platform.script.toFilePath())), 'data.json')));

  late final HttpServer server;
  late final List<CompanyContact> fileContent;
  if (await targetFile.exists()) {
    print('Serving data from $targetFile');
    fileContent = (jsonDecode(await targetFile.readAsString()) as List<dynamic>).map((e) => CompanyContact.fromJson(e)).toList();
  } else {
    print("$targetFile doesn't exists, stopping");
    exit(-1);
  }
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } catch (e) {
    print("Couldn't bind to port $port: $e");
    exit(-1);
  }
  print('Listening on http://${server.address.address}:${server.port}/');

  await for (HttpRequest req in server) {
    req.response.headers.contentType = ContentType.json;
    // CORS Headers, they cause a security risk.
    // Good practice would be to set the values as something else than anything.
    // Now anyone can access the data.
    req.response.headers.add(
      'Access-Control-Allow-Origin',
      '*',
      preserveHeaderCase: true,
    );
    req.response.headers.add(
      'Access-Control-Allow-Headers',
      'Origin, X-Requested-With, Content-Type, Accept, Authorization',
      preserveHeaderCase: true,
    );
    // Post something.
    if (req.method == 'POST') {
      // JSON raw data loaded from the response.
      // It's from raw data, so it's open for JSON-injection.
      var bodyJson = String.fromCharCodes((await req.toList()).first);
      print(bodyJson);
      Map<String, dynamic> body = jsonDecode(bodyJson);
      if (bodyJson.contains('"delete":true')) {
        String id = body['id'];
        print('Delete. ID: $id');
        var list = (jsonDecode(await targetFile.readAsString()) as List<dynamic>).map((e) => CompanyContact.fromJson(e)).toList();
        list.removeWhere((contact) => contact.id == id);
        final jsonList = list.map((e) => (e).toJson()).toList();
        await targetFile.writeAsString(jsonEncode(jsonList));
        req.response.statusCode = 202;
      } else {
        try {
          print('Post.');
          var newContact = CompanyContact.fromJson(body);
          var list = (jsonDecode(await targetFile.readAsString()) as List<dynamic>).map((e) => CompanyContact.fromJson(e)).toList();
          list.add(newContact);
          final jsonList = list.map((e) => (e).toJson()).toList();
          await targetFile.writeAsString(jsonEncode(jsonList));
          req.response.statusCode = 201;
        } catch (e) {
          print('Something went wrong: $e');
          req.response.statusCode = HttpStatus.internalServerError;
        }
      }
    }
    // Get something or delete something.
    if (req.method == 'GET') {
      print('Get.');
      // JSON raw data loaded from the response.
      // It's from raw data, so it's open for JSON-injection.
      // At the same time, we take the password from the request. It's hard coded into the program.
      if (req.headers.toString().contains('authorization: Basic admin:admin')) {
        try {
          final offset = int.parse(req.requestedUri.queryParameters['offset'] ?? '0');
          final pageSize = int.parse(req.requestedUri.queryParameters['pageSize'] ?? '10');
          final sortIndex = int.parse(req.requestedUri.queryParameters['sortIndex'] ?? '1');
          final sortAsc = int.parse(req.requestedUri.queryParameters['sortAsc'] ?? '1') == 1;

          fileContent.sort((a, b) => sortContacts(a, b, sortIndex, sortAsc));
          var list = (jsonDecode(await targetFile.readAsString()) as List<dynamic>).map((e) => CompanyContact.fromJson(e)).toList();
          final jsonList = list.map((e) => (e).toJson()).toList();
          req.response.write(jsonEncode(jsonList));
        } catch (e) {
          print('Something went wrong: $e');
          req.response.statusCode = HttpStatus.internalServerError;
        }
      } else {
        print('Not authorized.');
        req.response.statusCode = HttpStatus.unauthorized;
      }
    }
    await req.response.close();
  }
}
