import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Scanner',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Document Scanner'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class ProductInfo {
  final String name;
  final String brand;
  final String quantity;
  final String ingredients;
  final String allergens;
  final Map<String, dynamic> nutrients;
  final String imageUrl;

  ProductInfo({
    required this.name,
    required this.brand,
    required this.quantity,
    required this.ingredients,
    required this.allergens,
    required this.nutrients,
    required this.imageUrl,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    return ProductInfo(
      name: product['product_name'] ?? 'Unknown',
      brand: product['brands'] ?? 'Unknown',
      quantity: product['quantity'] ?? 'Unknown',
      ingredients: product['ingredients_text'] ?? 'No ingredients information',
      allergens: product['allergens'] ?? 'No allergens information',
      nutrients: product['nutriments'] ?? {},
      imageUrl: product['image_url'] ?? '',
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  String scannedText = '';
  String? expiryDate;
  List<String> allDates = [];  // Add this to store all dates
  ProductInfo? productInfo;
  bool isLoading = false;

  // Updated function to extract and compare dates
  String? extractExpiryDate(String text) {
    // Common date formats
    final List<RegExp> datePatterns = [
      // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      // MM/YYYY or MM-YYYY
      RegExp(r'(\d{1,2}[/-]\d{2,4})', caseSensitive: false),
    ];

    allDates = [];  // Clear previous dates
    DateTime? latestDate;
    String? latestDateStr;

    // Split text into lines for better processing
    final lines = text.split('\n');

    for (final line in lines) {
      for (final pattern in datePatterns) {
        final matches = pattern.allMatches(line);
        for (final match in matches) {
          final dateStr = match.group(0)?.trim();
          if (dateStr != null) {
            allDates.add(dateStr);  // Add to all dates list
            
            try {
              DateTime? parsedDate;
              // Try different date formats
              if (dateStr.contains('/') || dateStr.contains('-')) {
                final parts = dateStr.split(RegExp(r'[/-]'));
                if (parts.length == 3) {
                  // DD/MM/YYYY format
                  int year = int.parse(parts[2]);
                  if (year < 100) year += 2000;  // Convert 2-digit year to 4-digit
                  parsedDate = DateTime(year, int.parse(parts[1]), int.parse(parts[0]));
                } else if (parts.length == 2) {
                  // MM/YYYY format
                  int year = int.parse(parts[1]);
                  if (year < 100) year += 2000;
                  parsedDate = DateTime(year, int.parse(parts[0]), 1);
                }
              }

              if (parsedDate != null) {
                if (latestDate == null || parsedDate.isAfter(latestDate)) {
                  latestDate = parsedDate;
                  latestDateStr = dateStr;
                }
              }
            } catch (e) {
              // Skip invalid dates
              print('Error parsing date: $dateStr');
            }
          }
        }
      }
    }

    return latestDateStr;
  }

  Future<void> showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  pickAndScanImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  pickAndScanImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> fetchProductInfo(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          setState(() {
            productInfo = ProductInfo.fromJson(data);
          });
        } else {
          setState(() {
            scannedText = 'Product not found';
          });
        }
      } else {
        setState(() {
          scannedText = 'Failed to fetch product information';
        });
      }
    } catch (e) {
      setState(() {
        scannedText = 'Error: $e';
      });
    }
  }

  Future<void> pickAndScanImage(ImageSource source) async {
    setState(() {
      isLoading = true;
      scannedText = '';
      expiryDate = null;
      productInfo = null;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        // Text Recognition
        final inputImage = InputImage.fromFilePath(image.path);
        final textRecognizer = TextRecognizer();
        final RecognizedText recognizedText = 
            await textRecognizer.processImage(inputImage);
        textRecognizer.close();

        // Extract expiry date from recognized text
        final extractedDate = extractExpiryDate(recognizedText.text);

        setState(() {
          scannedText = recognizedText.text;
          expiryDate = extractedDate;
        });

        // Barcode Scanning
        var res = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SimpleBarcodeScannerPage(),
          ),
        );

        if (res is String && res != "-1") {
          await fetchProductInfo(res);
        }
      }
    } catch (e) {
      setState(() {
        scannedText = 'Error occurred while scanning: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the pickAndScanImage method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton.icon(
              onPressed: isLoading ? null : showImageSourceOptions,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan Document'),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (productInfo != null) ...[
                        Text(
                          'Product Information:',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        if (productInfo!.imageUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              productInfo!.imageUrl,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Text('Image not available'),
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        InfoCard(
                          title: 'Name',
                          content: productInfo!.name,
                        ),
                        InfoCard(
                          title: 'Brand',
                          content: productInfo!.brand,
                        ),
                        InfoCard(
                          title: 'Quantity',
                          content: productInfo!.quantity,
                        ),
                        InfoCard(
                          title: 'Allergens',
                          content: productInfo!.allergens,
                        ),
                        InfoCard(
                          title: 'Nutrients per 100g',
                          content: '''
Energy: ${productInfo!.nutrients['energy-kcal_100g']} kcal
Proteins: ${productInfo!.nutrients['proteins_100g']} g
Carbohydrates: ${productInfo!.nutrients['carbohydrates_100g']} g
Fat: ${productInfo!.nutrients['fat_100g']} g
''',
                        ),
                        const Divider(height: 32),
                      ],
                      if (expiryDate != null) ...[
                        InfoCard(
                          title: 'Expiry Date',
                          content: expiryDate!,
                          color: Colors.amber[100],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (allDates.isNotEmpty) ...[
                        InfoCard(
                          title: 'All Detected Dates',
                          content: allDates.join('\n'),
                          color: Colors.grey[100],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (scannedText.isNotEmpty) ...[
                        Text(
                          'Scanned Text:',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(scannedText),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final Color? color;  // Add color parameter

  const InfoCard({
    Key? key,
    required this.title,
    required this.content,
    this.color,  // Make it optional
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,  // Use the color if provided
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(content),
          ],
        ),
      ),
    );
  }
}
