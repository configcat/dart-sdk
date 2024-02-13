// Note for maintainers: the order of enum members matters.
// The index of the enum members must correspond to the comparator type number

enum PrerequisiteComparator {
  equals(name: "EQUALS"),
  notEquals(name: "NOT EQUALS");

  final String name;

  const PrerequisiteComparator({required this.name});

  static PrerequisiteComparator? tryFrom(int value) {
    return 0 <= value && value < PrerequisiteComparator.values.length
        ? PrerequisiteComparator.values[value]
        : null;
  }
}
