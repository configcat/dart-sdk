// Note for maintainers: the order of enum members matters.
// The index of the enum members must correspond to the comparator type numbers.

enum UserComparator {
  isOneOf(name: "IS ONE OF"),
  isNotOneOf(name: "IS NOT ONE OF"),
  containsAnyOf(name: "CONTAINS ANY OF"),
  notContainsAnyOf(name: "NOT CONTAINS ANY OF"),
  semverIsOneOf(name: "IS ONE OF"),
  semverIsNotOneOf(name: "IS NOT ONE OF"),
  semverLess(name: "<"),
  semverLessEquals(name: "<="),
  semverGreater(name: ">"),
  semverGreaterEquals(name: ">="),
  numberEquals(name: "="),
  numberNotEquals(name: "!="),
  numberLess(name: "<"),
  numberLessEquals(name: "<="),
  numberGreater(name: ">"),
  numberGreaterEquals(name: ">="),
  sensitiveIsOneOf(name: "IS ONE OF"),
  sensitiveIsNotOneOf(name: "IS NOT ONE OF"),
  dateBefore(name: "BEFORE"),
  dateAfter(name: "AFTER"),
  hashedEquals(name: "EQUALS"),
  hashedNotEquals(name: "NOT EQUALS"),
  hashedStartsWith(name: "STARTS WITH ANY OF"),
  hashedNotStartsWith(name: "NOT STARTS WITH ANY OF"),
  hashedEndsWith(name: "ENDS WITH ANY OF"),
  hashedNotEndsWith(name: "NOT ENDS WITH ANY OF"),
  hashedArrayContains(name: "ARRAY CONTAINS ANY OF"),
  hashedArrayNotContains(name: "ARRAY NOT CONTAINS ANY OF"),
  textEquals(name: "EQUALS"),
  textNotEquals(name: "NOT EQUALS"),
  textStartsWith(name: "STARTS WITH ANY OF"),
  textNotStartsWith(name: "NOT STARTS WITH ANY OF"),
  textEndsWith(name: "ENDS WITH ANY OF"),
  textNotEndsWith(name: "NOT ENDS WITH ANY OF"),
  textArrayContains(name: "ARRAY CONTAINS ANY OF"),
  textArrayNotContains(name: "ARRAY NOT CONTAINS ANY OF");

  final String name;

  const UserComparator({required this.name});

  static UserComparator? tryFrom(int value) {
    return 0 <= value && value < UserComparator.values.length
        ? UserComparator.values[value]
        : null;
  }
}
