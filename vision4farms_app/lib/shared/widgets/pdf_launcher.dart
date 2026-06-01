import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';

/// Descarrega um PDF protegido por JWT e abre-o com o visualizador nativo.
Future<void> openProtectedPdf(
  BuildContext context, {
  required String path,
  required String filename,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.accessTokenKey);
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      responseType: ResponseType.bytes,
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      validateStatus: (_) => true,
    ));
    final response = await dio.get<List<int>>(path);
    if (response.statusCode != 200 || response.data == null) {
      String msg = 'status ${response.statusCode}';
      try {
        final bytes = response.data;
        if (bytes != null && bytes.isNotEmpty) {
          final text = utf8.decode(bytes, allowMalformed: true);
          // Tenta parsear como JSON para mostrar o campo "detail"
          try {
            final json = jsonDecode(text);
            if (json is Map && json['detail'] != null) {
              msg += ' · ${json['detail']}';
            } else if (text.length < 400) {
              msg += ' · $text';
            }
          } catch (_) {
            if (text.length < 400) msg += ' · $text';
          }
        }
      } catch (_) {}
      messenger.showSnackBar(SnackBar(
        content: Text('Erro ao gerar PDF ($msg)'),
        duration: const Duration(seconds: 6),
      ));
      return;
    }
    final dir = await getTemporaryDirectory();
    final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(response.data!, flush: true);
    // OpenFilex usa um FileProvider (content://) — necessário desde o
    // Android 7, que proíbe partilhar URIs file:// com outras apps.
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF gerado mas não foi possível abrir: '
              '${result.message}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  } on DioException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Erro de rede: ${e.message ?? e.type}')),
    );
  } catch (err) {
    messenger.showSnackBar(
      SnackBar(content: Text('Erro ao gerar PDF: $err')),
    );
  }
}

/// Descarrega um ficheiro (PDF anexado) a partir de um URL completo e abre-o
/// com o visualizador nativo. Descarregar a totalidade dos bytes (em vez de
/// deixar o browser abrir o URL) evita downloads parciais que fazem o
/// visualizador pensar que o PDF está corrompido/protegido.
Future<void> openRemotePdf(
  BuildContext context, {
  required String url,
  required String filename,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.accessTokenKey);
    final dio = Dio(BaseOptions(
      responseType: ResponseType.bytes,
      followRedirects: true,
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      validateStatus: (_) => true,
    ));
    final response = await dio.get<List<int>>(url);
    if (response.statusCode != 200 || response.data == null) {
      messenger.showSnackBar(SnackBar(
        content: Text('Não foi possível abrir o ficheiro '
            '(status ${response.statusCode}).'),
        duration: const Duration(seconds: 5),
      ));
      return;
    }
    final dir = await getTemporaryDirectory();
    var safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (!safeName.toLowerCase().endsWith('.pdf')) safeName += '.pdf';
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(response.data!, flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Não foi possível abrir: ${result.message}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  } catch (err) {
    messenger.showSnackBar(
      SnackBar(content: Text('Erro ao abrir ficheiro: $err')),
    );
  }
}
