import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kooly',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 0, 139, 209)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Kooly'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int senceIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Expanded(child: 
        IndexedStack(
        index: senceIndex,
        children: const [
          MainPage(),
        ],
      ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int pilotIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(child: 
              IndexedStack(
              index: pilotIndex,
              children: [
                SearchPage(),
              ],
            ),
            ),
            BottomNavigationBar( //底部导航栏
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.search, color: (pilotIndex == 0 ? Colors.blue : Colors.black)),
                  label: '查找',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.home, color: (pilotIndex == 1 ? Colors.blue : Colors.black)),
                  label: '聊天',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person,color: (pilotIndex == 2 ? Colors.blue : Colors.black)),
                  label: '我的',
                ),
              ],
              onTap: (index){
                setState(() {
                  pilotIndex = index;
                });
              }
            )
          ],
        ),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("查找"),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              // 添加
            },
          ),
        ],
      ),
      body: Center(
        child: Row(children: [
          
        ],),
      )
    );
  }
}