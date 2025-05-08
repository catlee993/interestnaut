import 'package:flutter/material.dart';

class ReasonCard extends StatelessWidget {
  final String reason;
  final BoxDecoration? decoration;

  const ReasonCard({
    Key? key,
    required this.reason,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color.fromRGBO(123, 104, 238, 0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.android, color: Color.fromRGBO(140, 134, 258, 0.7)),
                  SizedBox(width: 8),
                  Text(
                    'Reasoning',
                    style: TextStyle(
                      color: Color.fromRGBO(140, 134, 258, 0.7),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 