import 'package:configcat_client/configcat_client.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  tearDown(() {
    ConfigCatClient.closeAll();
  });
  final userAttributeConvertTestData = {
    //SemVer data
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg",
      "lessThanWithPercentage",
      "0.0",
      "20%"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg",
      "lessThanWithPercentage",
      "0.9.9",
      "< 1.0.0"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg",
      "lessThanWithPercentage",
      "1.0.0",
      "20%"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg",
      "lessThanWithPercentage",
      "1.1",
      "20%"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg",
      "lessThanWithPercentage",
      0,
      "20%"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg",
      "lessThanWithPercentage",
      0.9,
      "20%"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/iV8vH2MBakKxkFZylxHmTg",
      "lessThanWithPercentage",
      2,
      "20%"
    ],
    //String Array data
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "stringArrayContainsAnyOfDogDefaultCat",
      {"x", "read"},
      "Dog"
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "stringArrayContainsAnyOfDogDefaultCat",
      {"x", "Read"},
      "Cat"
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "stringArrayContainsAnyOfDogDefaultCat",
      List<String>.of({"x", "read"}),
      "Dog"
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "stringArrayContainsAnyOfDogDefaultCat",
      List<String>.of({"x", "Read"}),
      "Cat"
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "stringArrayContainsAnyOfDogDefaultCat",
      "[\"x\", \"read\"]",
      "Dog"
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "stringArrayContainsAnyOfDogDefaultCat",
      "[\"x\", \"Read\"]",
      "Cat"
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "stringArrayContainsAnyOfDogDefaultCat",
      "x, read",
      "Cat"
    ],
    //Number date
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      -1,
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      2,
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      3,
      "<>4.2"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      5,
      ">=5"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      -1.0,
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      2.0,
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      3.0,
      "<>4.2"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      5.0,
      ">=5"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "-1.0",
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "2.0",
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "3.0",
      "<>4.2"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "5.0",
      ">=5"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "-1",
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "2",
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "3",
      "<>4.2"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "5",
      ">=5"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      double.nan,
      "<>4.2"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      double.infinity,
      ">5"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      double.negativeInfinity,
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      double.maxFinite.toInt(),
      ">5"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      -double.maxFinite.toInt(),
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "NotANumber",
      "80%"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "Infinity",
      ">5"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      " Infinity ",
      ">5"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "-Infinity",
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      " -Infinity ",
      "<2.1"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "NaN",
      "<>4.2"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      " NaN ",
      "<>4.2"
    ],
    [
      "configcat-sdk-1/PKDVCLf-Hq-h-kCzMp-L7Q/FCWN-k1dV0iBf8QZrDgjdw",
      "numberWithPercentage",
      "NaNa",
      "80%"
    ],
  };

  final userAttributeDateConvertTestData = {
    //Date data
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      DateTime.fromMillisecondsSinceEpoch(isUtc: true, 1680307199999),
      false
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      DateTime.fromMillisecondsSinceEpoch(isUtc: true, 1680307200001),
      true
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      1680307199.999,
      false
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      1680307200.001,
      true
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      1680307199,
      false
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      1680307201,
      true
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      "1680307199.999",
      false
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      "1680307200.001",
      true
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      "NaN",
      false
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      "+Infinity",
      false
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      "-Infinity",
      false
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      " NaN ",
      false
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      " +Infinity ",
      false
    ],
    [
      "configcat-sdk-1/JcPbCGl_1E-K9M-fJOyKyQ/OfQqcTjfFUGBwMKqtyEOrQ",
      "boolTrueIn202304",
      " -Infinity ",
      false
    ]
  };

  for (List<dynamic> element in userAttributeConvertTestData) {
    test("UserAttributeConvertTest", () async {
      await _userAttributeConvertTest(
          element[0], element[1], element[2], element[3]);
    });
  }

  for (List<dynamic> element in userAttributeDateConvertTestData) {
    test("UserAttributeDateConvertTest", () async {
      await _userAttributeDateConvertTest(
          element[0], element[1], element[2], element[3]);
    });
  }
}

Future<void> _userAttributeDateConvertTest(String key, String flagKey,
    Object customAttributeValue, Object expectedValue) async {
  final client = ConfigCatClient.get(sdkKey: key);

  Map<String, Object> customAttributes = <String, Object>{};
  customAttributes["Custom1"] = customAttributeValue;

  ConfigCatUser user =
      ConfigCatUser(identifier: "12345", custom: customAttributes);

  final result = await client.getValueDetails(
      key: flagKey, defaultValue: false, user: user);

  expect(result.value, expectedValue);
  expect(result.isDefaultValue, false);
}

Future<void> _userAttributeConvertTest(String key, String flagKey,
    Object customAttributeValue, Object expectedValue) async {
  final client = ConfigCatClient.get(sdkKey: key);

  Map<String, Object> customAttributes = <String, Object>{};
  customAttributes["Custom1"] = customAttributeValue;

  ConfigCatUser user =
      ConfigCatUser(identifier: "12345", custom: customAttributes);

  final result =
      await client.getValueDetails(key: flagKey, defaultValue: "", user: user);

  expect(result.value, expectedValue);
}
