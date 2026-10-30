import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';

class HttpTestAdapter extends BaseClient {
  bool _closed = false;
  final List<BaseRequest> _capturedRequests = [];
  final Map<String, Queue<_Response>> _responseQueue = {};

  List<BaseRequest> get capturedRequests {
    return List.unmodifiable(_capturedRequests);
  }

  @override
  void close() {
    _responseQueue.clear();
    _capturedRequests.clear();
    _closed = true;
    super.close();
  }

  void enqueueResponse(String path, int statusCode, dynamic body,
      {Map<String, String>? headers, Duration? delay, Exception? exception}) {
    final response = _Response(statusCode,
        body: jsonEncode(body),
        headers: headers,
        delay: delay,
        exception: exception);
    if (_responseQueue.containsKey(path)) {
      _responseQueue[path]?.add(response);
    } else {
      final queue = Queue<_Response>();
      queue.add(response);
      _responseQueue.addAll({path: queue});
    }
  }

  void clearRequests() {
    _capturedRequests.clear();
  }

  _Response? _next(String path) {
    final nextEntry = _responseQueue[path];
    if (nextEntry == null) {
      return null;
    }
    return nextEntry.length == 1 ? nextEntry.first : nextEntry.removeFirst();
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (_closed) {
      throw HttpException("Test adapter closed.");
    }

    _capturedRequests.add(request);
    final next = _next(request.url.toString());
    if (next == null) {
      throw HttpException(
          "Response not found for path: ${request.url.toString()}.");
    }
    if (next.delay != null) {
      await Future.delayed(next.delay!);
    }
    if (next.exception != null) {
      throw next.exception!;
    }

    return StreamedResponse(
      ByteStream.fromBytes(utf8.encode(next.body)),
      next.statusCode,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        ...(next.headers ?? {})
      },
      request: request,
    );
  }
}

class _Response {
  final int statusCode;
  final String body;
  final Map<String, String>? headers;
  final Duration? delay;
  final Exception? exception;

  _Response(this.statusCode,
      {this.body = "",
      Map<String, String>? headers,
      this.delay,
      this.exception})
      : headers = headers ?? {};
}
