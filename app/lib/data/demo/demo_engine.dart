import 'dart:math' as math;

const _epsilon = 1e-6;

class DemoNutrients {
  const DemoNutrients(this.kcal, this.protein, this.fat, this.carbs);

  static const zero = DemoNutrients(0, 0, 0, 0);

  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  DemoNutrients operator +(DemoNutrients other) =>
      DemoNutrients(kcal + other.kcal, protein + other.protein, fat + other.fat, carbs + other.carbs);
}

class DemoDish {
  const DemoDish({
    required this.id,
    required this.name,
    required this.category,
    required this.portionGrams,
    required this.nutrients,
    required this.priceMinor,
    required this.tags,
  });

  final int id;
  final String name;
  final String category;
  final double? portionGrams;
  final DemoNutrients nutrients;
  final int? priceMinor;
  final List<String> tags;
}

class DemoTarget {
  const DemoTarget({
    required this.kcal,
    required this.kcalTolerance,
    required this.minProtein,
    required this.maxFat,
    required this.maxCarbs,
    required this.excludedTags,
  });

  static const kcalStep = 10.0;
  static const gramStep = 5.0;
  static const _precision = 1e-9;

  final double kcal;
  final double kcalTolerance;
  final double minProtein;
  final double maxFat;
  final double maxCarbs;
  final Set<String> excludedTags;

  double get minKcal => kcal - kcalTolerance;

  double get maxKcal => kcal + kcalTolerance;

  bool allows(DemoDish dish) => !dish.tags.any(excludedTags.contains);

  bool isSatisfiedBy(DemoNutrients totals) =>
      totals.kcal >= minKcal - _epsilon &&
      totals.kcal <= maxKcal + _epsilon &&
      totals.protein >= minProtein - _epsilon &&
      totals.fat <= maxFat + _epsilon &&
      totals.carbs <= maxCarbs + _epsilon;

  DemoTarget relaxed() => _copy(
    kcalTolerance: kcalTolerance * 2.0,
    minProtein: minProtein * 0.8,
    maxFat: maxFat * 1.2,
    maxCarbs: maxCarbs * 1.2,
  );

  DemoTarget rounded() {
    final roundedKcal = math.max((kcal / kcalStep).round() * kcalStep, kcalStep);
    final shift = (roundedKcal - kcal).abs();
    return _copy(
      kcal: roundedKcal,
      kcalTolerance: math.max(_floorTo(kcalTolerance - shift), gramStep),
      minProtein: (minProtein / gramStep - _precision).ceil() * gramStep,
      maxFat: _floorTo(maxFat),
      maxCarbs: _floorTo(maxCarbs),
    );
  }

  static double _floorTo(double value) => (value / gramStep + _precision).floor() * gramStep;

  DemoTarget _copy({double? kcal, double? kcalTolerance, double? minProtein, double? maxFat, double? maxCarbs}) =>
      DemoTarget(
        kcal: kcal ?? this.kcal,
        kcalTolerance: kcalTolerance ?? this.kcalTolerance,
        minProtein: minProtein ?? this.minProtein,
        maxFat: maxFat ?? this.maxFat,
        maxCarbs: maxCarbs ?? this.maxCarbs,
        excludedTags: excludedTags,
      );
}

class DemoCombo {
  const DemoCombo({required this.dishes, required this.totals, required this.priceMinor, required this.score});

  final List<DemoDish> dishes;
  final DemoNutrients totals;
  final int? priceMinor;
  final double score;

  List<int> get dishIds => [for (final dish in dishes) dish.id];

  static int compare(DemoCombo left, DemoCombo right) {
    final byScore = left.score.compareTo(right.score);
    if (byScore != 0) return byScore;
    final leftIds = left.dishIds;
    final rightIds = right.dishIds;
    for (var index = 0; index < math.min(leftIds.length, rightIds.length); index++) {
      final byId = leftIds[index].compareTo(rightIds[index]);
      if (byId != 0) return byId;
    }
    return leftIds.length.compareTo(rightIds.length);
  }
}

abstract final class DemoMealStructure {
  static const maxSameDish = 2;
  static const _categoryLimits = {'main': 1, 'drink': 1, 'sauce': 1};
  static const _sauceCarriers = {'main', 'side', 'salad'};

  static bool canAdd(List<DemoDish> picked, DemoDish candidate) {
    final limit = _categoryLimits[candidate.category] ?? 1 << 30;
    return picked.where((dish) => dish.category == candidate.category).length < limit &&
        picked.where((dish) => dish.id == candidate.id).length < maxSameDish;
  }

  static bool isComplete(List<DemoDish> dishes) =>
      !dishes.any((dish) => dish.category == 'sauce') || dishes.any((dish) => _sauceCarriers.contains(dish.category));

  static bool isValid(List<DemoDish> dishes) =>
      dishes.isNotEmpty &&
      [for (var index = 0; index < dishes.length; index++) index].every(
        (index) => canAdd(dishes.sublist(0, index), dishes[index]),
      ) &&
      isComplete(dishes);
}

class DemoScorer {
  const DemoScorer({this.preferCheaper = false});

  static const _kcalWeight = 1.0;
  static const _proteinWeight = 0.6;
  static const _fatWeight = 0.3;
  static const _carbsWeight = 0.1;
  static const _priceWeight = 0.5;
  static const _priceScaleMinor = 100000.0;

  final bool preferCheaper;

  DemoCombo combo(List<DemoDish> dishes, DemoTarget target) {
    final totals = dishes.fold(DemoNutrients.zero, (sum, dish) => sum + dish.nutrients);
    final priceMinor = dishes.any((dish) => dish.priceMinor == null)
        ? null
        : dishes.fold<int>(0, (sum, dish) => sum + dish.priceMinor!);
    return DemoCombo(dishes: dishes, totals: totals, priceMinor: priceMinor, score: score(totals, priceMinor, target));
  }

  double score(DemoNutrients totals, int? priceMinor, DemoTarget target) {
    final kcalTerm = (totals.kcal - target.kcal).abs() / target.kcalTolerance;
    final proteinTerm = target.minProtein <= 0 ? 0.0 : target.minProtein / (target.minProtein + totals.protein);
    final fatTerm = target.maxFat <= 0 ? 0.0 : totals.fat / target.maxFat;
    final carbsTerm = target.maxCarbs <= 0 ? 0.0 : totals.carbs / target.maxCarbs;
    final pricePenalty = preferCheaper
        ? _priceWeight * (priceMinor?.toDouble() ?? _priceScaleMinor) / _priceScaleMinor
        : 0.0;
    return _kcalWeight * kcalTerm +
        _proteinWeight * proteinTerm +
        _fatWeight * fatTerm +
        _carbsWeight * carbsTerm +
        pricePenalty;
  }
}

class DemoOptimizer {
  const DemoOptimizer(this._scorer);

  static const maxItems = 3;
  static const heapFactor = 4;

  final DemoScorer _scorer;

  List<DemoCombo> bestCombos(List<DemoDish> menu, DemoTarget target, int limit) {
    final allowed = menu.where(target.allows).toList()
      ..sort((left, right) {
        final byKcal = left.nutrients.kcal.compareTo(right.nutrients.kcal);
        return byKcal != 0 ? byKcal : left.id.compareTo(right.id);
      });
    final best = _BoundedBest(limit * heapFactor);
    final picked = <DemoDish>[];
    final upperKcal = target.maxKcal + _epsilon;

    void visit(int start, DemoNutrients totals) {
      if (picked.isNotEmpty && target.isSatisfiedBy(totals) && DemoMealStructure.isComplete(picked)) {
        best.offer(_scorer.combo(List.of(picked), target));
      }
      if (picked.length == maxItems) return;
      var index = start;
      while (index < allowed.length && totals.kcal + allowed[index].nutrients.kcal <= upperKcal) {
        final dish = allowed[index];
        if (DemoMealStructure.canAdd(picked, dish)) {
          picked.add(dish);
          visit(index, totals + dish.nutrients);
          picked.removeLast();
        }
        index++;
      }
    }

    visit(0, DemoNutrients.zero);
    return diversify(best.ranked(), limit);
  }

  List<DemoCombo> replacements(
    List<DemoDish> menu,
    DemoTarget target,
    List<DemoDish> dishes,
    int replacedIndex,
    int limit,
  ) {
    final replaced = dishes[replacedIndex];
    final combos =
        menu
            .where((candidate) => candidate.id != replaced.id && target.allows(candidate))
            .map((candidate) => [...dishes]..[replacedIndex] = candidate)
            .where(DemoMealStructure.isValid)
            .map((candidateDishes) => _scorer.combo(candidateDishes, target))
            .where((combo) => target.isSatisfiedBy(combo.totals))
            .toList()
          ..sort(DemoCombo.compare);
    return combos.take(limit).toList();
  }

  static List<DemoCombo> diversify(List<DemoCombo> ranked, int limit) {
    final chosen = <DemoCombo>[];
    for (final candidate in ranked) {
      if (chosen.length < limit && chosen.every((combo) => sharedDishes(combo, candidate) <= 1)) {
        chosen.add(candidate);
      }
    }
    return chosen;
  }

  static int sharedDishes(DemoCombo first, DemoCombo second) {
    Map<int, int> counts(DemoCombo combo) {
      final counts = <int, int>{};
      for (final id in combo.dishIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    }

    final secondCounts = counts(second);
    return counts(
      first,
    ).entries.fold(0, (sum, entry) => sum + math.min(entry.value, secondCounts[entry.key] ?? 0));
  }
}

class _BoundedBest {
  _BoundedBest(this._capacity);

  final int _capacity;
  final List<DemoCombo> _items = [];

  void offer(DemoCombo combo) {
    if (_items.length < _capacity) {
      _items.add(combo);
      return;
    }
    final worst = _items.reduce((left, right) => DemoCombo.compare(left, right) >= 0 ? left : right);
    if (DemoCombo.compare(combo, worst) < 0) {
      _items
        ..remove(worst)
        ..add(combo);
    }
  }

  List<DemoCombo> ranked() => [..._items]..sort(DemoCombo.compare);
}

enum DemoVerdict { fits, partial, notFits }

class DemoReason {
  const DemoReason(this.code, {this.amount, this.tag});

  final String code;
  final double? amount;
  final String? tag;
}

class DemoAssessment {
  const DemoAssessment({required this.dish, required this.verdict, required this.reasons, required this.closeness});

  final DemoDish dish;
  final DemoVerdict verdict;
  final List<DemoReason> reasons;
  final double closeness;
}

class DemoAssessor {
  const DemoAssessor(this._scorer);

  static const _lowProteinShare = 0.75;

  final DemoScorer _scorer;

  List<DemoAssessment> assessMenu(List<DemoDish> menu, DemoTarget target) =>
      menu.map((dish) => assess(dish, target)).toList()..sort((left, right) {
        final byVerdict = left.verdict.index.compareTo(right.verdict.index);
        if (byVerdict != 0) return byVerdict;
        final byCloseness = left.closeness.compareTo(right.closeness);
        return byCloseness != 0 ? byCloseness : left.dish.id.compareTo(right.dish.id);
      });

  DemoAssessment assess(DemoDish dish, DemoTarget target) {
    final excludedTag = dish.tags.where(target.excludedTags.contains).firstOrNull;
    final blocking = [
      if (excludedTag != null) DemoReason('EXCLUDED_TAG', tag: excludedTag),
      ?_excess('KCAL_ABOVE', dish.nutrients.kcal, target.maxKcal),
      ?_excess('FAT_ABOVE', dish.nutrients.fat, target.maxFat),
      ?_excess('CARBS_ABOVE', dish.nutrients.carbs, target.maxCarbs),
    ];
    final proportionalProtein = dish.nutrients.kcal * target.minProtein / target.kcal;
    final warnings = blocking.isNotEmpty
        ? const <DemoReason>[]
        : [
            if (dish.nutrients.protein < proportionalProtein * _lowProteinShare)
              DemoReason('LOW_PROTEIN', amount: proportionalProtein - dish.nutrients.protein),
          ];
    final verdict = blocking.isNotEmpty
        ? DemoVerdict.notFits
        : warnings.isNotEmpty
        ? DemoVerdict.partial
        : DemoVerdict.fits;
    return DemoAssessment(
      dish: dish,
      verdict: verdict,
      reasons: [...blocking, ...warnings],
      closeness: _scorer.score(dish.nutrients, dish.priceMinor, target),
    );
  }

  static DemoReason? _excess(String code, double value, double limit) =>
      value > limit + _epsilon ? DemoReason(code, amount: value - limit) : null;
}

enum DemoMetricStatus { ok, above, below }

class DemoMetricCheck {
  const DemoMetricCheck(this.metric, this.value, this.goal, this.status);

  final String metric;
  final double value;
  final double goal;
  final DemoMetricStatus status;

  double get delta => value - goal;
}

abstract final class DemoExplanation {
  static List<DemoMetricCheck> explain(DemoNutrients totals, DemoTarget target) {
    final kcalDelta = totals.kcal - target.kcal;
    final kcalStatus = kcalDelta.abs() <= target.kcalTolerance + _epsilon
        ? DemoMetricStatus.ok
        : kcalDelta > 0
        ? DemoMetricStatus.above
        : DemoMetricStatus.below;
    return [
      DemoMetricCheck('KCAL', totals.kcal, target.kcal, kcalStatus),
      DemoMetricCheck(
        'PROTEIN',
        totals.protein,
        target.minProtein,
        totals.protein >= target.minProtein - _epsilon ? DemoMetricStatus.ok : DemoMetricStatus.below,
      ),
      DemoMetricCheck(
        'FAT',
        totals.fat,
        target.maxFat,
        totals.fat <= target.maxFat + _epsilon ? DemoMetricStatus.ok : DemoMetricStatus.above,
      ),
      DemoMetricCheck(
        'CARBS',
        totals.carbs,
        target.maxCarbs,
        totals.carbs <= target.maxCarbs + _epsilon ? DemoMetricStatus.ok : DemoMetricStatus.above,
      ),
    ];
  }
}
