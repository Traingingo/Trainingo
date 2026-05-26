import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';

class UploadFileData {
  final Uint8List bytes;
  final String filename;

  const UploadFileData({
    required this.bytes,
    required this.filename,
  });
}

class ApiService {
  final String baseUrl = AppConstants.baseUrl;

  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }

      final errorMsg = _parseError(response);
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('GET 요청 실패: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }

      final errorMsg = _parseError(response);
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('POST 요청 실패: $e');
    }
  }

  // 파일 1개 업로드용 multipart POST 요청 (기존 호출부 호환)
  Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    Uint8List fileBytes,
    String filename,
    Map<String, String> fields,
  ) async {
    return uploadFiles(
      endpoint,
      [
        UploadFileData(
          bytes: fileBytes,
          filename: filename,
        ),
      ],
      fields,
      fileFieldName: 'file',
    );
  }

  // 여러 파일 업로드용 multipart POST 요청 (Flutter Web/Windows bytes 기반)
  Future<Map<String, dynamic>> uploadFiles(
    String endpoint,
    List<UploadFileData> files,
    Map<String, String> fields, {
    String fileFieldName = 'files',
  }) async {
    if (files.isEmpty) {
      throw Exception('업로드할 파일을 1개 이상 선택해 주세요.');
    }

    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);

      request.fields.addAll(fields);

      for (final file in files) {
        request.files.add(
          http.MultipartFile.fromBytes(
            fileFieldName,
            file.bytes,
            filename: file.filename,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }

      final errorMsg = _parseError(response);
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('파일 업로드 실패: $e');
    }
  }

  // 백엔드 에러 디테일 메시지 파싱
  String _parseError(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body.containsKey('detail')) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return '에러 코드: ${response.statusCode}';
  }
}
