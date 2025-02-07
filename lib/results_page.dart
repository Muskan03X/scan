import 'package:flutter/material.dart';
import 'widgets/info_card.dart';

class ResultsPage extends StatelessWidget {
  final String? barcodeId;
  final String? expiryDate;
  final List<String> allDates;
  final String scannedText;
  final dynamic productInfo;

  const ResultsPage({
    Key? key,
    this.barcodeId,
    this.expiryDate,
    required this.allDates,
    required this.scannedText,
    this.productInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Results'),
      ),
      body: SingleChildScrollView(
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
              InfoCard(
                title: 'Product Info',
                content: productInfo.toString(),
                color: Colors.green[100],
              ),
              const SizedBox(height: 16),
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
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(scannedText),
            ],
          ],
        ),
      ),
    );
  }
} 