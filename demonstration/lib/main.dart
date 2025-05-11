import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert'; // Нужен ли?
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Нефтесервис',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 50,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const OilPumpScreen(),
    );
  }
}

class OilPumpScreen extends StatefulWidget {
  const OilPumpScreen({super.key});

  @override
  State<OilPumpScreen> createState() => _OilPumpScreenState();
}

class _OilPumpScreenState extends State<OilPumpScreen>
    with TickerProviderStateMixin {
  late WebSocketChannel channel;
  bool isConnected = false;

  double frequency = 0.0;
  bool isOn = false;
  String currentFrequency = '0';

  late AnimationController _animationController;
  late Animation<double> _animation;

  final double baseWidthFactor = 0.5;

  @override
  void initState() {
    super.initState();
    print('Initial state: $isConnected');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // Подключение к контроллеру
    connectToController();
  }

  void sendFrequency() {
    if (isConnected) {
      channel.sink.add('SET_FREQ:$frequency');
    }
  }

  void connectToController() {
    try {
      print('Connecting to ws://192.168.4.1:81...');
      channel = WebSocketChannel.connect(Uri.parse('ws://192.168.4.1:81'));
      print('Connection established.');
      setState(() {
        isConnected = true;
      });

      channel.stream.listen(
        (message) {
          final newFrequency = double.tryParse(message) ?? 0.0;
          setFrequency(newFrequency);
        },
        onError: (error) {
          print('Connection error: $error');
          setState(() {
            isConnected = false;
          });
        },
        onDone: () {
          print('Connection closed.');
          setState(() {
            isConnected = false;
          });
        },
      );
    } catch (e) {
      print('Exception during connection: $e');
      setState(() {
        isConnected = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (isConnected) {
      channel.sink.close(status.goingAway);
    }
    super.dispose();
  }

  void togglePower() {
    setState(() {
      isOn = !isOn;
      if (isOn) {
        final duration =
            (5000 / (1 + math.tan(frequency.clamp(1.0, 100.0) / 20))).toInt();

        _animationController.duration = Duration(milliseconds: duration);
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
      }
    });
  }

  void setFrequency(double value) {
    setState(() {
      frequency = value;
      currentFrequency =
          value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
      sendFrequency();
      // Скорость анимации
      if (isOn) {
        final duration = (20000 / (value.clamp(1.0, 100.0))).toInt();
        _animationController.duration = Duration(milliseconds: duration);
        _animationController.repeat(reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Image.asset('1.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Анимированная шкала с изменением ширины
                  SizedBox(
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Основная линия
                        Container(
                          width: double.infinity,
                          height: 2,
                          color: Colors.teal,
                        ),
                        // Анимированная полоса
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            if (!isOn) {
                              return FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.0,
                                child: child!,
                              );
                            }

                            // ignore: unused_local_variable
                            final factor = (frequency / 100.0).clamp(0.0, 1.0);
                            final widthFactor =
                                baseWidthFactor +
                                (_animation.value * (1.0 - baseWidthFactor));
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: widthFactor,
                              child: child,
                            );
                          },
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 74, 74, 74),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'ЧелГУ/Нефт.сервис',
                            style: Theme.of(context).textTheme.titleMedium!
                                .copyWith(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 30),
                        // передумал
                        // Padding(
                        //   padding: const EdgeInsets.only(right: 12.0),
                        //   child: Container(
                        //     width: 32,
                        //     height: 32,
                        //     decoration: BoxDecoration(
                        //       shape: BoxShape.circle,
                        //       color: isConnected ? Colors.green : Colors.red,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      // Поле показа частоты
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final fontSize = constraints.maxWidth * 0.35;
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.teal,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$currentFrequency Гц',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Поле ввода
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(color: Colors.teal, width: 2),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return TextField(
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: constraints.maxWidth * 0.35,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Гц',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) {
                                        final freq =
                                            double.tryParse(value) ?? 0.0;
                                        setFrequency(freq);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Кнопка отправки
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final iconSize = constraints.maxWidth * 0.35;
                              return ElevatedButton(
                                onPressed: () {
                                  sendFrequency();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Icon(
                                  LucideIcons.send,
                                  color: Colors.white,
                                  size: iconSize,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Управление питанием и подключением контроллера',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          SwitchListTile(
                            title: const Text(
                              'Питание',
                              style: TextStyle(fontSize: 30),
                            ),
                            value: isOn,
                            onChanged: (value) => togglePower(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      isConnected
                                          ? 'Статус подключения: подключено'
                                          : 'Статус подключения: не подключено',
                                      style: const TextStyle(fontSize: 30),
                                    ),
                                    const SizedBox(width: 8),
                                    // Нужен ли?
                                    // Container(
                                    //   width: 32,
                                    //   height: 32,
                                    //   decoration: BoxDecoration(
                                    //     shape: BoxShape.circle,
                                    //     color:
                                    //         isConnected
                                    //             ? Colors.green
                                    //             : Colors.red,
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: connectToController,
                                // icon: const Icon(Icons.link_rounded, size: 14),
                                label: Text(
                                  'Подключиться',
                                  style: const TextStyle(fontSize: 30),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 1,
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
