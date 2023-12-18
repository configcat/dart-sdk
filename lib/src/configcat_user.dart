/// An object containing attributes to properly identify a given user for variation evaluation.
/// Its only mandatory attribute is the [identifier].
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
      _attributes.addAll(custom);
    }
  }

  Object? getAttribute(String key) {
    return _attributes[key];
  }

  @override
  String toString() {
    Map<String, Object> tmp = Map<String, Object>.from(_attributes);
    StringBuffer stringBuffer = StringBuffer("{");

    stringBuffer.write("\"Identifier\":\"${tmp["Identifier"]}\"");
    tmp.remove("Identifier");

    if (tmp.containsKey("Email")) {
      stringBuffer.write(",\"Email\":\"${tmp["Email"]}\"");
      tmp.remove("Email");
    }
    if (tmp.containsKey("Country")) {
      stringBuffer.write(",\"Country\":\"${tmp["Country"]}\"");
      tmp.remove("Country");
    }
    var iterator = tmp.entries.iterator;
    while (iterator.moveNext()) {
      stringBuffer
          .write(",\"${iterator.current.key}\":\"${iterator.current.value}\"");
    }
    stringBuffer.write("}");
    return stringBuffer.toString();
  }
}
