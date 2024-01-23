/// An object containing attributes to properly identify a given user for variation evaluation.
/// Its only mandatory attribute is the [identifier].
///
/// Custom attributes of the user for advanced targeting rule definitions (e.g. user role, subscription type, etc.)
///
/// The set of allowed attribute values depends on the comparison type of the condition which references the User Object attribute.<br>
/// [String] values are supported by all comparison types (in some cases they need to be provided in a specific format though).<br>
/// Some of the comparison types work with other types of values, as described below.
///
/// Text-based comparisons (EQUALS, IS ONE OF, etc.)<br>
///  * accept [String] values,
///  * all other values are automatically converted to string (a warning will be logged but evaluation will continue as normal).
///
/// SemVer-based comparisons (IS ONE OF, &lt;, &gt;=, etc.)<br>
///  * accept [String] values containing a properly formatted, valid semver value,
///  * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
///
/// Number-based comparisons (=, &lt;, &gt;=, etc.)<br>
///  * accept [double] values (except for [double.nan]) and all other numeric values which can safely be converted to [double]
///  * accept [String] values containing a properly formatted, valid [double]  value
///  * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
///
/// Date time-based comparisons (BEFORE / AFTER)<br>
///  * accept [DateTime] values, which are automatically converted to a second-based Unix timestamp
///  * accept [double] values (except for {@code Double.NaN}) representing a second-based Unix timestamp and all other numeric values which can safely be converted to {@link Double}
///  * accept [String] values containing a properly formatted, valid [double]  value
///  * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
///
/// String array-based comparisons (ARRAY CONTAINS ANY OF / ARRAY NOT CONTAINS ANY OF)<br>
///  * accept [List] of [String]
///  * accept [List] of [dynamic] values, which are automatically converted to [String]
///  * accept [Set] of [dynamic] values, which are automatically converted to [String]
///  * accept [String] values containing a valid JSON string which can be deserialized to an array of [String]
///  * all other values are considered invalid (a warning will be logged and the currently evaluated targeting rule will be skipped).
///
///   In case a non-string attribute value needs to be converted to [String] during evaluation, it will always be done using the same format which is accepted by the comparisons.
class ConfigCatUser {
  final Map<String, Object> _attributes = <String, Object>{};
  final String identifier;

  ConfigCatUser(
      {required this.identifier,
      String? email,
      String? country,
      Map<String, Object>? custom}) {
    _attributes['Identifier'] = identifier;
    if (email != null && email.isNotEmpty) {
      _attributes['Email'] = email;
    }

    if (country != null && country.isNotEmpty) {
      _attributes['Country'] = country;
    }

    if (custom != null) {
      for(MapEntry<String, Object> entry in custom.entries){
        if(entry.key != "Identifier" && entry.key != "Email" && entry.key != "Country") {
          _attributes[entry.key] = entry.value;
        }
      }
    }
  }

  Object? getAttribute(String key) {
    return _attributes[key];
  }

  @override
  String toString() {
    StringBuffer stringBuffer = StringBuffer("{");

    stringBuffer.write("\"Identifier\":\"${_attributes["Identifier"]}\"");

    if (_attributes.containsKey("Email")) {
      stringBuffer.write(",\"Email\":\"${_attributes["Email"]}\"");
    }
    if (_attributes.containsKey("Country")) {
      stringBuffer.write(",\"Country\":\"${_attributes["Country"]}\"");
    }
    var iterator = _attributes.entries.iterator;
    while (iterator.moveNext()) {
      if(iterator.current.key != "Identifier" && iterator.current.key != "Email" && iterator.current.key != "Country") {
        stringBuffer
            .write(
            ",\"${iterator.current.key}\":\"${iterator.current.value}\"");
      }
    }
    stringBuffer.write("}");
    return stringBuffer.toString();
  }
}
