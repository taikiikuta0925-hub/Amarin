class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.available,
  });

  final String name;
  final String amount;
  final bool available;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      available: json['available'] == true,
    );
  }
}

class RecipeSuggestion {
  const RecipeSuggestion({
    required this.title,
    required this.description,
    required this.cookTimeMinutes,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.usesRegisteredItems,
    required this.tip,
  });

  final String title;
  final String description;
  final int cookTimeMinutes;
  final String servings;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<String> usesRegisteredItems;
  final String tip;

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'];
    final rawSteps = json['steps'];
    final rawUses = json['usesRegisteredItems'];
    return RecipeSuggestion(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      cookTimeMinutes: (json['cookTimeMinutes'] as num?)?.round() ?? 0,
      servings: json['servings'] as String? ?? '',
      ingredients: rawIngredients is List
          ? rawIngredients
                .whereType<Map<String, dynamic>>()
                .map(RecipeIngredient.fromJson)
                .toList()
          : const [],
      steps: rawSteps is List
          ? rawSteps.whereType<String>().toList()
          : const [],
      usesRegisteredItems: rawUses is List
          ? rawUses.whereType<String>().toList()
          : const [],
      tip: json['tip'] as String? ?? '',
    );
  }
}
