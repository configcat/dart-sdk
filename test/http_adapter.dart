import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class HttpTestAdapter implements HttpClientAdapter {
  bool _closed = false;
  final List<RequestOptions> _capturedRequests = [];
  final Map<String, Queue<_Response>> _responseQueue = {};
  List<RequestOptions> get capturedRequests {
    return List.unmodifiable(_capturedRequests);
  }

  HttpTestAdapter(Dio dio) {
    dio.httpClientAdapter = this;
  }

  @override
  void close({bool force = false}) {
    _responseQueue.clear();
    _capturedRequests.clear();
    _closed = true;
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (_closed) {
      throw HttpException("Test adapter closed.");
    }

    _capturedRequests.add(options);
    final next = _next(options.path);
    if (next == null) {
      throw HttpException("Response not found for path: ${options.path}.");
    }
    if (next.delay != null) {
      await Future.delayed(next.delay!);
    }
    if (next.exception != null) {
      throw next.exception!;
    }

    return ResponseBody(
        Stream.fromIterable(utf8
            .encode(next.body)
            .map((e) => Uint8List.fromList([e]))
            .toList()),
        next.statusCode,
        headers: next.headers?.map((key, value) => MapEntry(key, [value])));
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

  _Response? _next(String path) {
    final nextEntry = _responseQueue[path];
    if (nextEntry == null) {
      return null;
    }
    return nextEntry.length == 1 ? nextEntry.first : nextEntry.removeFirst();
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
