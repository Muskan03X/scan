import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/product_info.dart';
import '../screens/results_page.dart';

class ScanScreen extends StatefulWidget {
  final ImageSource source;
  const ScanScreen({super.key, required this.source});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool isLoading = false;
  List<String> allDates = [];

  @override
  void initState() {
    super.initState();
    // Start scanning immediately when screen opens
    scanDocument(widget.source);
  }

  Future<void> scanDocument(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        String scannedText = '';
        String? expiryDate;
        String? barcodeId;
        ProductInfo? productInfo;

        // Text Recognition
        try {
          final inputImage = InputImage.fromFilePath(image.path);
          final textRecognizer = TextRecognizer();
          final RecognizedText recognizedText = 
              await textRecognizer.processImage(inputImage);
          textRecognizer.close();

          scannedText = recognizedText.text;
          expiryDate = extractExpiryDate(recognizedText.text);
        } catch (e) {
          print('OCR Error: $e');
        }

        // Barcode Scanning
        try {
          var res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SimpleBarcodeScannerPage(),
            ),
          );

          if (res is String && res != "-1") {
            barcodeId = res;
            try {
              productInfo = await fetchProductInfo(res);
            } catch (e) {
              print('Product Info Error: $e');
            }
          }
        } catch (e) {
          print('Barcode Error: $e');
        }

        // Navigate to results page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResultsPage(
                barcodeId: barcodeId,
                expiryDate: expiryDate,
                scannedText: scannedText,
                productInfo: productInfo,
              ),
            ),
          );
        }
      } else {
        // If no image was selected, go back
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Scanning Error: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  // Add the missing methods
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
    ];

    List<DateTime> dates = [];
    List<String> dateStrings = [];
    final now = DateTime.now();

    DateTime? parseDate(String dateStr) {
      try {
        final parts = dateStr.split(RegExp(r'[/-]'));
        
        if (parts.length == 3) {
          // DD/MM/YYYY or DD/MM/YY
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);

          // Handle 2-digit year
          if (year < 100) {
            // If year is less than current 2-digit year + 10, assume it's 20xx
            int currentYear = now.year % 100;
            if (year < currentYear + 10) {
              year += 2000;
            } else {
              year += 1900;
            }
          }

          // Validate and swap if needed
          if (month > 12) {
            // Might be DD/MM swapped
            int temp = month;
            month = day;
            day = temp;
          }

          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            return DateTime(year, month, day);
          }
        } else if (parts.length == 2) {
          // MM/YYYY or MM/YY
          int month = int.parse(parts[0]);
          int year = int.parse(parts[1]);

          // Handle 2-digit year
          if (year < 100) {
            year += 2000;
          }

          // Validate month
          if (month >= 1 && month <= 12) {
            return DateTime(year, month, 1);
          }
        }
      } catch (e) {
        print('Error parsing date: $dateStr');
      }
      return null;
    }

    // First collect all dates from the text
    for (final line in text.split('\n')) {
      for (final pattern in datePatterns) {
        final matches = pattern.allMatches(line);
        for (final match in matches) {
          final dateStr = match.group(0)?.trim();
          if (dateStr != null) {
            DateTime? date = parseDate(dateStr);
            if (date != null && _isValidDate(date, now)) {
              dates.add(date);
              dateStrings.add(dateStr);
              allDates.add('$dateStr (${date.year})');
              print('Found date: $dateStr -> ${date.toString()}'); // Debug print
            }
          }
        }
      }
    }

    if (dates.isEmpty) {
      print('No valid dates found in text'); // Debug print
      return null;
    }

    // Find the latest date
    int latestIndex = 0;
    DateTime latestDate = dates[0];
    
    for (int i = 1; i < dates.length; i++) {
      if (dates[i].isAfter(latestDate)) {
        latestIndex = i;
        latestDate = dates[i];
      }
    }

    print('Selected expiry date: ${dateStrings[latestIndex]}'); // Debug print
    return dateStrings[latestIndex];
  }

  bool _isValidDate(DateTime date, DateTime now) {
    final minYear = now.year - 2; // Consider dates up to 2 years old
    final maxYear = now.year + 10; // Don't consider dates more than 10 years in future

    return date.year >= minYear && 
           date.year <= maxYear && 
           date.month >= 1 && 
           date.month <= 12;
  }

  Future<ProductInfo?> fetchProductInfo(String barcode) async {
    final apiKey = 'iw1ygc5e10s0cegwxiifou0pmd95aa';
    
    try {
      final response = await http.get(
        Uri.parse('https://api.barcodelookup.com/v3/products?barcode=$barcode&formatted=y&key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] != null && data['products'].isNotEmpty) {
          return ProductInfo.fromJson(data);
        }
      }
    } catch (e) {
      print('Error fetching product info: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while camera is opening
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 