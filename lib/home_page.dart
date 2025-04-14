import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController barcodeController = TextEditingController();
  String productName = '';
  String ingredients = '';
  String nutritionalContent = '';

  @override
  void dispose() {
    barcodeController.dispose();
    super.dispose();
  }

  Future<void> scanBarcode() async {
    try {
      String barcode = await FlutterBarcodeScanner.scanBarcode(
          "#ff6666", "Cancel", true, ScanMode.BARCODE);
      if (barcode != "-1") {
        barcodeController.text = barcode; // Update input field
        fetchProductData(barcode);
      }
    } catch (e) {
      print('Error scanning barcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning barcode: $e')),
      );
    }
  }

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
            ingredients = 'Fetching';
            nutritionalContent = 'Fetching ';

            // Fetch details from Gemini AI
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

  Future<void> fetchDetailsFromGemini(String productName) async {
    const apiKey = "";

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );

    final prompt =
        "No extra Text Give the Exact Value Strictly What are the ingredients and the nutritional content Also Give in the Format of 2 Paragraphs one is Ingredients and other is Nutritional Facts per 100g. Don't change the line, just change the line for the segregation (specifically providing a single value for each nutrient per 100 grams) of the following food product, keeping in mind it is from India: $productName. Give the Provided Things only Ingredients and Nutritional Information, no extra information. I certainly need only these Information. Just Give me only these info: energy_100g, saturated_fat_100g, sugars_100g, fiber_100g, proteins_100g, salt_100g, fruits_veggies_nuts_estimate_100g, carbohydrates_100g.";
    final content = [Content.text(prompt)];

    try {
      final response = await model.generateContent(content);
      final geminiText = response.text ?? 'No response received';

      List<String> details = geminiText.split('\n\n'); // Split into sections

      // Assuming this is inside a Flutter stateful widget
      setState(() {
        ingredients = details.isNotEmpty ? details[0] : 'No ingredients found';
        nutritionalContent =
            details.length > 1 ? details[1] : 'No nutritional info found';
      });
    } catch (e) {
      print('Error fetching : $e');
      setState(() {
        ingredients = 'Error fetching';
        nutritionalContent = 'Error fetching ';
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
            ],
          ),
        ),
      ),
    );
  }
}
