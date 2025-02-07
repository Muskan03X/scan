import 'package:flutter/material.dart';
import '../models/product_info.dart';

class ResultsPage extends StatelessWidget {
  final String? barcodeId;
  final String? expiryDate;
  final String scannedText;
  final ProductInfo? productInfo;

  const ResultsPage({
    Key? key,
    this.barcodeId,
    this.expiryDate,
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
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (productInfo?.imageUrl != null && productInfo!.imageUrl.isNotEmpty) ...[
                  Center(
                    child: Image.network(
                      productInfo!.imageUrl,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 200,
                          child: Center(
                            child: Icon(Icons.image_not_supported, size: 50),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (productInfo?.name != null) ...[
                  Text(
                    'Product Name',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(productInfo!.name),
                  const SizedBox(height: 16),
                ],
                if (productInfo?.description != null) ...[
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(productInfo!.description),
                  const SizedBox(height: 16),
                ],
                if (barcodeId != null) ...[
                  Text(
                    'Barcode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(barcodeId!),
                  const SizedBox(height: 16),
                ],
                if (expiryDate != null) ...[
                  Text(
                    'Expiry Date',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(expiryDate!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 