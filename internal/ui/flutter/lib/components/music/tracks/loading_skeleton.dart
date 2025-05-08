import 'package:flutter/material.dart';

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900
            ? 4
            : MediaQuery.of(context).size.width > 600
                ? 2
                : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 210 / 200,
      ),
      itemCount: 8,
      itemBuilder: (context, i) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 210,
                height: 118,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                margin: const EdgeInsets.only(bottom: 12),
              ),
              Container(
                width: 0.8 * 210,
                height: 16,
                color: Colors.grey[700],
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
              Container(
                width: 0.6 * 210,
                height: 16,
                color: Colors.grey[700],
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
              Container(
                width: 0.4 * 210,
                height: 16,
                color: Colors.grey[700],
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
            ],
          ),
        );
      },
    );
  }
} 