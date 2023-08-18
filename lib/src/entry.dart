import 'dart:convert';

import 'constants.dart';
import 'json/config.dart';

class Entry {
  final Config config;
  final String configJsonString;
  final String eTag;
  final DateTime fetchTime;

  Entry(this.configJsonString, this.config, this.eTag, this.fetchTime);

  bool get isEmpty => identical(this, empty);

  Entry withTime(DateTime time) => Entry(configJsonString, config, eTag, time);

  static Entry empty = Entry('', Config.empty, '', distantPast);

  String serialize() {
    return '${fetchTime.millisecondsSinceEpoch}\n$eTag\n$configJsonString';
  }

  static Entry fromConfigJson(String configJson, String eTag, DateTime time) {
    final decoded = jsonDecode(configJson);
    final config = Config.fromJson(decoded);
    return Entry(configJson, config, eTag, time);
  }

  static Entry fromCached(String cached) {
    final timeIndex = cached.indexOf('\n');
    if (timeIndex == -1) {
      throw FormatException("Number of values is fewer than expected.");
    }

    final eTagIndex = cached.indexOf('\n', timeIndex + 1);
    if (eTagIndex == -1) {
      throw FormatException("Number of values is fewer than expected.");
    }

    final timeString = cached.substring(0, timeIndex);
    final time = int.tryParse(timeString);
    if (time == null) {
      throw FormatException("Invalid fetch time: $timeString");
    }

    final fetchTime = DateTime.fromMillisecondsSinceEpoch(time, isUtc: true);
    final eTag = cached.substring(timeIndex + 1, eTagIndex);
    final configJson = cached.substring(eTagIndex + 1);

    return fromConfigJson(configJson, eTag, fetchTime);
  }
}
