import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ==================== 常量 ====================

int Communication_protocol_compatible_version = 1;

List<String> ports = [
  "你是一个叫Kooly的智能助手",
  "你是一个名为Kooly的智能助手,专注于回答用户问题。需要帮助用户执行任务时,在回答前使用'c[命令]'格式提供需执行的cmd命令,以协助完成任务。每次回答仅含一个'c[命令]',但此命令内可包含多个用&&连接的命令。用户提问直接转化为操作或查询。若命令有返回,系统将开启新对话告知你结果,以便继续指导或操作。获得返回后可以将信息继续用于回答，但是只需回答用户问题，不用使用echo等命令将回答显示出来，因为用户看不了你执行的命令结果",
  "你是一名简洁回答的智能助手Kooly。需要时在回答开头使用'c[命令]'使用户的电脑执行cmd指令,多个命令用'&&'连接。仅在必要时使用一条开头的命令,不必告知用户具体执行过程。对于单纯提问,直接回答即可",
  "你是一个名为Kooly的智能助手,专注于回答用户问题。需要帮助用户执行任务时,在回答前使用'c[命令]'格式提供需执行的cmd命令,以协助完成任务。每次回答仅含一个'c[命令]',但此命令内可包含多个用&&连接的命令。用户提问直接转化为操作或查询。若命令有返回,系统将开启新对话告知你结果,以便继续指导或操作。获得返回后可以将信息继续用于回答，但是只需回答用户问题，不用使用echo等命令将回答显示出来，因为用户看不了你执行的命令结果\n"
];

// ==================== 数据模型 ====================

class CommandExecution {
  final String command;
  String? result;
  bool isCompleted;
  bool isRunning;

  CommandExecution({
    required this.command,
    this.result,
    this.isCompleted = false,
    this.isRunning = false,
  });

  Map<String, dynamic> toJson() => {
    'command': command,
    'result': result,
    'isCompleted': isCompleted,
  };

  factory CommandExecution.fromJson(Map<String, dynamic> json) => CommandExecution(
    command: json['command'],
    result: json['result'],
    isCompleted: json['isCompleted'] ?? false,
  );
}

class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  String content;
  List<CommandExecution> commands;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    List<CommandExecution>? commands,
    DateTime? timestamp,
  }) : commands = commands ?? [],
       timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'commands': commands.map((c) => c.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    role: json['role'],
    content: json['content'],
    commands: (json['commands'] as List?)?.map((c) => CommandExecution.fromJson(c)).toList() ?? [],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class Conversation {
  String id;
  String title;
  List<ChatMessage> messages;
  DateTime createdAt;
  DateTime updatedAt;

  Conversation({
    required this.id,
    this.title = '新对话',
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : messages = messages ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'],
    title: json['title'] ?? '新对话',
    messages: (json['messages'] as List?)?.map((m) => ChatMessage.fromJson(m)).toList() ?? [],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
  );
}

class SavedDevice {
  String ip;
  String name;
  String password;
  bool isFavorite;
  DateTime lastConnected;

  SavedDevice({
    required this.ip,
    required this.name,
    required this.password,
    this.isFavorite = false,
    DateTime? lastConnected,
  }) : lastConnected = lastConnected ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'name': name,
    'password': password,
    'isFavorite': isFavorite,
    'lastConnected': lastConnected.toIso8601String(),
  };

  factory SavedDevice.fromJson(Map<String, dynamic> json) => SavedDevice(
    ip: json['ip'],
    name: json['name'],
    password: json['password'],
    isFavorite: json['isFavorite'] ?? false,
    lastConnected: json['lastConnected'] != null ? DateTime.parse(json['lastConnected']) : DateTime.now(),
  );
}

class AiApiInfo {
  String model_name = "deepseek-chat";
  String? api_key;
  String? api_url;
  bool use_custom_api = false;
  String? custom_api_key;
  String? custom_api_url;
  String? custom_model_name;

  String get effective_api_key => use_custom_api ? (custom_api_key ?? '') : (api_key ?? '');
  String get effective_api_url => use_custom_api ? (custom_api_url ?? '') : (api_url ?? '');
  String get effective_model_name => use_custom_api ? (custom_model_name ?? 'deepseek-chat') : model_name;
  bool get is_configured => effective_api_key.isNotEmpty && effective_api_url.isNotEmpty;
}

// ==================== 全局状态 ====================

String? now_drive_ip;
String? now_drive_name;
String? now_drive_password;
int now_drive_port = 42309;
AiApiInfo aiApiInfo = AiApiInfo();

List<Conversation> conversations = [];
Conversation? activeConversation;

List<SavedDevice> savedDevices = [];

String vcn_number_time = DateTime.now().millisecondsSinceEpoch.toString().substring(0, DateTime.now().millisecondsSinceEpoch.toString().length - 4);
int vcn_uses = 0;

// ==================== 工具函数 ====================

Map<String, String> generateAuthParams(String password) {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final timestampStr = timestamp.substring(0, timestamp.length - 4);

  if (timestampStr != vcn_number_time) {
    vcn_uses = 0;
    vcn_number_time = timestampStr;
  } else {
    vcn_uses += 1;
  }

  String hashString = md5.convert(utf8.encode(password + timestampStr)).toString().toUpperCase();

  String vc_number;
  switch (vcn_uses) {
    case 0: vc_number = "00"; break;
    case 1: vc_number = "01"; break;
    case 2: vc_number = "02"; break;
    case 3: vc_number = "03"; break;
    case 4: vc_number = "04"; break;
    case 5: vc_number = "05"; break;
    case 6: vc_number = "06"; break;
    default: vc_number = "0000"; break;
  }

  String verification_code = md5.convert(utf8.encode(password + timestampStr + vc_number)).toString().toUpperCase();

  return {'hash': hashString, 'verification-code': verification_code};
}

Future<bool> checkpassword(String password, String ip) async {
  final params = generateAuthParams(password);
  try {
    final response = await http.get(
      Uri.parse('http://$ip:$now_drive_port/checkpassword?hash=${params['hash']}&verification-code=${params['verification-code']}'),
      headers: {'User-Agent': 'Kooly'},
    ).timeout(const Duration(seconds: 6), onTimeout: () {
      throw TimeoutException('Request timed out');
    });
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

Future<int> connectToDevice(String ip, String name, String password) async {
  now_drive_ip = ip;
  now_drive_name = name;
  now_drive_password = password;

  final params = generateAuthParams(password);
  try {
    final response = await http.get(
      Uri.parse('http://$ip:$now_drive_port/get_apiinfo?hash=${params['hash']}&verification-code=${params['verification-code']}'),
      headers: {'User-Agent': 'Kooly'},
    ).timeout(const Duration(seconds: 6), onTimeout: () {
      throw TimeoutException('Request timed out');
    });
    if (response.statusCode == 200) {
      var responseBody = json.decode(response.body);
      aiApiInfo.api_key = responseBody['key'];
      aiApiInfo.api_url = responseBody['url'];

      _saveDeviceToMemory(ip, name, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_connected_ip', ip);
    }
    return response.statusCode;
  } catch (e) {
    return 500;
  }
}

void _saveDeviceToMemory(String ip, String name, String password) {
  final existingIndex = savedDevices.indexWhere((d) => d.ip == ip);
  if (existingIndex >= 0) {
    savedDevices[existingIndex].name = name;
    savedDevices[existingIndex].password = password;
    savedDevices[existingIndex].lastConnected = DateTime.now();
  } else {
    savedDevices.add(SavedDevice(ip: ip, name: name, password: password));
  }
  saveSavedDevices();
}

Future<String> runCommand(String command) async {
  final params = generateAuthParams(now_drive_password!);
  try {
    final response = await http.get(
      Uri.parse('http://$now_drive_ip:$now_drive_port/run_cmd?hash=${params['hash']}&verification-code=${params['verification-code']}&command=$command'),
      headers: {'User-Agent': 'Kooly'},
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      throw TimeoutException('Request timed out');
    });
    if (response.statusCode == 200) {
      Map<String, dynamic> responseBody;
      String cleanedBody = response.body.replaceAll(RegExp(r'[\n\r\t]'), '');
      try {
        responseBody = json.decode(cleanedBody);
      } catch (e) {
        return '解析响应失败';
      }
      if (responseBody['success'] == "true") {
        return responseBody['result'] ?? '';
      } else {
        return responseBody['message'] ?? '执行错误';
      }
    }
    return '';
  } catch (e) {
    return '命令执行失败: $e';
  }
}

// ==================== 持久化 ====================

Future<void> saveSavedDevices() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = savedDevices.map((d) => d.toJson()).toList();
  await prefs.setString('saved_devices', jsonEncode(jsonList));
}

Future<void> loadSavedDevices() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('saved_devices');
  if (jsonString != null) {
    final jsonList = jsonDecode(jsonString) as List;
    savedDevices = jsonList.map((j) => SavedDevice.fromJson(j)).toList();
  }
}

Future<void> saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('port', now_drive_port);
  await prefs.setBool('use_custom_api', aiApiInfo.use_custom_api);
  if (aiApiInfo.custom_api_key != null) await prefs.setString('custom_api_key', aiApiInfo.custom_api_key!);
  if (aiApiInfo.custom_api_url != null) await prefs.setString('custom_api_url', aiApiInfo.custom_api_url!);
  if (aiApiInfo.custom_model_name != null) await prefs.setString('custom_model_name', aiApiInfo.custom_model_name!);
  await prefs.setString('model_name', aiApiInfo.model_name);
}

Future<void> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  now_drive_port = prefs.getInt('port') ?? 42309;
  aiApiInfo.use_custom_api = prefs.getBool('use_custom_api') ?? false;
  aiApiInfo.custom_api_key = prefs.getString('custom_api_key');
  aiApiInfo.custom_api_url = prefs.getString('custom_api_url');
  aiApiInfo.custom_model_name = prefs.getString('custom_model_name');
  aiApiInfo.model_name = prefs.getString('model_name') ?? 'deepseek-chat';
}

Future<void> saveConversations() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = conversations.map((c) => c.toJson()).toList();
  await prefs.setString('conversations', jsonEncode(jsonList));
  if (activeConversation != null) {
    await prefs.setString('active_conversation_id', activeConversation!.id);
  }
}

Future<void> loadConversations() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('conversations');
  if (jsonString != null) {
    final jsonList = jsonDecode(jsonString) as List;
    conversations = jsonList.map((c) => Conversation.fromJson(c)).toList();

    final activeId = prefs.getString('active_conversation_id');
    if (activeId != null) {
      final found = conversations.where((c) => c.id == activeId).toList();
      if (found.isNotEmpty) {
        activeConversation = found.first;
      } else if (conversations.isNotEmpty) {
        activeConversation = conversations.last;
      }
    } else if (conversations.isNotEmpty) {
      activeConversation = conversations.last;
    }
  }
}

// ==================== App入口 ====================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedDevices();
  await loadSettings();
  await loadConversations();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kooly',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 0, 139, 209)),
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
  int _tabIndex = 1; // 默认聊天页

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoConnect();
    });
  }

  Future<void> _tryAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final lastIp = prefs.getString('last_connected_ip');
    if (lastIp == null) return;

    final found = savedDevices.where((d) => d.ip == lastIp).toList();
    if (found.isEmpty) return;

    try {
      final statusCode = await connectToDevice(found.first.ip, found.first.name, found.first.password);
      if (statusCode == 200) {
        setState(() {});
      }
    } catch (e) {
      // 静默失败
    }
  }

  void _changeTab(int index) {
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                SearchPage(onSwitchTab: _changeTab),
                ChatPage(onNavigateToSearch: () => _changeTab(0)),
                const SettingsPage(),
              ],
            ),
          ),
          BottomNavigationBar(
            currentIndex: _tabIndex,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.search), label: '查找'),
              BottomNavigationBarItem(icon: Icon(Icons.chat), label: '聊天'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
            ],
            onTap: _changeTab,
          ),
        ],
      ),
    );
  }
}

// ==================== 查找设备页面 ====================

class SearchPage extends StatefulWidget {
  final void Function(int) onSwitchTab;
  const SearchPage({super.key, required this.onSwitchTab});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<DriveItem> discoveredDevices = [];
  bool is_searching = false;
  bool _abortSearch = false;

  void enterPassword(String ip, String name) {
    showDialog(
      context: context,
      builder: (context) {
        String password = '';
        return AlertDialog(
          title: const Text('输入密码'),
          content: TextField(
            onChanged: (value) => password = value,
            obscureText: true,
            decoration: const InputDecoration(hintText: '请输入密码'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final statusCode = await connectToDevice(ip, name, password);
                if (statusCode == 200) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('连接成功'), duration: Duration(seconds: 1)),
                    );
                    widget.onSwitchTab(1);
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('密码错误或连接错误，请重试'), duration: Duration(seconds: 1)),
                    );
                  }
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _connectSavedDevice(SavedDevice device) async {
    final statusCode = await connectToDevice(device.ip, device.name, device.password);
    if (statusCode == 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功'), duration: Duration(seconds: 1)),
        );
        widget.onSwitchTab(1);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接失败，请检查设备是否在线'), duration: Duration(seconds: 1)),
        );
      }
    }
    setState(() {});
  }

  Future<void> searchDevice() async {
    _abortSearch = false;
    setState(() {
      is_searching = true;
      discoveredDevices.clear();
    });

    for (int x = 1; x <= 5 && !_abortSearch; x++) {
      for (int y = 1; y <= 256 && !_abortSearch; y++) {
        if (y == 21 && x != 3) break;
        String ip = '192.168.$x.$y';
        try {
          final response = await http.get(
            Uri.parse('http://$ip:$now_drive_port'),
            headers: {'User-Agent': 'Kooly'},
          ).timeout(const Duration(milliseconds: 150));
          if (response.statusCode == 200 && response.body.contains('Kooly')) {
            var deviceName = response.body.contains('"name":"')
                ? response.body.split('"name":"')[1].split('"')[0]
                : "Drive";
            setState(() {
              discoveredDevices.add(DriveItem(
                ip: ip,
                name: deviceName,
                on_connect: () => enterPassword(ip, deviceName),
              ));
            });
          }
        } catch (e) {
          continue;
        }
      }
    }

    setState(() => is_searching = false);
  }

  @override
  void initState() {
    super.initState();
    searchDevice();
  }

  void _addByIp() {
    showDialog(
      context: context,
      builder: (context) {
        String ip = '';
        return AlertDialog(
          title: const Text('输入IP地址'),
          content: TextField(
            onChanged: (value) => ip = value,
            decoration: const InputDecoration(hintText: '请输入IP地址'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
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
        enterPassword(ip, "未知设备");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoriteDevices = savedDevices.where((d) => d.isFavorite).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("查找"),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addByIp),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (!is_searching) {
                searchDevice();
              } else {
                _abortSearch = true;
                setState(() => is_searching = false);
              }
            },
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 已保存设备 / 收藏
            if (savedDevices.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('已保存设备', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ...savedDevices.map((device) => _buildSavedDeviceTile(device)),
              if (favoriteDevices.isNotEmpty && favoriteDevices.length < savedDevices.length)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text('收藏', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ),
              if (favoriteDevices.isNotEmpty && favoriteDevices.length < savedDevices.length)
                ...favoriteDevices.map((device) => _buildSavedDeviceTile(device)),
              const Divider(indent: 16, endIndent: 16),
            ],

            // 附近设备
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('附近设备', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...discoveredDevices,
            if (is_searching)
              const Center(
                child: SizedBox(
                  height: 50,
                  width: 50,
                  child: CircularProgressIndicator(),
                ),
              )
            else if (discoveredDevices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('没有在附近找到设备', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedDeviceTile(SavedDevice device) {
    final isConnected = now_drive_ip == device.ip;
    return Container(
      decoration: BoxDecoration(
        color: isConnected ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.2), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2)),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            device.isFavorite ? Icons.star : Icons.star_border,
            color: device.isFavorite ? Colors.amber : Colors.grey,
          ),
          onPressed: () {
            setState(() {
              device.isFavorite = !device.isFavorite;
            });
            saveSavedDevices();
          },
        ),
        title: Row(
          children: [
            Text(device.name),
            if (isConnected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.link, size: 16, color: Colors.blue),
            ],
          ],
        ),
        subtitle: Text(device.ip),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _connectSavedDevice(device),
              child: Text(isConnected ? '已连接' : '连接'),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () {
                setState(() {
                  savedDevices.remove(device);
                });
                saveSavedDevices();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 聊天页面 ====================

class ChatPage extends StatefulWidget {
  final VoidCallback onNavigateToSearch;
  const ChatPage({super.key, required this.onNavigateToSearch});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isAsking = false;
  bool _highLevelMode = false;
  ChatMessage? _currentAssistantMsg;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _newConversation() {
    final conv = Conversation(id: DateTime.now().millisecondsSinceEpoch.toString());
    conversations.add(conv);
    activeConversation = conv;
    setState(() {});
    saveConversations();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isAsking) return;

    if (!aiApiInfo.is_configured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完成设备连接或API配置'), duration: Duration(seconds: 1)),
      );
      return;
    }

    if (activeConversation == null) {
      _newConversation();
    }

    // 添加用户消息
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
    );
    activeConversation!.messages.add(userMsg);

    // 自动设置对话标题
    if (activeConversation!.messages.where((m) => m.role == 'user').length == 1) {
      activeConversation!.title = text.length > 20 ? '${text.substring(0, 20)}...' : text;
    }

    _inputController.clear();

    // 创建助手消息占位
    _currentAssistantMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
    );
    activeConversation!.messages.add(_currentAssistantMsg!);
    activeConversation!.updatedAt = DateTime.now();

    setState(() {});
    _scrollToBottom();

    _streamResponse(_currentAssistantMsg!);
  }

  void _stopAsking() {
    _isAsking = false;
    setState(() {});
  }

  List<Map<String, dynamic>> _buildApiMessages() {
    String prompt = _highLevelMode ? ports[1] : ports[2];
    List<Map<String, dynamic>> apiMessages = [
      {'role': 'system', 'content': prompt},
    ];

    final msgs = activeConversation!.messages;
    // 限制最近30条消息，避免超出token限制
    final start = msgs.length > 30 ? msgs.length - 30 : 0;

    for (int i = start; i < msgs.length; i++) {
      final msg = msgs[i];
      // 跳过空消息（当前正在流式生成的占位）
      if (msg.content.isEmpty && msg.commands.isEmpty) continue;

      apiMessages.add({'role': msg.role, 'content': msg.content});

      // 在助手消息后，若有命令执行结果，注入虚拟用户消息
      if (msg.role == 'assistant') {
        for (var cmd in msg.commands) {
          if (cmd.result != null && cmd.result!.isNotEmpty) {
            apiMessages.add({'role': 'user', 'content': '指令执行结果：\n${cmd.result}'});
          }
        }
      }
    }

    return apiMessages;
  }

  Future<void> _streamResponse(ChatMessage assistantMsg) async {
    _isAsking = true;
    _currentAssistantMsg = assistantMsg;
    setState(() {});

    final apiMessages = _buildApiMessages();

    final client = http.Client();
    try {
      final requestBody = {
        "model": aiApiInfo.effective_model_name,
        "messages": apiMessages,
        "stream": true,
        "max_tokens": 600,
        "temperature": 1.3,
      };

      final request = http.Request('POST', Uri.parse(aiApiInfo.effective_api_url))
        ..headers.addAll({
          'Authorization': 'Bearer ${aiApiInfo.effective_api_key}',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode(requestBody);

      final response = await client.send(request);

      if (response.statusCode != 200) {
        assistantMsg.content = '请求失败: ${response.statusCode}';
        _isAsking = false;
        setState(() {});
        return;
      }

      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in stream) {
        if (!_isAsking) return;
        if (line.isEmpty) continue;
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          try {
            final jsonResponse = jsonDecode(data);
            final content = jsonResponse['choices'][0]['delta']['content'];
            if (content != null) {
              assistantMsg.content += content;
              setState(() {});
              _scrollToBottom();
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
    } catch (e) {
      if (assistantMsg.content.isEmpty) {
        assistantMsg.content = '连接错误: $e';
      }
    } finally {
      client.close();
      _isAsking = false;
      setState(() {});
    }

    // 检查是否包含命令
    await _checkForCommand(assistantMsg);

    activeConversation!.updatedAt = DateTime.now();
    saveConversations();
  }

  Future<void> _checkForCommand(ChatMessage assistantMsg) async {
    final match = RegExp(r'c\[([^\]]+)\]').firstMatch(assistantMsg.content);
    if (match == null) return;

    String command = match.group(1)!;

    // 添加命令执行记录
    final cmdExec = CommandExecution(command: command, isRunning: true);
    assistantMsg.commands.add(cmdExec);
    setState(() {});

    // 执行命令
    String result = await runCommand(command);

    cmdExec.isRunning = false;
    cmdExec.isCompleted = true;
    cmdExec.result = result;
    setState(() {});

    // 如果有结果，继续对话
    if (result.isNotEmpty) {
      final continuationMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
      );
      activeConversation!.messages.add(continuationMsg);
      setState(() {});
      _scrollToBottom();

      await _streamResponse(continuationMsg);
    }
  }

  List<Widget> _buildMessageContent(ChatMessage message) {
    List<Widget> widgets = [];
    String content = message.content;

    // 将 c[...] 替换为 CommandCard，其余为文本
    final regex = RegExp(r'c\[[^\]]*\]');
    int lastEnd = 0;
    int cmdIndex = 0;

    for (var match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        String text = content.substring(lastEnd, match.start);
        if (text.trim().isNotEmpty) {
          widgets.add(SelectableText(text.trim(), style: const TextStyle(fontSize: 16)));
        }
      }
      if (cmdIndex < message.commands.length) {
        widgets.add(CommandCard(command: message.commands[cmdIndex]));
        cmdIndex++;
      }
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      String text = content.substring(lastEnd);
      if (text.trim().isNotEmpty) {
        widgets.add(SelectableText(text.trim(), style: const TextStyle(fontSize: 16)));
      }
    }

    // 未在文本中匹配到的命令卡片
    while (cmdIndex < message.commands.length) {
      widgets.add(CommandCard(command: message.commands[cmdIndex]));
      cmdIndex++;
    }

    if (widgets.isEmpty) {
      widgets.add(const Text('...', style: TextStyle(color: Colors.grey)));
    }

    return widgets;
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (message.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: SelectableText(
            message.content,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      );
    } else {
      // 助手消息
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildMessageContent(message),
          ),
        ),
      );
    }
  }

  Widget _buildConversationDrawer() {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('对话列表'),
            automaticallyImplyLeading: false,
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('新建对话'),
            onTap: () {
              _newConversation();
              Navigator.pop(context);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: conversations.isEmpty
                ? const Center(child: Text('暂无对话', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conv = conversations[conversations.length - 1 - index];
                      final isActive = activeConversation?.id == conv.id;
                      final lastMsg = conv.messages.isNotEmpty ? conv.messages.last : null;
                      return ListTile(
                        selected: isActive,
                        selectedTileColor: Colors.blue[50],
                        title: Text(
                          conv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
                        ),
                        subtitle: Text(
                          lastMsg != null && lastMsg.content.isNotEmpty
                              ? lastMsg.content.replaceAll(RegExp(r'c\[[^\]]*\]'), '').trim().substring(0, lastMsg.content.replaceAll(RegExp(r'c\[[^\]]*\]'), '').trim().length > 30 ? 30 : null)
                              : '空对话',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () {
                            setState(() {
                              conversations.remove(conv);
                              if (activeConversation?.id == conv.id) {
                                activeConversation = conversations.isNotEmpty ? conversations.last : null;
                              }
                            });
                            saveConversations();
                          },
                        ),
                        onTap: () {
                          setState(() => activeConversation = conv);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = now_drive_ip != null;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(activeConversation?.title ?? '聊天'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _newConversation,
          ),
        ],
      ),
      drawer: _buildConversationDrawer(),
      body: Column(
        children: [
          // 连接状态栏
          if (!isConnected && !aiApiInfo.use_custom_api)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.orange[100],
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('未连接设备', style: TextStyle(fontSize: 14))),
                  TextButton(
                    onPressed: widget.onNavigateToSearch,
                    child: const Text('去连接'),
                  ),
                ],
              ),
            ),
          if (aiApiInfo.use_custom_api)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.blue[50],
              child: const Row(
                children: [
                  Icon(Icons.cloud, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('使用自定义API', style: TextStyle(fontSize: 13, color: Colors.blue))),
                ],
              ),
            ),

          // 消息列表
          Expanded(
            child: activeConversation == null || activeConversation!.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('开始新对话', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _newConversation,
                          icon: const Icon(Icons.add),
                          label: const Text('新建对话'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: activeConversation!.messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(activeConversation!.messages[index]);
                    },
                  ),
          ),

          // 输入区域
          if (activeConversation != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withValues(alpha: 0.2), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, -1)),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: '输入消息...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _highLevelMode = !_highLevelMode;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        minimumSize: const Size(44, 44),
                        backgroundColor: _highLevelMode ? Colors.blue : null,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.offline_bolt, size: 20),
                    ),
                    ElevatedButton(
                      onPressed: _isAsking ? _stopAsking : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(64, 44),
                      ),
                      child: Text(_isAsking ? '停止' : '发送'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== 设置页面 ====================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  MaterialColor _selectedColor = Colors.blue;
  final _portController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _customModelController = TextEditingController();
  final _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _portController.text = now_drive_port.toString();
    _apiUrlController.text = aiApiInfo.custom_api_url ?? '';
    _apiKeyController.text = aiApiInfo.custom_api_key ?? '';
    _customModelController.text = aiApiInfo.custom_model_name ?? '';
    _modelController.text = aiApiInfo.model_name;
  }

  @override
  void dispose() {
    _portController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _customModelController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _savePort() {
    final port = int.tryParse(_portController.text);
    if (port != null) {
      now_drive_port = port;
      saveSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('端口已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _saveCustomApi() {
    aiApiInfo.custom_api_url = _apiUrlController.text.isEmpty ? null : _apiUrlController.text;
    aiApiInfo.custom_api_key = _apiKeyController.text.isEmpty ? null : _apiKeyController.text;
    aiApiInfo.custom_model_name = _customModelController.text.isEmpty ? null : _customModelController.text;
    saveSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API配置已保存'), duration: Duration(seconds: 1)),
    );
  }

  void _saveModelName() {
    aiApiInfo.model_name = _modelController.text.isEmpty ? 'deepseek-chat' : _modelController.text;
    saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("设置"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题色
          Row(
            children: [
              const Text("主题色：", style: TextStyle(fontSize: 18)),
              DropdownButton<MaterialColor>(
                borderRadius: BorderRadius.circular(10),
                value: _selectedColor,
                onChanged: (color) => setState(() => _selectedColor = color!),
                items: const [
                  DropdownMenuItem(
                    value: Colors.blue,
                    child: Row(children: [
                      SizedBox(width: 20, height: 20, child: ColoredBox(color: Colors.blue)),
                      SizedBox(width: 8),
                      Text('蓝色'),
                    ]),
                  ),
                  DropdownMenuItem(
                    value: Colors.pink,
                    child: Row(children: [
                      SizedBox(width: 20, height: 20, child: ColoredBox(color: Colors.pink)),
                      SizedBox(width: 8),
                      Text('粉色'),
                    ]),
                  ),
                  DropdownMenuItem(
                    value: Colors.green,
                    child: Row(children: [
                      SizedBox(width: 20, height: 20, child: ColoredBox(color: Colors.green)),
                      SizedBox(width: 8),
                      Text('绿色'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 端口
          Row(
            children: [
              const Text("端口：", style: TextStyle(fontSize: 18)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: TextField(
                    controller: _portController,
                    decoration: InputDecoration(
                      hintText: '请输入端口',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[200],
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: _savePort,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _savePort(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // API来源选择
          SwitchListTile(
            title: const Text('使用自定义API'),
            subtitle: Text(
              aiApiInfo.use_custom_api ? '使用自己配置的API密钥和地址' : '使用服务器返回的API信息',
              style: const TextStyle(fontSize: 13),
            ),
            value: aiApiInfo.use_custom_api,
            onChanged: (val) {
              setState(() {
                aiApiInfo.use_custom_api = val;
              });
              saveSettings();
            },
          ),
          const SizedBox(height: 8),

          // 默认模型名称
          TextField(
            controller: _modelController,
            decoration: InputDecoration(
              labelText: '默认模型名称',
              hintText: '如 deepseek-chat',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveModelName,
              ),
            ),
            onSubmitted: (_) => _saveModelName(),
          ),
          const SizedBox(height: 16),

          // 自定义API配置
          if (aiApiInfo.use_custom_api) ...[
            const Divider(),
            const Text('自定义API配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'API URL',
                hintText: '如 https://api.deepseek.com/chat/completions',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saveCustomApi(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onSubmitted: (_) => _saveCustomApi(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customModelController,
              decoration: InputDecoration(
                labelText: '模型名称',
                hintText: '如 deepseek-chat',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saveCustomApi(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saveCustomApi,
              child: const Text('保存API配置'),
            ),
          ],

          // 服务器API信息展示
          if (!aiApiInfo.use_custom_api && aiApiInfo.api_url != null) ...[
            const Divider(),
            const Text('服务器API信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('API URL'),
              subtitle: Text(aiApiInfo.api_url ?? '', style: const TextStyle(fontSize: 12)),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('API Key'),
              subtitle: Text(
                aiApiInfo.api_key != null ? '${aiApiInfo.api_key!.substring(0, aiApiInfo.api_key!.length > 8 ? 8 : aiApiInfo.api_key!.length)}...' : '无',
                style: const TextStyle(fontSize: 12),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ==================== 组件 ====================

class CommandCard extends StatelessWidget {
  final CommandExecution command;

  const CommandCard({super.key, required this.command});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: command.isRunning
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  command.isCompleted ? Icons.check_circle : Icons.terminal,
                  size: 20,
                  color: command.isCompleted ? Colors.green : Colors.grey[700],
                ),
          title: Text(
            command.isRunning ? '正在执行: ${command.command}' : '已执行命令: ${command.command}',
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            if (command.result != null && command.result!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: SelectableText(
                  command.result!,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.greenAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DriveItem extends StatelessWidget {
  final String ip;
  final String name;
  final VoidCallback on_connect;

  const DriveItem({super.key, required this.ip, required this.name, required this.on_connect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.2), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2)),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
