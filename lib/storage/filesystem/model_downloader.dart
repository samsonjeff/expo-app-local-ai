import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'file_storage_manager.dart';

final modelDownloaderProvider = Provider<ModelDownloader>((ref) {
  return ModelDownloader();
});

class ModelDownloader {
  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};

  /// Downloads a GGUF model to the models directory.
  /// Supports resuming partial downloads if the server supports range requests.
  Future<File> downloadModel({
    required String modelId,
    required String url,
    required String fileName,
    String? expectedSha256,
    void Function(double progress, int bytesReceived, int totalBytes)? onProgress,
  }) async {
    final modelsDir = await FileStorageManager.instance.getModelsDir();
    final destinationFile = File(p.join(modelsDir.path, fileName));

    if (await destinationFile.exists()) {
      if (expectedSha256 != null) {
        final isValid = await _verifySha256(destinationFile, expectedSha256);
        if (isValid) {
          // File is already downloaded and verified
          return destinationFile;
        } else {
          // Corrupted or incomplete, delete and start over
          await destinationFile.delete();
        }
      } else {
        // Without SHA, we assume if it exists, it's correct (or we can check size)
        // For production, always use SHA validation.
        return destinationFile;
      }
    }

    final cancelToken = CancelToken();
    _cancelTokens[modelId] = cancelToken;

    int downloadedBytes = 0;
    // Basic implementation for a fresh download.
    // To support full resumability, we'd check partial files (.part) and use HTTP Range headers.
    final partFile = File('${destinationFile.path}.part');
    if (await partFile.exists()) {
      downloadedBytes = await partFile.length();
    }

    final options = Options(
      responseType: ResponseType.stream,
      headers: downloadedBytes > 0 ? {'Range': 'bytes=$downloadedBytes-'} : null,
    );

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: options,
        cancelToken: cancelToken,
      );

      final totalBytes = int.tryParse(
              response.headers.value(HttpHeaders.contentLengthHeader) ?? '-1') ??
          -1;
      
      final expectedTotal = totalBytes != -1 ? totalBytes + downloadedBytes : -1;

      final raf = await partFile.open(mode: downloadedBytes > 0 ? FileMode.append : FileMode.write);
      
      int received = downloadedBytes;
      await for (final chunk in response.data!.stream) {
        if (cancelToken.isCancelled) {
          await raf.close();
          throw Exception('Download cancelled');
        }
        await raf.writeFrom(chunk);
        received += chunk.length;
        if (onProgress != null && expectedTotal != -1) {
          onProgress(received / expectedTotal, received, expectedTotal);
        }
      }
      
      await raf.close();

      if (expectedTotal != -1 && received < expectedTotal) {
        throw Exception('Download incomplete');
      }

      if (expectedSha256 != null) {
        final isValid = await _verifySha256(partFile, expectedSha256);
        if (!isValid) {
          await partFile.delete();
          throw Exception('SHA256 checksum validation failed.');
        }
      }

      await partFile.rename(destinationFile.path);
      _cancelTokens.remove(modelId);
      return destinationFile;
    } catch (e) {
      _cancelTokens.remove(modelId);
      rethrow;
    }
  }

  void cancelDownload(String modelId) {
    if (_cancelTokens.containsKey(modelId)) {
      _cancelTokens[modelId]!.cancel('Cancelled by user');
      _cancelTokens.remove(modelId);
    }
  }

  Future<bool> _verifySha256(File file, String expectedSha256) async {
    final stream = file.openRead();
    final digest = await sha256.bind(stream).last;
    return digest.toString().toLowerCase() == expectedSha256.toLowerCase();
  }
}
