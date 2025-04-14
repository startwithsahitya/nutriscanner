import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'evalv.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController barcodeController = TextEditingController();

  // Product data and grades.
  String productName = '';
  String ingredients = '';
  String nutritionalContent = '';
  String modelGrade =
      ''; // Grade from the nutritional model (predictNutriScore)
  String geminiGrade = ''; // Grade from Gemini's initial evaluation
  String finalGrade = ''; // Combined grade from model and Gemini
  String healthConditionGrade =
      ''; // New grade based on health condition evaluation

  // Health condition dropdown selections.
  String selectedCondition = 'None';
  final List<String> healthConditions = [
    'None',
    'Diabetes',
    'Chronic Kidney Disease',
    'Heart Disease',
    'Celiac Disease'
  ];

  @override
  void dispose() {
    barcodeController.dispose();
    super.dispose();
  }

  // Scans a barcode and resets state.
  Future<void> scanBarcode() async {
    try {
      String barcode = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Cancel", true, ScanMode.BARCODE);
      if (barcode != "-1") {
        setState(() {
          productName = '';
          ingredients = 'Fetching...';
          nutritionalContent = 'Fetching...';
          modelGrade = '';
          geminiGrade = '';
          finalGrade = '';
          healthConditionGrade = '';
          selectedCondition = 'None';
        });
        barcodeController.text = barcode;
        fetchProductData(barcode);
      }
    } catch (e) {
      print('Error scanning barcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning barcode: $e')),
      );
    }
  }

  // Fetches product data from OpenFoodFacts.
  Future<void> fetchProductData(String barcode) async {
    if (barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a barcode')),
      );
      return;
    }
    final url = 'https://world.openfoodfacts.org/api/v0/product/$barcode.json';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (data['status'] == 1) {
            productName =
                data['product']['product_name'] ?? 'No name available';
            ingredients = 'Fetching...';
            nutritionalContent = 'Fetching...';
            // Fetch details (ingredients, nutritional info, and Gemini grade) from Gemini.
            fetchDetailsFromGemini(productName);
          } else {
            productName = 'Product not found';
            ingredients = 'No ingredients available';
            nutritionalContent = 'No nutritional info available';
          }
        });
      } else {
        setState(() => productName = 'Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching product data: $e');
      setState(() => productName = 'Error fetching product data');
    }
  }

  // Calls Gemini AI to fetch ingredients, nutritional info, and an initial grade.
  Future<void> fetchDetailsFromGemini(String productName) async {
    const apiKey = "";
    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
    // Ask Gemini to return exactly three paragraphs: ingredients, nutritional info (as comma-separated values), and a grade.
    final prompt =
        "No extra text. Provide exactly three paragraphs separated by newlines. The first paragraph should only include the ingredients of $productName. The second paragraph should contain the nutritional facts per 100g of the $productName in the following format: \"Energy: X kcal, Saturated fat: Y g, Sugars: Z g, Fiber: W g, Proteins: V g, Salt: U g, Fruits_vegies_nuts_estimate: T g, Carbohydrates: S g.\" The third paragraph should only be a single letter (A–E) that represents the product's overall quality based solely on nutritional facts. Do not include any titles or extra text. Go easy on Grade no strict grading";
    final content = [Content.text(prompt)];
    try {
      final response = await model.generateContent(content);
      final geminiText = response.text ?? 'No response received';
      List<String> details = geminiText.split('\n\n');
      setState(() {
        ingredients = details.isNotEmpty ? details[0] : 'No ingredients found';
        nutritionalContent =
            details.length > 1 ? details[1] : 'No nutritional info found';
        geminiGrade = details.length > 2 ? details[2].trim().toUpperCase() : '';
      });
      // Calculate the grade from nutritional data.
      calculateModelGrade();
    } catch (e) {
      print('Error fetching details from Gemini: $e');
      setState(() {
        ingredients = 'Error fetching details';
        nutritionalContent = 'Error fetching nutritional info';
        geminiGrade = '';
      });
    }
  }

  // Parses nutritionalContent and uses predictNutriScore to compute the grade from nutritional data.
  void calculateModelGrade() {
    String cleaned = nutritionalContent.trim();
    if (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    cleaned =
        cleaned.replaceFirst(RegExp(r'^[Nn]utritional [Ii]nformation:\s*'), '');

    List<String> parts = cleaned.split(',');
    List<double> features = [];
    RegExp regex = RegExp(r'([-+]?\d*\.?\d+)');
    for (String part in parts) {
      Match? match = regex.firstMatch(part.trim());
      if (match != null) {
        double value = double.parse(match.group(0)!);
        features.add(value);
      }
    }
    // Substitute extreme value if necessary.
    if (features.length == 8 && features[6] == 0) {
      features[6] = 63.75;
    }

    if (features.length == 8) {
      String grade = predictNutriScore(features);
      setState(() {
        modelGrade = grade;
      });
      // Now combine Gemini and model grades.
      combineGrades();
    } else {
      setState(() {
        modelGrade = 'Insufficient data';
      });
    }
  }

  /// Combines the model grade and Gemini grade with weightage (0.55 for model, 0.45 for Gemini).
  void combineGrades() {
    Map<String, double> gradeMapping = {
      'A': 5.0,
      'B': 4.0,
      'C': 3.0,
      'D': 2.0,
      'E': 1.0,
    };
    if (!gradeMapping.containsKey(modelGrade) ||
        !gradeMapping.containsKey(geminiGrade)) {
      setState(() {
        finalGrade = 'Insufficient data';
      });
      return;
    }
    double modelScore = gradeMapping[modelGrade]!;
    double geminiScore = gradeMapping[geminiGrade]!;
    double combinedScore = 0.55 * modelScore + 0.45 * geminiScore;
    String finalLetter;
    if (combinedScore >= 4.3) {
      finalLetter = 'A';
    } else if (combinedScore >= 3.4) {
      finalLetter = 'B';
    } else if (combinedScore >= 2.5) {
      finalLetter = 'C';
    } else if (combinedScore >= 1.5) {
      finalLetter = 'D';
    } else {
      finalLetter = 'E';
    }
    setState(() {
      finalGrade = finalLetter;
    });
    // If a health condition is already selected, evaluate health condition grade.
    if (selectedCondition != 'None') {
      evaluateHealthCondition();
    }
  }

  /// Sends a prompt to Gemini to compute an overall grade taking into account health condition.
  void evaluateHealthCondition() async {
    const apiKey = "";
    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
    // Construct the prompt with nutritional facts, final grade and selected health condition.
    final prompt =
        "Based on the following nutritional facts: \"$nutritionalContent\", and the overall grade: \"$finalGrade\", and considering the health condition: \"$selectedCondition\", please re-evaluate and provide a single letter grade (A–E) reflecting the product's suitability for someone with that health condition. Respond with only the grade letter.";
    final content = [Content.text(prompt)];
    try {
      final response = await model.generateContent(content);
      final text = response.text ?? 'No response';
      // Expecting a single letter grade in response.
      setState(() {
        healthConditionGrade = text.trim().toUpperCase();
      });
    } catch (e) {
      print("Error evaluating health condition: $e");
      setState(() {
        healthConditionGrade = 'Error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                onPressed: scanBarcode,
                child: const Text('Scan Barcode'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Enter Barcode Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => fetchProductData(barcodeController.text),
                child: const Text('Get Product Details'),
              ),
              const SizedBox(height: 20),
              Text(
                'Product Name: $productName',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Ingredients:',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(ingredients, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 10),
              Text(
                'Nutritional Information:',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(nutritionalContent,
                    style: const TextStyle(fontSize: 14)),
              ),

              const SizedBox(height: 10),
              Text(
                'Grade:',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(finalGrade, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              // New Health Condition Dropdown
              Text(
                'Health Condition:',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: selectedCondition,
                items: healthConditions.map((String condition) {
                  return DropdownMenuItem<String>(
                    value: condition,
                    child: Text(condition),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedCondition = newValue;
                      // If condition is not "None", evaluate the health condition grade.
                      if (newValue != 'None') {
                        evaluateHealthCondition();
                      } else {
                        healthConditionGrade = '';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Health Condition Grade:',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  healthConditionGrade.isNotEmpty
                      ? healthConditionGrade
                      : 'Not evaluated',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
