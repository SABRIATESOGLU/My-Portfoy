import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StockPortfolioPage extends StatefulWidget {
  const StockPortfolioPage({super.key});

  @override
  _StockPortfolioState createState() => _StockPortfolioState();
}

class _StockPortfolioState extends State<StockPortfolioPage> {
  Map<String, dynamic> stockPrices = {}; // Hisselerin fiyatları
  bool isLoading = false; // Veri çekilirken gösterilecek durum
  List<Map<String, dynamic>> stockPortfolio = []; // Hisse portföyü

  TextEditingController stockController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController costController = TextEditingController();

  double totalPortfolioValue = 0.0;
  DateTime? selectedDate;

  final String finnhubApiKey =
      'cttaen1r01qqhvb04dm0cttaen1r01qqhvb04dmg'; // API anahtarınızı buraya yazın.

  Future<void> fetchStockData() async {
    setState(() {
      isLoading = true;
    });

    String symbols = stockPortfolio.map((e) => e['symbol']).join(',');
    if (symbols.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      for (var stock in stockPortfolio) {
        String symbol = stock['symbol'];
        final url =
            'https://finnhub.io/api/v1/quote?symbol=$symbol&token=$finnhubApiKey';
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data != null && data['c'] != null) {
            setState(() {
              stockPrices[symbol] = data; // Veriyi fiyatlar map'ine ekle
            });
          }
        }
      }
      calculateTotalPortfolioValue(); // Toplam portföy değerini hesapla
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void addStock() {
    String symbol = stockController.text.trim().toUpperCase();
    double quantity = double.tryParse(quantityController.text) ?? 0;
    double cost = double.tryParse(costController.text) ?? 0;

    if (symbol.isNotEmpty && quantity > 0 && cost > 0 && selectedDate != null) {
      setState(() {
        stockPortfolio.add({
          'symbol': symbol,
          'quantity': quantity,
          'cost': cost,
          'date': selectedDate!.toIso8601String().split('T')[0],
        });
      });
      saveStockPortfolio();
      fetchStockData();
    }

    stockController.clear();
    quantityController.clear();
    costController.clear();
    selectedDate = null;
  }

  void calculateTotalPortfolioValue() {
    double total = 0.0;
    for (var stock in stockPortfolio) {
      String symbol = stock['symbol'];
      double quantity = stock['quantity'];
      double price = stockPrices[symbol]?['c'] ?? 0; // 'c' = current price
      total += quantity * price;
    }
    setState(() {
      totalPortfolioValue = total;
    });
  }

  Future<void> saveStockPortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> encodedPortfolio =
        stockPortfolio.map((stock) => json.encode(stock)).toList();
    await prefs.setStringList('stockPortfolio', encodedPortfolio);
  }

  Future<void> loadStockPortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? encodedPortfolio = prefs.getStringList('stockPortfolio');
    if (encodedPortfolio != null) {
      setState(() {
        stockPortfolio = encodedPortfolio
            .map((stock) => json.decode(stock) as Map<String, dynamic>)
            .where((stock) => stock['symbol'] != null)
            .toList();
      });
      fetchStockData();
    }
  }

  void updateStockQuantityAndCost(
      int index, double addedQuantity, double newCost) {
    setState(() {
      double currentQuantity = stockPortfolio[index]['quantity'];
      double currentCost = stockPortfolio[index]['cost'];

      double totalQuantity = currentQuantity + addedQuantity;
      double totalCost =
          (currentCost * currentQuantity + newCost * addedQuantity) /
              totalQuantity;

      stockPortfolio[index]['quantity'] = totalQuantity;
      stockPortfolio[index]['cost'] = totalCost;
    });

    saveStockPortfolio();
    calculateTotalPortfolioValue();
  }

  @override
  void initState() {
    super.initState();
    loadStockPortfolio();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hisse Portföyü'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockController,
                        decoration: const InputDecoration(
                          labelText: 'Hisse Sembolü',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Adet',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Maliyet Fiyatı',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: selectedDate == null
                                  ? 'Tarih Seç'
                                  : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: addStock,
                  child: const Text('Ekle'),
                ),
              ],
            ),
          ),
          isLoading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: stockPortfolio.length,
                    itemBuilder: (context, index) {
                      final stock = stockPortfolio[index];
                      final symbol = stock['symbol'];
                      final quantity = stock['quantity'];
                      final cost = stock['cost'];
                      final date = stock['date'];
                      final price =
                          stockPrices[symbol]?['c'] ?? 0; // 'c' = current price
                      final currentValue = quantity * price;

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Text(
                              '$symbol - Güncel: \$${price.toStringAsFixed(2)}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Adet: $quantity'),
                              Text('Maliyet: \$${cost.toStringAsFixed(2)}'),
                              Text('Tarih: $date'),
                              Text(
                                  'Toplam Değer: \$${currentValue.toStringAsFixed(2)}'),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () async {
                                      final addedQuantityController =
                                          TextEditingController();
                                      final newCostController =
                                          TextEditingController();

                                      await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Alım İşlemi'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller:
                                                    addedQuantityController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Alınacak Adet',
                                                ),
                                              ),
                                              TextField(
                                                controller: newCostController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Alım Fiyatı',
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('İptal'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                double addedQuantity =
                                                    double.tryParse(
                                                            addedQuantityController
                                                                .text) ??
                                                        0;
                                                double newCost =
                                                    double.tryParse(
                                                            newCostController
                                                                .text) ??
                                                        0;
                                                if (addedQuantity > 0 &&
                                                    newCost > 0) {
                                                  updateStockQuantityAndCost(
                                                      index,
                                                      addedQuantity,
                                                      newCost);
                                                }
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Onayla'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text('Al'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final sellQuantityController =
                                          TextEditingController();

                                      await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Satış İşlemi'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller:
                                                    sellQuantityController,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Satılacak Adet',
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('İptal'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                double sellQuantity =
                                                    double.tryParse(
                                                            sellQuantityController
                                                                .text) ??
                                                        0;
                                                if (sellQuantity > 0) {
                                                  setState(() {
                                                    if (sellQuantity >
                                                        stockPortfolio[index]
                                                            ['quantity']) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                              'Hata: Satılacak adet, mevcut adetten fazla olamaz!'),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    } else {
                                                      stockPortfolio[index]
                                                              ['quantity'] -=
                                                          sellQuantity;
                                                      if (stockPortfolio[index]
                                                              ['quantity'] ==
                                                          0) {
                                                        stockPortfolio.removeAt(
                                                            index); // Adet sıfırsa hisseyi kaldır
                                                      }
                                                      saveStockPortfolio();
                                                      calculateTotalPortfolioValue();
                                                    }
                                                  });
                                                  Navigator.of(context).pop();
                                                }
                                              },
                                              child: const Text('Onayla'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text('Sat'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Toplam Değer: \$${totalPortfolioValue.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
