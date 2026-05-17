import 'package:flutter/material.dart';

import '../utils/hebrew_strings.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(HebrewStrings.loading),
        ],
      ),
    );
  }
}
