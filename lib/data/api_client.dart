import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:file_picker/file_picker.dart';
import 'package:get/get_connect/http/src/request/request.dart';
import 'package:ride_sharing_user_app/data/error_response.dart';
import 'package:path/path.dart';
import 'package:ride_sharing_user_app/features/address/domain/models/address_model.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient extends GetxService {
  final String appBaseUrl;
  final SharedPreferences sharedPreferences;
  static final String noInternetMessage = 'connection_to_api_server_failed'.tr;
  final int timeoutInSeconds = 45;
  final int retryAttempts = 2;

  late String token;
  late Map<String, String> _mainHeaders;

  ApiClient({required this.appBaseUrl, required this.sharedPreferences}) {
    token = sharedPreferences.getString(AppConstants.token) ?? '';
    customPrint('Token: $token');
    Address? address;
    try {
      address = Address.fromJson(
          jsonDecode(sharedPreferences.getString(AppConstants.userAddress)!));
      customPrint(address.toJson().toString());
      // ignore: empty_catches
    } catch (e) {}
    updateHeader(token, address);
  }

  void updateHeader(String token, Address? address, {String? zoneId}) {
    Map<String, String> header = {};
    if (address != null) {
      header.addAll({'zoneId': address.zoneId.toString()});
    }
    if (zoneId != null) {
      header.addAll({'zoneId': zoneId});
    }
    header.addAll({
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      AppConstants.localization:
          sharedPreferences.getString(AppConstants.languageCode) ??
              AppConstants.languages[0].languageCode,
      'Authorization': 'Bearer $token',
    });
    if (kDebugMode) {
      print('====> API Call: Zone: ${address?.zoneId ?? ''}');
    }

    _mainHeaders = header;
  }

  Future<Response> getData(String uri,
      {Map<String, dynamic>? query, Map<String, String>? headers}) async {
    try {
      if (kDebugMode) {
        print('====> API Call: $uri\nHeader: $_mainHeaders');
      }
      http.Response response = await _sendWithRetry(
        uri: uri,
        request: () => http.get(
          Uri.parse(appBaseUrl + uri),
          headers: headers ?? _mainHeaders,
        ),
      );
      return handleResponse(response, uri);
    } catch (e) {
      _logNetworkException(uri, e);
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postData(String uri, dynamic body,
      {Map<String, String>? headers}) async {
    try {
      if (kDebugMode) {
        print('====> API Call: $uri\nHeader: $_mainHeaders');
        print('====> API Body: $body');
      }
      http.Response response = await _sendWithRetry(
        uri: uri,
        request: () => http.post(
          Uri.parse(appBaseUrl + uri),
          body: jsonEncode(body),
          headers: headers ?? _mainHeaders,
        ),
      );
      return handleResponse(response, uri);
    } catch (e) {
      _logNetworkException(uri, e);
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postMultipartDataConversation(
      String? uri, Map<String, String> body, List<MultipartBody>? multipartBody,
      {Map<String, String>? headers, PlatformFile? otherFile}) async {
    http.MultipartRequest request =
        http.MultipartRequest('POST', Uri.parse(appBaseUrl + uri!));
    request.headers.addAll(headers ?? _mainHeaders);

    if (otherFile != null) {
      request.files.add(http.MultipartFile('files[${multipartBody!.length}]',
          otherFile.readStream!, otherFile.size,
          filename: basename(otherFile.name)));
    }
    if (multipartBody != null) {
      for (MultipartBody multipart in multipartBody) {
        Uint8List list = await multipart.file!.readAsBytes();
        request.files.add(http.MultipartFile(
          multipart.key,
          multipart.file!.readAsBytes().asStream(),
          list.length,
          filename: '${DateTime.now().toString()}.png',
        ));
      }
    }
    request.fields.addAll(body);
    http.Response response =
        await http.Response.fromStream(await request.send());
    return handleResponse(response, uri);
  }

  Future<Response> postMultipartData(String uri, Map<String, String> body,
      MultipartBody profile, List<MultipartBody> multipartBody,
      {Map<String, String>? headers}) async {
    try {
      if (kDebugMode) {
        print('====> API Call: $uri\nHeader: $_mainHeaders');
        print(
            '====> API Body: $body with ${multipartBody.length} picture and ${profile.key}');
      }
      http.MultipartRequest request =
          http.MultipartRequest('POST', Uri.parse(appBaseUrl + uri));
      request.headers.addAll(headers ?? _mainHeaders);
      if (profile.file != null) {
        Uint8List list = await profile.file!.readAsBytes();
        request.files.add(http.MultipartFile(
          profile.key,
          profile.file!.readAsBytes().asStream(),
          list.length,
          filename: '${DateTime.now().toString()}.png',
        ));
      }

      for (MultipartBody multipart in multipartBody) {
        log("Here-----${multipart.file}/${multipart.key}");
        if (multipart.file != null) {
          log("Here----Inside-");
          Uint8List list = await multipart.file!.readAsBytes();
          request.files.add(http.MultipartFile(
            multipart.key,
            multipart.file!.readAsBytes().asStream(),
            list.length,
            filename: multipart.file?.path.split('/').last,
          ));
          log("===ImageKey==>${multipart.key}/${multipart.file!.readAsBytes().asStream()}");
        }
      }
      request.fields.addAll(body);
      http.Response response =
          await http.Response.fromStream(await request.send());
      return handleResponse(response, uri);
    } catch (e) {
      _logNetworkException(uri, e);
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> putData(String uri, dynamic body,
      {Map<String, String>? headers}) async {
    try {
      if (kDebugMode) {
        print('====> API Call: $uri\nHeader: $_mainHeaders');
        print('====> API Body: $body');
      }
      http.Response response = await _sendWithRetry(
        uri: uri,
        request: () => http.put(
          Uri.parse(appBaseUrl + uri),
          body: jsonEncode(body),
          headers: headers ?? _mainHeaders,
        ),
      );
      return handleResponse(response, uri);
    } catch (e) {
      _logNetworkException(uri, e);
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> deleteData(String uri,
      {Map<String, String>? headers}) async {
    try {
      if (kDebugMode) {
        print('====> API Call: $uri\nHeader: $_mainHeaders');
      }
      http.Response response = await _sendWithRetry(
        uri: uri,
        request: () => http.delete(
          Uri.parse(appBaseUrl + uri),
          headers: headers ?? _mainHeaders,
        ),
      );
      return handleResponse(response, uri);
    } catch (e) {
      _logNetworkException(uri, e);
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<http.Response> _sendWithRetry({
    required String uri,
    required Future<http.Response> Function() request,
  }) async {
    Object? lastError;

    for (int attempt = 0; attempt <= retryAttempts; attempt++) {
      try {
        final http.Response response =
            await request().timeout(Duration(seconds: timeoutInSeconds));

        if (!_shouldRetryStatus(response.statusCode) ||
            attempt == retryAttempts) {
          return response;
        }

        if (kDebugMode) {
          print(
              '====> API Retry status [${response.statusCode}] $uri attempt ${attempt + 1}');
        }
      } catch (error) {
        lastError = error;

        if (attempt == retryAttempts || !_shouldRetryError(error)) {
          rethrow;
        }

        if (kDebugMode) {
          print(
              '====> API Retry exception $uri attempt ${attempt + 1}: $error');
        }
      }

      await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
    }

    throw lastError ?? Exception('API request failed: $uri');
  }

  bool _shouldRetryStatus(int? statusCode) {
    return statusCode == 408 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  bool _shouldRetryError(Object error) {
    return error is TimeoutException || error is http.ClientException;
  }

  void _logNetworkException(String uri, Object error) {
    if (kDebugMode) {
      print('====> API Exception: $uri\n$error');
    }
  }

  Response handleResponse(http.Response response, String uri) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
      // ignore: empty_catches
    } catch (e) {}

    final http.BaseRequest? request = response.request;
    Response localResponse = Response(
      body: body ?? response.body,
      bodyString: response.body.toString(),
      request: request == null
          ? null
          : Request(
              headers: request.headers,
              method: request.method,
              url: request.url),
      headers: response.headers,
      statusCode: response.statusCode,
      statusText: response.reasonPhrase,
    );

    if (localResponse.statusCode != 200 &&
        localResponse.body != null &&
        localResponse.body is! String) {
      if (localResponse.body.toString().startsWith('{errors: [{code:')) {
        ErrorResponse errorResponse =
            ErrorResponse.fromJson(localResponse.body);
        localResponse = Response(
            statusCode: localResponse.statusCode,
            body: localResponse.body,
            statusText: errorResponse.errors![0].message);
      } else if (localResponse.body.toString().startsWith('{message')) {
        localResponse = Response(
            statusCode: localResponse.statusCode,
            body: localResponse.body,
            statusText: localResponse.body['message']);
      }
    } else if (localResponse.statusCode != 200 && localResponse.body == null) {
      localResponse = Response(statusCode: 0, statusText: noInternetMessage);
    }

    log('====> API Response: [${localResponse.statusCode}] $uri\n${localResponse.body}');

    return localResponse;
  }
}

class MultipartBody {
  String key;
  XFile? file;

  MultipartBody(this.key, this.file);
}
