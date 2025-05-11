import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]).then((_) {
    runApp(const MyApp());
  });
}

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

  var logger = Logger();

  late AnimationController _animationController;
  late Animation<double> _animation;

  final double baseWidthFactor = 0.5;

  @override
  void initState() {
    super.initState();
    logger.i('Initial state: $isConnected');
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
      if (isConnected) {
        logger.i('Closing previous connection...');
        channel.sink.close(status.goingAway);
      }

      logger.i('Connecting to ws://192.168.4.1:80...');
      channel = WebSocketChannel.connect(Uri.parse('ws://192.168.4.1:80'));

      setState(() {
        isConnected = false;
      });

      channel.stream.listen(
        (message) {
          if (!isConnected) {
            logger.i('Connection established.');
            setState(() {
              isConnected = true;
            });
          }

          final newFrequency = double.tryParse(message) ?? 0.0;
          setFrequency(newFrequency);
        },
        onError: (error) {
          logger.e('Connection error: $error');
          setState(() {
            isConnected = false;
          });
        },
        onDone: () {
          logger.i('Connection closed.');
          setState(() {
            isConnected = false;
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      logger.e('Exception during connection: $e');
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
      // sendFrequency();
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
        padding: const EdgeInsets.all(46.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      // Для десктопа
                      // child: Image.asset('1.png', fit: BoxFit.cover),
                      // Для мобилок
                      child: Image.asset('assets/1.png', fit: BoxFit.cover),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Поле показа частоты
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final fontSize = (constraints.maxWidth * 0.35)
                                  .clamp(20.0, 48.0);

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
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$currentFrequency Гц',
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),

                      // Поле ввода
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final fontSize = (constraints.maxWidth * 0.35)
                                  .clamp(20.0, 48.0);

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.teal,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: fontSize * 0.3,
                                    ),
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: fontSize,
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
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),

                      // Кнопка отправки
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final iconSize = (constraints.maxWidth * 0.35)
                                  .clamp(20.0, 48.0);

                              return ElevatedButton(
                                onPressed: sendFrequency,
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
                  const SizedBox(height: 2),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double baseFontSize =
                          constraints.maxWidth * 0.035; // ~5% ширины экрана
                      final double buttonFontSize = constraints.maxWidth * 0.02;
                      final double paddingValue = constraints.maxWidth * 0.02;

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            baseFontSize * 0.6,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(paddingValue),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Опционально под мобилки, не уверен, что все войдет
                              // Text(
                              //   'Управление питанием и подключением контроллера',
                              //   style: TextStyle(
                              //     fontSize: baseFontSize * 1.2,
                              //     fontWeight: FontWeight.bold,
                              //   ),
                              // ),
                              // const Divider(),
                              SwitchListTile(
                                title: Text(
                                  'Питание',
                                  style: TextStyle(fontSize: baseFontSize),
                                ),
                                value: isOn,
                                onChanged: (value) => togglePower(),
                              ),
                              SizedBox(height: paddingValue * 0.1),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: paddingValue,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          isConnected
                                              ? 'Статус: подключено'
                                              : 'Статус: не подключено',
                                          style: TextStyle(
                                            fontSize: baseFontSize,
                                          ),
                                        ),
                                        SizedBox(width: paddingValue * 0.1),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: connectToController,
                                    // icon: Icon(
                                    //   Icons.link_rounded,
                                    //   size: baseFontSize * 0.7,
                                    // ),
                                    label: Text(
                                      'Подключиться',
                                      style: TextStyle(
                                        fontSize: buttonFontSize,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[300],
                                      padding: EdgeInsets.symmetric(
                                        horizontal: paddingValue,
                                        vertical: paddingValue * 0.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          baseFontSize * 0.5,
                                        ),
                                      ),
                                      elevation: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
