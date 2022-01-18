/// An object containing attributes to properly identify a given user for variation evaluation.
/// Its only mandatory attribute is the [identifier].
class ConfigCatUser {
  final Map<String, String> _attributes = <String, String>{};
  final String identifier;

  ConfigCatUser(
      {required this.identifier,
      String? email,
      String? country,
      Map<String, String>? custom}) {
    _attributes['Identifier'] = identifier;
    if (email != null) {
      _attributes['Email'] = email;
    }

    if (country != null) {
      _attributes['Country'] = country;
    }

    if (custom != null) {
      _attributes.addAll(custom);
    }
  }

  String? getAttribute(String key) {
    return _attributes[key];
  }

  @override
  String toString() {
    return _attributes.toString();
  }
}
