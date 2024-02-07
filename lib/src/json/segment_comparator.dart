// Note for maintainers: the order of enum members matters.
// The index of the enum members must correspond to the comparator type number

enum SegmentComparator {
  isInSegment(name: "IS IN SEGMENT"),
  isNotInSegment(name: "IS NOT IN SEGMENT");

  final String name;

  const SegmentComparator({required this.name});

  static SegmentComparator? tryFrom(int value) {
    return 0 <= value && value < SegmentComparator.values.length
        ? SegmentComparator.values[value]
        : null;
  }
}
