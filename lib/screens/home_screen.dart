import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restrictedmodule/main.dart';
import '../providers/product_provider.dart';
import '../widgets/product_list.dart';
import '../widgets/search_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Price Comparison'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          SearchBarWidget(),
          Expanded(
            child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestrictedModulApp(),
                    ),
                  );
                },
                child: Text("Restricted Module Button")),
          ),
          Expanded(
            child: ProductList(),
          ),
        ],
      ),
    );
  }
}
