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
  final String description;
  final String category;
  final String manufacturer;
  final String imageUrl;
  final String stores;
  final String price;

  ProductInfo({
    required this.name,
    required this.brand,
    required this.description,
    required this.category,
    required this.manufacturer,
    required this.imageUrl,
    required this.stores,
    required this.price,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    final product = json['products'][0]; // Get first product from results
    
    // Handle the images array properly
    String imgUrl = '';
    if (product['images'] != null && product['images'] is List && product['images'].isNotEmpty) {
      imgUrl = product['images'][0].toString();
    }

    return ProductInfo(
      name: product['title']?.toString() ?? 'Unknown',
      brand: product['brand']?.toString() ?? 'Unknown',
      description: product['description']?.toString() ?? 'No description available',
      category: product['category']?.toString() ?? 'Unknown',
      manufacturer: product['manufacturer']?.toString() ?? 'Unknown',
      imageUrl: imgUrl,
      stores: product['stores']?.toString() ?? 'Not available',
      price: product['price']?.toString() ?? 'Not available',
    );
  }
}

class DateInfo {
  final String dateStr;
  final DateTime date;
  final bool isExpiryDate;

  DateInfo(this.dateStr, this.date, this.isExpiryDate);
}

class _MyHomePageState extends State<MyHomePage> {
  String scannedText = '';
  String? expiryDate;
  String? barcodeId;
  List<String> allDates = [];
  ProductInfo? productInfo;
  bool isLoading = false;

  String? extractExpiryDate(String text) {
    final List<RegExp> datePatterns = [
      // DD/MM/YYYY or DD-MM-YYYY
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{4})', caseSensitive: false),
      // DD/MM/YY or DD-MM-YY
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2})', caseSensitive: false),
      // MM/YYYY or MM-YYYY
      RegExp(r'(\d{1,2}[/-]\d{4})', caseSensitive: false),
      // MM/YY or MM-YY
      RegExp(r'(\d{1,2}[/-]\d{2})', caseSensitive: false),
      // YYYY/MM/DD
      RegExp(r'(\d{4}[/-]\d{1,2}[/-]\d{1,2})', caseSensitive: false),
    ];

    // Keywords that indicate expiry date
    final expiryKeywords = RegExp(
      r'(exp|expiry|best before|use by|valid until|bb|consume before)',
      caseSensitive: false
    );

    // Keywords that indicate manufacturing date
    final mfgKeywords = RegExp(
      r'(mfg|manufacturing date|made on|produced on|packed on)',
      caseSensitive: false
    );

    allDates = [];
    List<DateInfo> validDates = [];
    final now = DateTime.now();

    // Split text into lines and process each line
    final lines = text.split('\n');

    for (final line in lines) {
      bool isExpiryLine = line.toLowerCase().contains(expiryKeywords);
      bool isMfgLine = line.toLowerCase().contains(mfgKeywords);

      for (final pattern in datePatterns) {
        final matches = pattern.allMatches(line);
        for (final match in matches) {
          final dateStr = match.group(0)?.trim();
          if (dateStr != null) {
            try {
              DateTime? parsedDate = _parseDate(dateStr);
              if (parsedDate != null && _isValidDate(parsedDate, now)) {
                allDates.add('${dateStr}${isExpiryLine ? ' (EXP)' : isMfgLine ? ' (MFG)' : ''}');
                validDates.add(DateInfo(
                  dateStr,
                  parsedDate,
                  isExpiryLine
                ));
              }
            } catch (e) {
              print('Error parsing date: $dateStr');
            }
          }
        }
      }
    }

    // Sort dates by expiry flag and date value
    validDates.sort((a, b) {
      if (a.isExpiryDate && !b.isExpiryDate) return -1;
      if (!a.isExpiryDate && b.isExpiryDate) return 1;
      return b.date.compareTo(a.date);
    });

    // First try to find the latest expiry date
    final expiryDates = validDates.where((d) => d.isExpiryDate);
    if (expiryDates.isNotEmpty) {
      return expiryDates.first.dateStr;
    }

    // If no expiry date found, return the latest future date
    final futureDates = validDates.where((d) => d.date.isAfter(now));
    if (futureDates.isNotEmpty) {
      return futureDates.first.dateStr;
    }

    // If no future date found, return the latest date
    return validDates.isNotEmpty ? validDates.first.dateStr : null;
  }

  DateTime? _parseDate(String dateStr) {
    final parts = dateStr.split(RegExp(r'[/-]'));
    
    try {
      if (parts.length == 3) {
        int year = int.parse(parts[2]);
        int month = int.parse(parts[1]);
        int day = int.parse(parts[0]);

        // Handle 2-digit year
        if (year < 100) {
          year += 2000;
        }

        // Validate month and day
        if (month > 12) {
          // Might be YYYY/MM/DD format
          if (parts[0].length == 4) {
            year = int.parse(parts[0]);
            month = int.parse(parts[1]);
            day = int.parse(parts[2]);
          } else {
            // Swap day and month if month > 12
            final temp = month;
            month = day;
            day = temp;
          }
        }

        return DateTime(year, month, day);
      } else if (parts.length == 2) {
        int year = int.parse(parts[1]);
        int month = int.parse(parts[0]);

        if (year < 100) year += 2000;
        if (month > 12) return null;

        return DateTime(year, month, 1);
      }
    } catch (e) {
      print('Error parsing date components: $dateStr');
    }
    return null;
  }

  bool _isValidDate(DateTime date, DateTime now) {
    final minYear = now.year - 2; // Don't consider dates more than 2 years old
    final maxYear = now.year + 10; // Don't consider dates more than 10 years in future

    return date.year >= minYear && 
           date.year <= maxYear && 
           date.month >= 1 && 
           date.month <= 12;
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
    final apiKey = 'iw1ygc5e10s0cegwxiifou0pmd95aa';
    
    try {
      final response = await http.get(
        Uri.parse('https://api.barcodelookup.com/v3/products?barcode=$barcode&formatted=y&key=$apiKey')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] != null && data['products'].isNotEmpty) {
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
          scannedText = 'Failed to fetch product information: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        scannedText = 'Error fetching product info: $e';
      });
    }
  }

  Future<void> pickAndScanImage(ImageSource source) async {
    setState(() {
      isLoading = true;
      scannedText = '';
      expiryDate = null;
      barcodeId = null;
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
          setState(() {
            barcodeId = res;
          });
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
                      if (barcodeId != null) ...[
                        InfoCard(
                          title: 'Barcode ID',
                          content: barcodeId!,
                          color: Colors.blue[100],
                        ),
                        const SizedBox(height: 16),
                      ],
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
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        InfoCard(
                          title: 'Product Name',
                          content: productInfo!.name,
                        ),
                        InfoCard(
                          title: 'Brand',
                          content: productInfo!.brand,
                        ),
                        InfoCard(
                          title: 'Category',
                          content: productInfo!.category,
                        ),
                        InfoCard(
                          title: 'Description',
                          content: productInfo!.description,
                        ),
                        InfoCard(
                          title: 'Manufacturer',
                          content: productInfo!.manufacturer,
                        ),
                        InfoCard(
                          title: 'Stores',
                          content: productInfo!.stores,
                        ),
                        InfoCard(
                          title: 'Price',
                          content: productInfo!.price,
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
