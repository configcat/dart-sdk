import 'dart:core';
import 'dart:core' as core;

// Note for maintainers: the order of enum members matters.
// The index of the enum members must correspond to the comparator type numbers.

enum SettingType {
  boolean(name: 'Boolean'),
  string(name: 'String'),
  int(name: 'Int'),
  double(name: 'Double');

  final String name;

  const SettingType({required this.name});

  static SettingType? tryFrom(core.int value) {
    return 0 <= value && value < SettingType.values.length
        ? SettingType.values[value]
        : null;
  }
}
