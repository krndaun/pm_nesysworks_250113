import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nesysworks/widgets/menu_widget.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  IO.Socket? _socket;
  List<dynamic> _realTimeData = [];

  @override
  void initState() {
    super.initState();
    _initializeSocket();
    _fetchInitialData();
  }

  // Socket.IO 초기화
  void _initializeSocket() {
    _socket = IO.io(
      'http://121.140.204.7:18988',
      IO.OptionBuilder().setTransports(['websocket']).build(),
    );

    _socket!.onConnect((_) {
      print('Socket.IO 서버에 연결됨');
    });

    // 실시간 데이터 업데이트 처리
    _socket!.on('update', (data) {
      setState(() {
        _realTimeData = data;
      });
    });

    // 참여 업데이트 처리
    _socket!.on('join_update', (data) {
      print('참여 업데이트 수신: $data');
      _fetchInitialData(); // 참여 업데이트 시 데이터 새로고침
    });

    _socket!.onDisconnect((_) => print('Socket.IO 연결 종료'));
  }

  // 초기 데이터 로드
  Future<void> _fetchInitialData() async {
    try {
      final response = await http.get(
        Uri.parse('http://121.140.204.7:18988/api/ast_req_info'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _realTimeData = jsonDecode(response.body);
        });
      } else {
        print('데이터 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('초기 데이터 로드 오류: $e');
    }
  }

  // 참여 API 호출
  Future<void> _joinRequest(int id) async {
    try {
      final response = await http.post(
        Uri.parse('http://121.140.204.7:18988/api/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('참여 성공!')),
          );
          _fetchInitialData(); // 데이터 새로고침
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('참여 실패: ${data['error']}')),
          );
        }
      } else {
        print('참여 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('참여 요청 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('참여 요청 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('실시간 요청 목록'),
      ),
      drawer: AppMenu(), // 모든 페이지에서 메뉴 사용 가능

      body: RefreshIndicator(
        onRefresh: _fetchInitialData,
        child: ListView(
          children: _realTimeData.map((item) {
            final int id = item['id'];
            final int joinedWorkers = item['joined_workers'];
            final int totalWorkers = item['workers'];

            return ListTile(
              title: Text('ID: $id'),
              subtitle: Text('참여 인원: $joinedWorkers / $totalWorkers'),
              trailing: ElevatedButton(
                onPressed: () => _joinRequest(id),
                child: Text('참여'),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
