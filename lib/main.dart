import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main(){
  runApp(const MyApp());
}

String ?now_drive_ip;
String ?now_drive_name;
String ?now_drive_password;
int ?now_drive_port;

Future<bool> checkpassword(String password, String ip) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString(); // 输出 13位
  final timestampStr = timestamp.substring(0, timestamp.length - 2);
  print("time:"+timestampStr);
  List<int> bytes = utf8.encode(password+timestampStr);
  var hash = md5.convert(bytes);
  var hashString = hash.toString().toUpperCase();
  print(hashString);
  final response = await http.get(
    Uri.parse('http://$ip:42309/checkpassword?hash=${hashString}'),
    headers: {'User-Agent': 'Kooly'},
  ).timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      throw TimeoutException('Request timed out');
    },
  );
  if (response.statusCode == 200) {
    return true; // 密码正确
  }
  else if(response.statusCode == 401){
    return false;// 密码错误
  }
  else {
    return false; 
  }
}


List<DriveItem> driveItems = []; // 设备列表

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

  bool is_searching = false; // 是否正在搜索

  void enterPassword(String ip) {
    // 弹出输入密码的对话框
    showDialog(
      context: context,
      builder: (context) {
        String password = '';
        return AlertDialog(
          title: const Text('输入密码'),
          content: TextField(
            onChanged: (value) {
              password = value;
            },
            obscureText: true,
            decoration: const InputDecoration(hintText: '请输入密码'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // 取消操作
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if(await checkpassword(password, ip)){
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('密码正确'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  Navigator.of(context).pop();
                }
                else{
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('密码错误或连接错误，请重试'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> SearchDrive() async {
  is_searching = true; // 设置为正在搜索
  driveItems.clear(); // 清空设备列表
  for (int x = 1; x <= 10; x++) {
    for (int y = 1; y <= 18; y++) {
      String ip = '192.168.$x.$y';
      try {
        print('Checking $ip...');
        final response = await http.get(
          Uri.parse('http://$ip:42309'),
          headers: {'User-Agent': 'Kooly'},
        ).timeout(
          const Duration(milliseconds: 150),
          onTimeout: () {
            throw TimeoutException('Request timed out');
          },
        );
        
        if (response.statusCode == 200) {
          if (!response.body.contains('Kooly')){
            setState(() {
              is_searching = false; // 设置为搜索完成
            });
            continue;
          }
          print('Found device at $ip');
          var deviceName = response.body.contains('"name":"') 
            ? response.body.split('"name":"')[1].split('"')[0]
            : "Drive";
          driveItems.add(DriveItem(
            ip: ip,
            name: deviceName,
            on_connect: (){
            enterPassword(ip);
            },
          ));
          driveItemsStream.add(driveItems);
        }
      } catch (e) {
        continue;
      }
    }
  }
  setState(() {
    is_searching = false; // 设置为搜索完成
  });
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
              //弹出弹窗要求输入ip地址
              showDialog(
                context: context,
                builder: (context) {
                  String ip = '';
                  return AlertDialog(
                    title: const Text('输入IP地址'),
                    content: TextField(
                      onChanged: (value) {
                        ip = value;
                      },
                      decoration: const InputDecoration(hintText: '请输入IP地址'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          //TODO 取消
                          Navigator.of(context).pop();
                        },
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(ip);
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  );
                },
              ).then((ip) {
                if (ip != null && ip.isNotEmpty) {
                  driveItemsStream.add(driveItems);
                  enterPassword(ip);
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if(!is_searching){SearchDrive();}
            }
          ),
        ],
      ),
      body: StreamBuilder<List<DriveItem>>(
        stream: driveItemsStream.stream,
        initialData: driveItems,
        builder: (context, snapshot) {
          return SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 15),
            ...driveItems,
            if (is_searching) Center(
              child: const SizedBox(
              height: 50,
              width: 50,
              child: CircularProgressIndicator(),
              ),
            ) else if (driveItems.isEmpty) const Center(
              child: const Text('没有在附近找到设备', 
              style: TextStyle(fontSize: 24, color: Colors.grey),
              ),
            ) else const SizedBox.shrink(),
          ],
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
  final VoidCallback on_connect; // 连接设备的回调函数
  //final int port; // 设备端口
  
  const DriveItem({super.key, required this.ip, required this.name, required this.on_connect});

  void connect() {
    // 连接设备 TODO

  }

  Future<void> sendChatMessage(String message,String password) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString(); // 输出 13位
    final timestampStr = timestamp.substring(0, timestamp.length - 2);
    print("time:"+timestampStr);
    List<int> bytes = utf8.encode(password+timestampStr);
    var hash = md5.convert(bytes);
    var hashString = hash.toString().toUpperCase();
    print(hashString);
    final response = await http.get(
      Uri.parse('http://$ip:42309/chat?hash=${hashString}?message=${message}'),
      headers: {'User-Agent': 'Kooly'},
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException('Request timed out');
      },
    );
    if (response.statusCode == 200) {
      
    }
    else if(response.statusCode == 401){
    }
    else {
    }
  }

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
          // 连接设备
          on_connect();
        },
      ),
      ),
    );
  }
}