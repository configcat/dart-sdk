import '../constants.dart';
import '../json/config.dart';

class Entry {
  final Config config;
  final String json;
  final String eTag;
  final DateTime fetchTime;

  Entry(this.config, this.json, this.eTag, this.fetchTime);

  bool isEmpty() => identical(this, empty);

  Entry withTime(DateTime time) => Entry(config, json, eTag, time);

  static Entry empty = Entry(Config.empty, '', '', distantPast);
}
