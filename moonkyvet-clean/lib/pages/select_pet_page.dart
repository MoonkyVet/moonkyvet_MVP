import 'package:flutter/material.dart';

class SelectPetPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select a Pet'),
      ),
      body: Center(
        child: Text('This is the page where the user selects a pet for AI chat.'),
      ),
    );
  }
}
