class ConfigCatUser {
  final Map<String, String> attributes = Map<String, String>();
  String identifier;

  ConfigCatUser({required this.identifier, String? email = null, String? country = null, Map<String, String>? custom = null}) {
    this.attributes['Identifier'] = identifier;
    if (email != null) {
      attributes["Email"] = email;
    }

    if (country != null) {
      attributes["Country"] = country;
    }

    if (custom != null) {
      custom.forEach((key, value) => attributes[key] = value);
    }
  }

  String? getAttribute({required String key}) {
    if (key.isEmpty) {
      assert(false, 'key cannot be empty');
    }

    return attributes[key];
  }

  @override
  String toString() {
    return attributes.toString();
  }
}
