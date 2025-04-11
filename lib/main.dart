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
int now_drive_port = 42309;

Future<bool> checkpassword(String password, String ip) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString(); // 输出 13位
  final timestampStr = timestamp.substring(0, timestamp.length - 2);

  List<int> bytes = utf8.encode(password+timestampStr);
  var hash = md5.convert(bytes);
  var hashString = hash.toString().toUpperCase();

  try {
    final response = await http.get(
      Uri.parse('http://$ip:42309/checkpassword?hash=$hashString'),
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
  catch (e) {
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
      body: IndexedStack(
      index: senceIndex,
      children: const [
        MainPage(),
      ],
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
                //ChatPage(),
                SettingsPage(),
              ],
            ),
            ),
            BottomNavigationBar( //底部导航栏
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.search, color: (pilotIndex == 0 ? Colors.blue : Colors.black)),
                  label: '查找',
                ),
                /*
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat, color: (pilotIndex == 1 ? Colors.blue : Colors.black)),
                  label: '聊天',
                ),
                */
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings,color: (pilotIndex == 2 ? Colors.blue : Colors.black)),
                  label: '设置',
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

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("设置"),
      ),
      body: Center(
        child: Text(
          '设置页面',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  bool hogh_level_mode = false; // 高级模式
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  TextEditingController _messageController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text("聊天"),
      ),
      body: Column(
      children: <Widget>[
        Expanded(
        child: Center(
          child: Text(
          now_drive_name == null ? "未连接设备" : now_drive_name!,
          style: TextStyle(fontSize: 35, color: Colors.black),
          ),
        ),
        ),
        Container(
        padding: EdgeInsets.all(8.0),
        child: Row(
          children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: '输入消息...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(width: 0),
          ElevatedButton(
            onPressed: () {
              setState(() {
                widget.hogh_level_mode = !widget.hogh_level_mode;
              });
            },
            style: ElevatedButton.styleFrom(
              shape: CircleBorder(),
              minimumSize: Size(50, 50),
              backgroundColor: widget.hogh_level_mode ? Colors.blue : null,
            ),
            child: Icon(Icons.offline_bolt),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 处理发送消息
              DriveItem(ip: now_drive_ip ?? "", name: now_drive_name ?? "", on_connect: (){},).sendChatMessage(_messageController.text, now_drive_password ?? "");
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(80, 50),
            ),
            child: Text('发送'),
          ),
          
          ],
        ),
        ),
      ],
      ),
    );
  }
}

int search_y = 0;

class SearchPage extends StatefulWidget {
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final StreamController<List<DriveItem>> driveItemsStream = StreamController<List<DriveItem>>.broadcast();

  bool is_searching = false; // 是否正在搜索

  void enterPassword(DriveItem driveItem) async {
    String ip = driveItem.ip;
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
                  Navigator.of(context).pop();
                  driveItem.connect(password);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('连接成功'),
                        duration: Duration(seconds: 1),
                      ),
                  );
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ChatPage(),
                  ));
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
  for (search_y = 0; search_y <= 260; search_y++) {
    String ip = '192.168.3.$search_y';
    try {
      print('Checking $ip...');
      final response = await http.get(
        Uri.parse('http://$ip:42309'),
        headers: {'User-Agent': 'Kooly'},
      ).timeout(
        const Duration(milliseconds: 130),
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
            search_y = 259;
            enterPassword(DriveItem(ip: ip,name: deviceName, on_connect: (){}));
          },
        ));
        driveItemsStream.add(driveItems);
      }
    } catch (e) {
      continue;
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
              if(!is_searching){SearchDrive();}else{search_y = 0;}
              setState(() {
                is_searching = true; // 设置为正在搜索
              });
            }
          ),
          IconButton(
            onPressed: (){}, icon: Icon(Icons.qr_code_scanner), // 扫描二维码
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

  void connect(String password) {
    // 连接设备 TODO
    now_drive_ip = ip;
    now_drive_name = name;
    now_drive_password = password;
  }

  Future<void> sendChatMessage(String message,String password) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString(); // 输出 13位
    final timestampStr = timestamp.substring(0, timestamp.length - 2);

    List<int> bytes = utf8.encode(password+timestampStr);
    var hash = md5.convert(bytes);
    var hashString = hash.toString().toUpperCase();

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
        onPressed: on_connect,
      ),
      ),
    );
  }
}