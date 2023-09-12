import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '블루투스 테스트 화면',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '블루투스 테스트 화면'),
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
  /// 블루투스 통신 객체 생성
  final _ble = FlutterReactiveBle();

  /// 블루투스 통신 디바이스 리스트 생성
  final List<DiscoveredDevice> testlist = [];

  /// 블루투스 통신 스트림 생성
  StreamSubscription? _subscription;

  /// 현재 연결되어 있는지 확인
  bool _isScanning = false;

  /// 심박계 UUID
  final Uuid heartRateServiceCBUUID = Uuid.parse('180d');

  /// 심박수 측정 서비스 ID
  final Uuid heartRateMeasurementCharacteristicCBUUID = Uuid.parse('2a37');

  /// 디바이스 id저장
  String? deviceId;

  /// 심박수
  int heart = 0;

  @override
  Stream<ConnectionStateUpdate> get state => _deviceConnectionController.stream;
  final _deviceConnectionController = StreamController<ConnectionStateUpdate>();
  late StreamSubscription<ConnectionStateUpdate> _connection;
  late StreamSubscription<List<int>>? subscribeStream;

  /// 스캔 시작
  void startScan() async {
    /// 디바이스 목록 없애기
    testlist.clear();

    /// 스트림 취소
    _subscription?.cancel();

    /// 스트림 시작
    _subscription = _ble.scanForDevices(
      /// 원하는 서비스 아이디
      withServices: [heartRateServiceCBUUID],

      /// 스캔모드 설정
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      /// 디바이스 가 넘어보면 상태 바꿔주기
      setState(() {
        /// 있는 디바이스가 아니면 추가해주기
        if (!_isDeviceInList(device) && !device.name.isEmpty) {
          testlist.add(device);
          print(testlist);
        }
      });
    }, onError: (e) {
      /// 에러 발생시 에러 출력해주기
      print('error');
    });
  }

  /// 있는 블루투스인지 아닌지 확인
  bool _isDeviceInList(DiscoveredDevice device) {
    /// 찾은 디바이스가 찾았던 디바이스에 있는지 확인하기
    for (var d in testlist) {
      if (d.id == device.id) {
        return true;
      }
    }
    return false;
  }

  /// 블루투스 연동
  void connect(String deviceId) async {
    _connection = _ble.connectToDevice(id: deviceId).listen((update) {
      // 연동되면 상태 없데이트하기
      _deviceConnectionController.add(update);
      print(update.connectionState);

      // 블루투스 연동되고, 연결된 상태라면 읽어오기
      if (update.connectionState == DeviceConnectionState.connected) {
        read();
      }
    }, onError: (Object e) => print('$e'));
  }

  /// 블루투스 연동 끊기
  void disconnect() async {
    try {
      await _connection.cancel();
    } on Exception catch (e, _) {
      print("Error disconnecting from a device: $e");
    } finally {
      // Since [_connection] subscription is terminated, the "disconnected" state cannot be received and propagated
      _deviceConnectionController.add(
        ConnectionStateUpdate(
          deviceId: deviceId!,
          connectionState: DeviceConnectionState.disconnected,
          failure: null,
        ),
      );
    }
  }

  /// 블루투스 데이터 읽어오기
  void read() async {
    /// 어떤걸 받아올건지 정하기
    final characteristic = QualifiedCharacteristic(
        serviceId: heartRateServiceCBUUID,
        characteristicId: heartRateMeasurementCharacteristicCBUUID,
        deviceId: deviceId!);

    /// 정한걸 스트림으로 결과값 받아오기
    _ble.subscribeToCharacteristic(characteristic).listen((event) {
      // 받아온 결과값 프린트찍기
      print(event[1]);
      // 받아온 결과값 변수에 저장하기
      heart = event[1];
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    print('initState');
    _ble.statusStream.listen((status) {
      print(status);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    print('스캔 시작');
                    startScan();
                  },
                  child: Text('스캔 시작하기'),
                ),
                ElevatedButton(
                  onPressed: () {
                    print('연결 취소');
                    disconnect();
                  },
                  child: Text('연결 끊기'),
                ),
              ],
            ),
            Text('$heart'),
            Expanded(
              child: Container(
                color: Colors.lightGreen,
                child: ListView.builder(
                  itemCount: testlist.length,
                  itemBuilder: (BuildContext context, int index) {
                    final device = testlist[index];
                    return ListTile(
                      onTap: () {
                        print('$device.name');
                        deviceId = device.id;
                        connect(deviceId!);
                      },
                      title: Text(device.name ?? 'stringsss'),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ), // This trailingomma makes auto-formatting nicer for build methods.
    );
  }
}
