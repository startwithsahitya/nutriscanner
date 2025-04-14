import 'dart:math';

/// Predicts the Nutri-Score (A–E) from a list of 8 nutritional features.
String predictNutriScore(List<double> inputFeatures) {
  // Validate that exactly 8 features are provided.
  if (inputFeatures.length != 8) {
    throw ArgumentError(
        "Expected exactly 8 nutritional features, but got ${inputFeatures.length}.");
  }

  // Mean and standard deviation values for normalization.
  final List<double> mean = [
    1067.47619469,
    4.55465717,
    15.64480898,
    2.22087765,
    6.14093092,
    2.07412382,
    63.74801479,
    33.71262432
  ];
  final List<double> std = [
    795.832468,
    7.21078974,
    21.0735161,
    3.3305593,
    8.50975841,
    45.5886691,
    0.465373605,
    31.0040239
  ];

  // Coefficients for 5 classes (5×8 matrix)
  final List<List<double>> coefficients = [
    [
      -0.648593009,
      -3.26911908,
      -1.94489582,
      0.804726391,
      0.703769718,
      -18.0886262,
      0.000253052936,
      -0.259972104
    ],
    [
      0.356457263,
      -0.469507012,
      -1.04178498,
      -0.0114109888,
      -0.531903885,
      -14.7474178,
      0.00195639747,
      -0.459694727
    ],
    [
      0.375697572,
      0.0838146878,
      -0.327468114,
      0.300108973,
      -0.299580133,
      -0.86990195,
      0.0820146481,
      -0.364157486
    ],
    [
      -0.120744911,
      1.58489049,
      1.44998616,
      -0.347695173,
      0.302092535,
      16.2918824,
      0.00458090168,
      0.552009867
    ],
    [
      0.0371830847,
      2.06992091,
      1.86416275,
      -0.745729203,
      -0.174378235,
      17.4140636,
      -0.0888050002,
      0.531814451
    ]
  ];

  // Intercepts for each class.
  final List<double> intercept = [
    -3.03319761,
    -0.59980749,
    0.50823897,
    1.69817278,
    1.42659336
  ];

  // Nutri-Score grade labels.
  final List<String> grades = ['A', 'B', 'C', 'D', 'E'];

  // Standardize the input features.
  List<double> scaled =
      List.generate(8, (i) => (inputFeatures[i] - mean[i]) / std[i]);

  // Compute logits for each class.
  List<double> logits = List.generate(5, (i) {
    double dot = intercept[i];
    for (int j = 0; j < 8; j++) {
      dot += coefficients[i][j] * scaled[j];
    }
    return dot;
  });

  // Softmax: Compute probabilities.
  double maxLogit = logits.reduce(max);
  List<double> expScores = logits.map((l) => exp(l - maxLogit)).toList();
  double sumExp = expScores.reduce((a, b) => a + b);
  List<double> probs = expScores.map((e) => e / sumExp).toList();

  // Find the grade with the maximum probability.
  int prediction = probs.indexWhere((p) => p == probs.reduce(max));
  return grades[prediction];
}
