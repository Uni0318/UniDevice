// @dart=2.17

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart'; // 确保导入此文件
//import 'package:flutter_web_plugins/flutter_web_plugins.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //setUrlStrategy(PathUrlStrategy());
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eunice',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PinCodeScreen(),
    );
  }
}

class PinCodeScreen extends StatefulWidget {
  const PinCodeScreen({super.key});

  @override
  State<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends State<PinCodeScreen> {
  final TextEditingController _pinController = TextEditingController();
  final String _correctPin = "1234"; // 您可以在這裡設置您想要的PIN碼

  void _verifyPin() {
    if (_pinController.text == _correctPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CalendarScreen()),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('錯誤'),
            content: const Text('密碼不正確'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('確定'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歡迎'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('輸入密碼'),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '密碼',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyPin,
              child: const Text('驗證'),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final logger = Logger();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, dynamic> _usageData = {};
  late Future<Map<String, dynamic>> futureUsageData;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('zh_CN', null).then((_) => setState(() {}));
    _loadUsageData();
  }

  Future<void> _loadUsageData() async {
    futureUsageData = fetchUsageData();
    try {
      _usageData = await futureUsageData;
    } catch (e) {
      logger.e('Error loading usage data: $e');
    }
  }

  Future<Map<String, dynamic>> fetchUsageData() async {
    try {
      final databaseReference = FirebaseDatabase.instance.ref();
      final dataSnapshot = await databaseReference.get();
      if (dataSnapshot.exists) {
        final data = dataSnapshot.value as Map<dynamic, dynamic>;
        logger.i('Data fetched from Firebase: $data');

        // 將 LinkedMap 轉換為 Map<String, dynamic>
        Map<String, dynamic> parsedData = {};
        data.forEach((key, value) {
          if (value is Map) {
            parsedData[key.toString()] = Map<String, dynamic>.from(value);
          }
        });
        return parsedData;
      } else {
        throw Exception('No data available');
      }
    } catch (e) {
      logger.e('Error fetching usage data: $e');
      throw Exception('Error fetching usage data');
    }
  }

  void _navigateToRangeFilter(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RangeFilterScreen(usageData: _usageData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('月曆'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () => _navigateToRangeFilter(context),
          ),
          DropdownButton<CalendarFormat>(
            value: _calendarFormat,
            items: const [
              DropdownMenuItem(
                value: CalendarFormat.month,
                child: Text('月'),
              ),
              DropdownMenuItem(
                value: CalendarFormat.twoWeeks,
                child: Text('兩週'),
              ),
              DropdownMenuItem(
                value: CalendarFormat.week,
                child: Text('週'),
              )
            ],
            onChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format!;
                });
              }
            },
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: futureUsageData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          } else {
            _usageData = snapshot.data!;
            return Column(
              children: [
                TableCalendar(
                  locale: 'zh_CN',
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsageDetailsScreen(date: selectedDay, usageData: _usageData),
                      ),
                    );
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format!;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

class UsageDetailsScreen extends StatelessWidget {
  final DateTime date;
  final Map<String, dynamic> usageData;

  const UsageDetailsScreen({super.key, required this.date, required this.usageData});

  List<Widget> buildDetails(BuildContext context, Map<String, dynamic> data) {
    List<Widget> details = [];
    data.forEach((key, value) {
      if (value is Map) {
        details.add(Text('模式 1 總時長: ${(value['mode1TotalTime'] as num).toInt()} 秒',
            style: Theme.of(context).textTheme.titleLarge));
        details.add(const SizedBox(height: 10));
        details.add(Text('模式 1 失敗次數: ${(value['mode1FailureCount'] as num).toInt()}',
            style: Theme.of(context).textTheme.titleLarge));
        details.add(const SizedBox(height: 10));
        details.add(Text('模式 1 成功次數: ${(value['mode1SuccessCount'] as num).toInt()}',
            style: Theme.of(context).textTheme.titleLarge));
        details.add(const SizedBox(height: 10));
        details.add(Text('模式 2 總時長: ${(value['mode2TotalTime'] as num).toInt()} 秒',
            style: Theme.of(context).textTheme.titleLarge));
        details.add(const SizedBox(height: 10));
        details.add(Text('模式 2 失敗次數: ${(value['mode2FailureCount'] as num).toInt()}',
            style: Theme.of(context).textTheme.titleLarge));
        details.add(const SizedBox(height: 10));
        details.add(Text('模式 2 成功次數: ${(value['mode2SuccessCount'] as num).toInt()}',
            style: Theme.of(context).textTheme.titleLarge));
        details.add(const SizedBox(height: 10));
        details.add(const Divider()); // 分隔線
      }
    });
    return details;
  }

  @override
  Widget build(BuildContext context) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    final data = usageData[dateString];

    return Scaffold(
      appBar: AppBar(
        title: Text('使用細節 - $dateString'),
      ),
      body: data == null || data.isEmpty
          ? const Center(child: Text('無數據'))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: buildDetails(context, data),
        ),
      ),
    );
  }
}

class RangeFilterScreen extends StatefulWidget {
  final Map<String, dynamic> usageData;

  const RangeFilterScreen({super.key, required this.usageData});

  @override
  State<RangeFilterScreen> createState() => _RangeFilterScreenState();
}

class _RangeFilterScreenState extends State<RangeFilterScreen> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime _focusedDay = DateTime.now();
  final RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<Map<String, String>> filteredData = [];

  Future<void> _downloadData() async {
    if (_rangeStart == null || _rangeEnd == null) return;

    final start = _rangeStart!;
    final end = _rangeEnd!;
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final csvData = [
      ['日期', '模式1總時長', '模式1失敗次數', '模式1成功次數', '模式2總時長', '模式2失敗次數', '模式2成功次數']
    ];

    for (var day = start; day.isBefore(end.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      final dateString = dateFormatter.format(day);
      final data = widget.usageData[dateString];
      if (data != null) {
        data.forEach((key, value) {
          if (value is Map) {
            csvData.add([
              dateString,
              (value['mode1TotalTime'] as num).toInt().toString(),
              (value['mode1FailureCount'] as num).toInt().toString(),
              (value['mode1SuccessCount'] as num).toInt().toString(),
              (value['mode2TotalTime'] as num).toInt().toString(),
              (value['mode2FailureCount'] as num).toInt().toString(),
              (value['mode2SuccessCount'] as num).toInt().toString(),
            ]);
            filteredData.add({
              '日期': dateString,
              '模式1總時長': (value['mode1TotalTime'] as num).toInt().toString(),
              '模式1失敗次數': (value['mode1FailureCount'] as num).toInt().toString(),
              '模式1成功次數': (value['mode1SuccessCount'] as num).toInt().toString(),
              '模式2總時長': (value['mode2TotalTime'] as num).toInt().toString(),
              '模式2失敗次數': (value['mode2FailureCount'] as num).toInt().toString(),
              '模式2成功次數': (value['mode2SuccessCount'] as num).toInt().toString(),
            });
          }
        });
      }
    }

    final csv = const ListToCsvConverter().convert(csvData);
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/usage_data.csv';
    final file = File(path);
    await file.writeAsString(csv);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('文件已保存至: $path')),
    );
  }

  Widget _buildRangeSummary() {
    if (_rangeStart == null || _rangeEnd == null) {
      return const Text('請選擇日期範圍');
    }

    final start = _rangeStart!;
    final end = _rangeEnd!;
    int mode1TotalFailures = 0;
    int mode1TotalSuccesses = 0;
    int mode2TotalFailures = 0;
    int mode2TotalSuccesses = 0;
    int totalUsageDuration = 0;

    List<Widget> detailedDataWidgets = [];

    for (var day = start; day.isBefore(end.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      final dateString = DateFormat('yyyy-MM-dd').format(day);
      final data = widget.usageData[dateString];
      if (data != null) {
        data.forEach((key, value) {
          if (value is Map) {
            mode1TotalFailures += (value['mode1FailureCount'] as num).toInt();
            mode1TotalSuccesses += (value['mode1SuccessCount'] as num).toInt();
            mode2TotalFailures += (value['mode2FailureCount'] as num).toInt();
            mode2TotalSuccesses += (value['mode2SuccessCount'] as num).toInt();
            totalUsageDuration += (value['mode1TotalTime'] as num).toInt() +
                (value['mode2TotalTime'] as num).toInt();

            detailedDataWidgets.add(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('日期: $dateString'),
                Text('模式1總時長: ${(value['mode1TotalTime'] as num).toInt()} 秒'),
                Text('模式1失敗次數: ${(value['mode1FailureCount'] as num).toInt()}'),
                Text('模式1成功次數: ${(value['mode1SuccessCount'] as num).toInt()}'),
                Text('模式2總時長: ${(value['mode2TotalTime'] as num).toInt()} 秒'),
                Text('模式2失敗次數: ${(value['mode2FailureCount'] as num).toInt()}'),
                Text('模式2成功次數: ${(value['mode2SuccessCount'] as num).toInt()}'),
                const Divider(),
              ],
            ));
          }
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '所選日期範圍: ${DateFormat('yyyy年MM月dd日').format(start)} - ${DateFormat('yyyy年MM月dd日').format(end)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          '模式 1 總失敗次數: $mode1TotalFailures',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          '模式 1 總成功次數: $mode1TotalSuccesses',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          '模式 2 總失敗次數: $mode2TotalFailures',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          '模式 2 總成功次數: $mode2TotalSuccesses',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          '總使用時長: ${Duration(seconds: totalUsageDuration).inHours} 小時 ${Duration(seconds: totalUsageDuration).inMinutes.remainder(60)} 分鐘 ${totalUsageDuration.remainder(60)} 秒',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        Text(
          '範圍內的數據:',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        ...detailedDataWidgets,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('篩選日期範圍'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TableCalendar(
              locale: 'zh_CN',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              onRangeSelected: (start, end, focusedDay) {
                setState(() {
                  _rangeStart = start;
                  _rangeEnd = end;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarFormat: _calendarFormat,
              availableCalendarFormats: const {CalendarFormat.month: '月'},
              rangeSelectionMode: _rangeSelectionMode,
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format!;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: _buildRangeSummary(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _downloadData,
              child: const Text('下載範圍數據'),
            ),
          ],
        ),
      ),
    );
  }
}
