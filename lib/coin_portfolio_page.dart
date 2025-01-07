import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CoinPortfolioPage extends StatefulWidget {
  @override
  _CoinPortfolioState createState() => _CoinPortfolioState();
}

class _CoinPortfolioState extends State<CoinPortfolioPage> {
  Map<String, dynamic> coinPrices = {};
  Map<String, String> coinLogos = {};
  bool isLoading = false;
  List<Map<String, dynamic>> portfolio = [];

  TextEditingController coinController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController costController = TextEditingController();

  double totalPortfolioValue = 0.0;
  DateTime? selectedDate;

  Future<String> getPortfolioFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/portfolio.json';
  }

  Future<void> savePortfolioToFile() async {
    final filePath = await getPortfolioFilePath();
    final file = File(filePath);
    List<String> encodedPortfolio =
        portfolio.map((coin) => json.encode(coin)).toList();
    await file.writeAsString(json.encode(encodedPortfolio));
  }

  Future<void> loadPortfolioFromFile() async {
    final filePath = await getPortfolioFilePath();
    final file = File(filePath);

    if (await file.exists()) {
      final content = await file.readAsString();
      List<dynamic> decodedPortfolio = json.decode(content);

      setState(() {
        portfolio = decodedPortfolio
            .map((coin) => json.decode(coin) as Map<String, dynamic>)
            .toList();
      });
      fetchCoinData();
    }
  }

  Future<void> fetchCoinData() async {
    setState(() {
      isLoading = true;
    });

    String ids = portfolio.map((e) => e['name']).join(',');
    if (ids.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    const baseUrl = 'https://api.coingecko.com/api/v3/';
    final priceUrl = '$baseUrl/simple/price?ids=$ids&vs_currencies=usd';
    final logoUrl = '$baseUrl/coins/markets?vs_currency=usd&ids=$ids';

    try {
      final priceResponse = await http.get(Uri.parse(priceUrl));
      if (priceResponse.statusCode == 200) {
        final data = json.decode(priceResponse.body);
        setState(() {
          coinPrices = data;
        });
      }

      final logoResponse = await http.get(Uri.parse(logoUrl));
      if (logoResponse.statusCode == 200) {
        final data = json.decode(logoResponse.body) as List;
        setState(() {
          coinLogos = {
            for (var coin in data) coin['id']: coin['image'] as String,
          };
        });
      }

      calculateTotalPortfolioValue();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void addCoin() {
    String coin = coinController.text.trim().toLowerCase();
    double quantity = double.tryParse(quantityController.text) ?? 0;
    double cost = double.tryParse(costController.text) ?? 0;

    if (coin.isNotEmpty && quantity > 0 && cost > 0 && selectedDate != null) {
      setState(() {
        portfolio.add({
          'name': coin,
          'quantity': quantity,
          'cost': cost,
          'date': selectedDate!.toIso8601String().split('T')[0],
        });
      });
      savePortfolioToFile();
      fetchCoinData();
    }

    coinController.clear();
    quantityController.clear();
    costController.clear();
    selectedDate = null;
  }

  void calculateTotalPortfolioValue() {
    double total = 0.0;
    for (var coin in portfolio) {
      String name = coin['name'];
      double quantity =
          (coin['quantity'] as num).toDouble(); // Ensure type safety
      double price = (coinPrices[name]?['usd'] as num?)?.toDouble() ?? 0.0;
      total += quantity * price;
    }
    setState(() {
      totalPortfolioValue = total;
    });
  }

  void manageCoin(int index, bool isBuying) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController actionController = TextEditingController();
        TextEditingController? priceController =
            isBuying ? TextEditingController() : null;

        return AlertDialog(
          title: Text(
            isBuying
                ? 'Alım İşlemi (${portfolio[index]['name'].toUpperCase()})'
                : 'Satış İşlemi (${portfolio[index]['name'].toUpperCase()})',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: actionController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isBuying ? 'Alınacak Miktar' : 'Satılacak Miktar',
                  border: OutlineInputBorder(),
                ),
              ),
              if (isBuying) ...[
                SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Alım Fiyatı',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                double actionAmount =
                    double.tryParse(actionController.text) ?? 0;

                if (!isBuying && actionAmount > portfolio[index]['quantity']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Geçersiz miktar!')),
                  );
                } else {
                  setState(() {
                    if (isBuying) {
                      double buyPrice =
                          double.tryParse(priceController?.text ?? '0') ?? 0;
                      if (buyPrice <= 0 || actionAmount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Geçersiz miktar veya fiyat!')),
                        );
                        return;
                      }

                      portfolio[index]['cost'] = ((portfolio[index]['cost'] *
                                  portfolio[index]['quantity']) +
                              (buyPrice * actionAmount)) /
                          (portfolio[index]['quantity'] + actionAmount);
                      portfolio[index]['quantity'] += actionAmount;
                    } else {
                      portfolio[index]['quantity'] -= actionAmount;
                      if (portfolio[index]['quantity'] <= 0) {
                        portfolio.removeAt(index);
                      }
                    }
                  });
                  savePortfolioToFile();
                  calculateTotalPortfolioValue();
                  Navigator.of(context).pop();
                }
              },
              child: Text(isBuying ? 'Al' : 'Sat'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    loadPortfolioFromFile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Coin Portföyü'),
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
                        controller: coinController,
                        decoration: InputDecoration(
                          labelText: 'Coin Adı',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Adet',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Maliyet Fiyatı',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
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
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: addCoin,
                  child: Text('Ekle'),
                ),
              ],
            ),
          ),
          isLoading
              ? Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: portfolio.length,
                    itemBuilder: (context, index) {
                      final coin = portfolio[index];
                      final name = coin['name'];
                      final quantity = (coin['quantity'] as num)
                          .toDouble(); // Ensure type safety
                      final cost = coin['cost'];
                      final date = coin['date'];
                      final price =
                          (coinPrices[name]?['usd'] as num?)?.toDouble() ?? 0.0;
                      final currentValue = quantity * price;

                      return Card(
                        margin: EdgeInsets.all(8),
                        child: ListTile(
                          leading: coinLogos[name] != null
                              ? Image.network(
                                  coinLogos[name]!,
                                  width: 40,
                                  height: 40,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.error),
                                )
                              : Icon(Icons.monetization_on),
                          title: Text(
                              '${name.toUpperCase()} - Güncel: \$${price.toStringAsFixed(2)}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Adet: $quantity'),
                              Text('Maliyet: \$${cost.toStringAsFixed(2)}'),
                              Text('Tarih: $date'),
                              Text(
                                  'Toplam Değer: \$${currentValue.toStringAsFixed(2)}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => manageCoin(index, true),
                                child: Text('Al'),
                              ),
                              TextButton(
                                onPressed: () => manageCoin(index, false),
                                child: Text('Sat'),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
