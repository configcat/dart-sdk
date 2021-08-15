abstract class ConfigCache {
  read({key: String});
  write({key: String, value: String});
}

class InMemoryConfigCache extends ConfigCache {
  final store = Map<String, String>();

  @override
  read({key: String}) {
    return store[key];
  }

  @override
  write({key: String, value: String}) {
    store[key] = value;
  }

}