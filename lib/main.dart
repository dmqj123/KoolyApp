import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

int Communication_protocol_compatible_version = 1; //通信协议兼容版本

void main(){
  runApp(const MyApp());
}

String ai_answer = "";

List<String> ports = [
  "你是一个叫Kooly的智能助手",
  "你是一个名为Kooly的智能助手,专注于简洁地回答用户问题。需要帮助用户执行任务时,在回答前使用'c[命令]'格式提供需执行的cmd命令,以协助完成任务。每次回答仅含一个'c[命令]',但此命令内可包含多个用&&连接的命令。用户提问直接转化为操作或查询。若命令有返回,系统将开启新对话告知你结果,以便继续指导或操作", //高级模式
  "你是一名简洁回答的智能助手Kooly。需要时在回答开头使用'c[命令]'使用户的电脑执行cmd指令,多个命令用'&&'连接。仅在必要时使用一条开头的命令,不必告知用户具体执行过程。对于单纯提问,直接回答即可", //普通模式
  "你是一个名为Kooly的智能助手,专注于回答用户问题。需要帮助用户执行任务时,在回答前使用'c[命令]'格式提供需执行的cmd命令,以协助完成任务。每次回答仅含一个'c[命令]',但此命令内可包含多个用&&连接的命令。用户提问直接转化为操作或查询。若命令有返回,系统将开启新对话告知你结果,以便继续指导或操作\n" //有命令返回
];

String ?now_drive_ip;
String ?now_drive_name;
String ?now_drive_password;
int now_drive_port = 42309;

AiApiInfo aiApiInfo = AiApiInfo();

class AiApiInfo {
  String model_name = "deepseek-chat";
  String ?api_key;
  String ?api_url;
}

String vcn_number_time = DateTime.now().millisecondsSinceEpoch.toString().substring(0, DateTime.now().millisecondsSinceEpoch.toString().length - 4);
int vcn_uses = 0; //校验码使用情况

Future<bool> checkpassword(String password, String ip) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString(); // 输出 13位
  final timestampStr = timestamp.substring(0, timestamp.length - 4);

  if(timestampStr != vcn_number_time){
    vcn_uses = 0;
    vcn_number_time = DateTime.now().millisecondsSinceEpoch.toString().substring(0, DateTime.now().millisecondsSinceEpoch.toString().length - 4);
  }
  else{
    vcn_uses += 1;
  }

  String hashString = md5.convert(utf8.encode(password+timestampStr)).toString().toUpperCase();

  String vc_number ="00";

  //匹配vcn_uses
  switch (vcn_uses){
    case 0:
      vc_number = "00";
      break;
    case 1:
      vc_number = "01";
      break;
    case 2:
      vc_number = "02";
      break;
    case 3:
      vc_number = "03";
      break;
    case 4:
      vc_number = "04";
      break;
    case 5:
      vc_number = "05";
      break;
    case 6:
      vc_number = "06";
      break;
    default:
      vc_number = "0000";
      break;
  }

  String verification_code = md5.convert(utf8.encode(password+timestampStr+vc_number)).toString().toUpperCase();

  try {
    final response = await http.get(
      Uri.parse('http://$ip:42309/checkpassword?hash=$hashString&verification-code=$verification_code'),
      headers: {'User-Agent': 'Kooly'},
    ).timeout(
      const Duration(seconds: 6),
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
  MaterialColor _selectedColor = Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("设置"),
      ),
      body: Column(
        children: [
          SizedBox(height: 15),
          Row(
            children: [
              Text("主题色：",style: TextStyle(fontSize: 35),),
              DropdownButton<MaterialColor>(
                borderRadius: BorderRadius.circular(10),
                value: _selectedColor,
                onChanged: (color) => setState(() => _selectedColor = color!),
                items: [
                  DropdownMenuItem(
                    value: Colors.blue,
                    child: Row(children: [
                      Container(width: 20, height: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('蓝色'),
                    ]),
                  ),
                  DropdownMenuItem(
                    value: Colors.pink,
                    child: Row(children: [
                      Container(width: 20, height: 20, color: Colors.pink),
                      const SizedBox(width: 8),
                      const Text('粉色'),
                    ]),
                  ),
                ],
              )
            ],
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Text("端口：",style: TextStyle(fontSize: 35),),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 20), // 设置右边距为10
                child: TextField(
                  controller: TextEditingController(),
                  decoration: InputDecoration(
                    hintText: '请输入端口',
                    border: OutlineInputBorder(),
                    filled: true, // 启用填充
                    fillColor: Colors.grey[200], // 设置填充颜色
                  ),
                ),
              ),)
            ],
          ),
        ],
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
  bool is_asking = false;
  Future<void> ask(String _question,String _p) async {
    send_message(
      aiApiInfo.api_url!,
      aiApiInfo.api_key!,
      _question,
      _p
    );
  }
  Future<String> run_command(String command) async {

    // 替换ai_answer
    ai_answer.replaceAll(command, "正在执行命令："+command);
    setState(() {});
          
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString(); // 输出 13位
    final timestampStr = timestamp.substring(0, timestamp.length - 4);

    if(timestampStr != vcn_number_time){
      vcn_uses = 0;
      vcn_number_time = DateTime.now().millisecondsSinceEpoch.toString().substring(0, DateTime.now().millisecondsSinceEpoch.toString().length - 4);
    }
    else{
      vcn_uses += 1;
    }

    String hashString = md5.convert(utf8.encode(now_drive_password!+timestampStr)).toString().toUpperCase();

    String vc_number ="00";

    //匹配vcn_uses
    switch (vcn_uses){
      case 0:
        vc_number = "00";
        break;
      case 1:
        vc_number = "01";
        break;
      case 2:
        vc_number = "02";
        break;
      case 3:
        vc_number = "03";
        break;
      case 4:
        vc_number = "04";
        break;
      case 5:
        vc_number = "05";
        break;
      case 6:
        vc_number = "06";
        break;
      default:
        vc_number = "0000";
        break;
    }

    String verification_code = md5.convert(utf8.encode(now_drive_password!+timestampStr+vc_number)).toString().toUpperCase();
    final response = await http.get(
      Uri.parse('http://$now_drive_ip:42309/run_cmd?hash=${hashString}&verification-code=$verification_code&command=$command'),
      headers: {'User-Agent': 'Kooly'},
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Request timed out');
      },
    );
    String result = "";
    if (response.statusCode == 200) {
      //获取请求体里面的字段
      // 声明响应体变量
      var responseBody;
      // 清理响应内容中的换行符、回车符和制表符
      String cleanedBody = response.body.replaceAll(RegExp(r'[\n\r\t]'), '');
      try {
        // 尝试解析清理后的JSON字符串
        responseBody = json.decode(cleanedBody);
      } catch (e) {
        // 如果解析失败,打印错误信息并返回错误提示
        print('JSON解析错误: $e');
        return '解析响应失败';
      }
      if(responseBody['success']=="true"){
        result = responseBody['result'];
      }
      else{
        result = responseBody["执行错误:"+'message'];
      }
    }
    else if(response.statusCode == 401){
    }
    else {
    }
    return result;
  }
  Future<void> send_message(String url,String key,String question,String port) async {
    is_asking = true;
    final client = http.Client();
    try {
      final requestBody = {
        "model": aiApiInfo.model_name,
        "messages": [
          {"role": "user", "content": question},
          {"role": "system", "content": port}
        ],
        "stream": true, // 启用流式传输
        "max_tokens": 600,
        "temperature": 1.3,
      };
  
      final request = http.Request('POST', Uri.parse(url))
        ..headers.addAll({
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode(requestBody);
  
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('请求失败: ${response.statusCode}');
      }
  
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
  
      await for (final line in stream) {
        if (line.isEmpty) continue;
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          
          try {
            final jsonResponse = jsonDecode(data);
            final content = jsonResponse['choices'][0]['delta']['content'];
            if (content != null) {
              if(!is_asking){
                return;
              }
              ai_answer += content;
              setState(() {
                
              });
            }
          } catch (e) {
            print('解析错误: $e');
          }
        }
      }
    } finally {
      client.close();
      is_asking = false;
      String comm="";
      //如果ai_answer以"c["开头，且有"]"
      if(ai_answer.startsWith("c[")){
        if(ai_answer.contains("]")){
          //将c[]中间的内容赋值
          comm = ai_answer.substring(2,ai_answer.indexOf("]"));

          String result = await run_command(comm);

          if(!result.isEmpty){
            ask("请继续",ports[3]+"用户上次的提问："+question+"\n"+"你上次的回答："+ai_answer+"\n"+"指令执行结果："+result);
          }
          else{
            // 替换ai_answer
            ai_answer.replaceAll(comm, "命令执行完毕："+comm);
            setState(() {});
          }
        }
      }
      setState(() {
        
      });
    }
}
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
        Card(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              //maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.5 // 添加最大高度约束
            ),
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              child: RichText(
                text: TextSpan(
                  text: "Kooly: " + (ai_answer ?? "..."),  // 拼接固定前缀与动态回答内容
                  style: const TextStyle(
                    fontSize: 35,      // 设置字体大小
                    color: Colors.black, // 设置文本颜色
                  ),
                ),
              ),
            )
          )
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
              if(is_asking){
                setState(() {
                  is_asking = false;
                });
                return;
              }
              if ((aiApiInfo.api_url?.isNotEmpty ?? false) && 
                  (aiApiInfo.api_key?.isNotEmpty ?? false)) {
                ai_answer = "";
                is_asking = true;
                ask(_messageController.text, ports[2]);
                setState(() {
                  //_messageController.text = ""; // 清空输入框
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请先完成设备连接配置'),
                    duration: Duration(seconds: 1), // 添加持续时间参数
                  )
                );

              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(80, 50),
            ),
            child: Text(is_asking ? "停止" : "发送"),
          )
          ],
        ),
        ),
      ],
      ),
    );
  }
}

int search_y = 0;
int search_x = 0;

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
                if(await driveItem.connect(password)==200){
                  Navigator.of(context).pop();
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

  Future<void> SearchDevice() async {
  is_searching = true; // 设置为正在搜索
  driveItems.clear(); // 清空设备列表
  for (search_x = 1; search_x <= 5; search_x++) {
    for (search_y = 1; search_y <= 256; search_y++) {
      if(search_y==21){
        if(search_x!=3){
          break;
        }
      }
      String ip = '192.168.$search_x.$search_y';
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
              enterPassword(DriveItem(ip: ip,name: deviceName, on_connect: (){}));
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
    SearchDevice();
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
                  //driveItemsStream.add(driveItems);
                  enterPassword(DriveItem(ip: ip, name: "未知设备", on_connect: (){}));
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if(!is_searching){SearchDevice();}else{search_y = 0;search_x = 0;} // 刷新设备列表
              setState(() {
                is_searching = true; // 设置为正在搜索
              });
            }
          ),
          IconButton(
            onPressed: (){
              // 扫描二维码
            }, icon: Icon(Icons.qr_code_scanner), // 扫描二维码
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
            if (is_searching) const Center(
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

  Future<int> connect(String password) async {
    now_drive_ip = ip;
    now_drive_name = name;
    now_drive_password = password;

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString(); // 输出 13位
    final timestampStr = timestamp.substring(0, timestamp.length - 4);

    if(timestampStr != vcn_number_time){
      vcn_uses = 0;
      vcn_number_time = DateTime.now().millisecondsSinceEpoch.toString().substring(0, DateTime.now().millisecondsSinceEpoch.toString().length - 4);
    }
    else{
      vcn_uses += 1;
    }

    String hashString = md5.convert(utf8.encode(password+timestampStr)).toString().toUpperCase();

    String vc_number ="00";

    //匹配vcn_uses
    switch (vcn_uses){
      case 0:
        vc_number = "00";
        break;
      case 1:
        vc_number = "01";
        break;
      case 2:
        vc_number = "02";
        break;
      case 3:
        vc_number = "03";
        break;
      case 4:
        vc_number = "04";
        break;
      case 5:
        vc_number = "05";
        break;
      case 6:
        vc_number = "06";
        break;
      default:
        vc_number = "0000";
        break;
    }

  String verification_code = md5.convert(utf8.encode(password+timestampStr+vc_number)).toString().toUpperCase();
    final response = await http.get(
      Uri.parse('http://$ip:42309/get_apiinfo?hash=${hashString}&verification-code=$verification_code'),
      headers: {'User-Agent': 'Kooly'},
    ).timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        throw TimeoutException('Request timed out');
      },
    );
    if (response.statusCode == 200) {
      //获取请求体里面的url和key字段
      var responseBody = json.decode(response.body);
      aiApiInfo.api_key = responseBody['key'];
      aiApiInfo.api_url = responseBody['url'];
    }
    else if(response.statusCode == 401){
    }
    else {
    }
    return response.statusCode;
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