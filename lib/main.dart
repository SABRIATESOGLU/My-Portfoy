import 'package:flutter/material.dart';
import 'coin_portfolio_page.dart';
import 'stock_portfolio_page.dart';
import 'login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Portföy Takip Uygulaması',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool isLoggedIn = false;

  final List<Widget> _pages = [
    // Giriş sayfasına onLoginSuccess parametresi ekleniyor
    LoginPage(onLoginSuccess: () {}), // Sayfa 1: Kullanıcı Girişi
    CoinPortfolioPage(), // Sayfa 2: Coin Portföyü
    const StockPortfolioPage(), // Sayfa 3: Hisse Portföyü
  ];

  void _onItemTapped(int index) {
    if (index != 0 && !isLoggedIn) {
      // Giriş yapılmadıysa uyarı göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce giriş yapın!')),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void onLoginSuccess() {
    // Giriş başarılı olduğunda çağrılır
    setState(() {
      isLoggedIn = true;
      _selectedIndex = 1; // İlk olarak Coin Portföyü sayfasına yönlendir
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages.map((page) {
          if (page is LoginPage) {
            // onLoginSuccess parametresini geçiyoruz
            return LoginPage(onLoginSuccess: onLoginSuccess);
          }
          return page;
        }).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Kullanıcı Girişi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Coin Portföyü',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Hisse Portföyü',
          ),
        ],
      ),
    );
  }
}
