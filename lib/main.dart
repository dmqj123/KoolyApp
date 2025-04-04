import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

List<DriveItem> driveItems = [DriveItem(ip: "192.168.1.5", name: "win10")]; // 设备列表

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
  final StreamController<List<DriveItem>> driveItemsStream = StreamController<List<DriveItem>>.broadcast();

  Future<void> SearchDrive() async {
  for (int x = 1; x <= 20; x++) {
    for (int y = 1; y <= 20; y++) {
      String ip = '192.168.$x.$y';
      try {
        print('Checking $ip...');
        final response = await http.get(Uri.parse('http://$ip:80')).timeout(
          const Duration(milliseconds: 120),
          onTimeout: () {
            throw TimeoutException('Request timed out');
          },
        );
        
        if (response.statusCode == 200) {
          print('Found device at $ip');
          var deviceInfo = jsonDecode(response.body);
          driveItems.add(DriveItem(
            ip: ip,
            name: deviceInfo['name'] ?? 'Unknown Device',
          ));
          driveItemsStream.add(driveItems);
        }
      } catch (e) {
        continue;
      }
    }
  }
}


  @override
  void initState() {
    super.initState();
    driveItemsStream.add(driveItems);
    SearchDrive();
  }

  @override
  void dispose() {
    driveItemsStream.close();
    super.dispose();
  }

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
              // 添加设备
            },
          ),
        ],
      ),
      body: StreamBuilder<List<DriveItem>>(
        stream: driveItemsStream.stream,
        initialData: driveItems,
        builder: (context, snapshot) {
          return SingleChildScrollView(
        child: Column(
          children: driveItems,
        ),
          );
        }
      ),
    );
  }
}

class DriveItem extends StatelessWidget {
  final String ip;
  final String name; // 设备名称
  
  const DriveItem({super.key, required this.ip, required this.name});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
        color: Colors.grey.withOpacity(0.2),
        spreadRadius: 1,
        blurRadius: 3,
        offset: Offset(0, 2),
        ),
      ],
      ),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
      title: Text(name),
      subtitle: Text(ip),
      trailing: ElevatedButton(
        child: const Text('连接'),
        onPressed: () {
        // Handle connection
        },
      ),
      ),
    );
  }
}