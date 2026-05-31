import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
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
    final String safeUri = uri ?? '';

    try {
      http.MultipartRequest request =
          http.MultipartRequest('POST', Uri.parse(appBaseUrl + safeUri));
      request.headers.addAll(_multipartHeaders(headers));

      if (otherFile != null) {
        request.files.add(http.MultipartFile(
          'files[${multipartBody?.length ?? 0}]',
          otherFile.readStream!,
          otherFile.size,
          filename: basename(otherFile.name),
        ));
      }

      if (multipartBody != null) {
        for (MultipartBody multipart in multipartBody) {
          if (multipart.file != null) {
            await _addXFileToMultipartRequest(
              request,
              multipart.key,
              multipart.file!,
            );
          }
        }
      }

      request.fields.addAll(body);
      http.Response response =
          await http.Response.fromStream(await request.send());
      return handleResponse(response, safeUri);
    } catch (e) {
      _logNetworkException(safeUri, e);
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Future<Response> postMultipartData(String uri, Map<String, String> body,
      MultipartBody profile, List<MultipartBody> multipartBody,
      {Map<String, String>? headers}) async {
    try {
      if (kDebugMode) {
        print('====> API Multipart Call: $uri');
        print('====> API Multipart Body: $body');
        print('====> API Multipart Primary Key: ${profile.key}');
        print(
            '====> API Multipart Extra Keys: ${multipartBody.map((item) => item.key).join(', ')}');
      }

      http.MultipartRequest request =
          http.MultipartRequest('POST', Uri.parse(appBaseUrl + uri));
      request.headers.addAll(_multipartHeaders(headers));

      if (profile.file != null) {
        await _addXFileToMultipartRequest(
          request,
          profile.key,
          profile.file!,
        );
      }

      for (MultipartBody multipart in multipartBody) {
        if (multipart.file != null) {
          await _addXFileToMultipartRequest(
            request,
            multipart.key,
            multipart.file!,
          );
        }
      }

      request.fields.addAll(body);

      if (kDebugMode) {
        print(
            '====> API Multipart Files: ${request.files.map((file) => file.field).join(', ')}');
      }

      http.Response response =
          await http.Response.fromStream(await request.send());
      return handleResponse(response, uri);
    } catch (e) {
      _logNetworkException(uri, e);
      return Response(statusCode: 1, statusText: noInternetMessage);
    }
  }

  Map<String, String> _multipartHeaders(Map<String, String>? headers) {
    final Map<String, String> multipartHeaders =
        Map<String, String>.from(headers ?? _mainHeaders);

    multipartHeaders.removeWhere(
      (key, value) => key.toLowerCase() == 'content-type',
    );

    multipartHeaders['Accept'] = 'application/json';

    return multipartHeaders;
  }

  Future<void> _addXFileToMultipartRequest(
    http.MultipartRequest request,
    String fieldName,
    XFile file,
  ) async {
    final Uint8List bytes = await file.readAsBytes();
    final String fileName = basename(file.path).trim().isNotEmpty
        ? basename(file.path)
        : '${DateTime.now().millisecondsSinceEpoch}.png';

    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: fileName,
      ),
    );

    if (kDebugMode) {
      print(
          '====> API Multipart File Added: $fieldName | $fileName | ${bytes.length} bytes');
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
