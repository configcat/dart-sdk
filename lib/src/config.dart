enum Config {
  value,
  comparator,
  comparisonAttribute,
  comparisonValue,
  rolloutPercentageItems,
  percentage,
  rolloutRules,
  variationId,
  preferences,
  preferencesUrl,
  preferencesRedirect,
  entries,
}

const Map<Config, String> ConfigName = {
  Config.value: 'v',
  Config.comparator: 't',
  Config.comparisonAttribute: 'a',
  Config.comparisonValue: 'c',
  Config.rolloutPercentageItems: 'p',
  Config.percentage: 'p',
  Config.rolloutRules: 'r',
  Config.variationId: 'i',
  Config.preferences: 'p',
  Config.preferencesUrl: 'u',
  Config.preferencesRedirect: 'r',
  Config.entries: 'f',
};
