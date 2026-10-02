enum DietPreference {
  noPork({'pork'}),
  vegetarian({'meat', 'fish', 'seafood'}),
  noNuts({'nuts'}),
  noMilk({'milk'}),
  noGluten({'gluten'});

  const DietPreference(this.excludedTags);

  final Set<String> excludedTags;

  static Set<String> excludedTagsOf(Set<DietPreference> preferences) => {
    for (final preference in preferences) ...preference.excludedTags,
  };
}
