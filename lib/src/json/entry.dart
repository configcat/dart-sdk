import 'package:json_annotation/json_annotation.dart';

import '../constants.dart';
import 'config.dart';

part 'entry.g.dart';

@JsonSerializable()
class Entry {
  final Config config;
  final String eTag;
  final DateTime fetchTime;

  Entry(this.config, this.eTag, this.fetchTime);

  bool get isEmpty => identical(this, empty);

  Entry withTime(DateTime time) => Entry(config, eTag, time);

  static Entry empty = Entry(Config.empty, '', distantPast);

  factory Entry.fromJson(Map<String, dynamic> json) => _$EntryFromJson(json);

  Map<String, dynamic> toJson() => _$EntryToJson(this);
}
