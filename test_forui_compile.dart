import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FTextField(
            control: FTextFieldControl.managed(
              controller: TextEditingController(),
            ),
          ),
        ),
      ),
    ),
  );
}
