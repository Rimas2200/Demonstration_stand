import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }
  runApp(const MyApp());
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
  bool isConnecting = false;
  double frequency = 0.0; // Для внутреннего использования и анимации
  String currentFrequency = '0'; // Только для отображения данных с контроллера
  String _inputFrequency = ''; // Ввод пользователя
  bool isOn = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      connectToController(context);
    });
  }

  void showSnackbar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ?? Colors.teal,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void sendFrequency(BuildContext context) {
    if (isConnected && channel != null) {
      final input = double.tryParse(_inputFrequency);
      if (input == null || input <= 0) {
        showSnackbar(
          context,
          'Введите корректную частоту',
          backgroundColor: Colors.red,
        );
        return;
      }
      final message = 'SET_FREQ:$input';
      logger.i('Attempting to send frequency: $input Hz');
      try {
        channel.sink.add(message);
        logger.i('Frequency sent: $message');
        showSnackbar(context, 'Отправлено: $input Гц');
      } catch (e) {
        logger.e('Error sending frequency: $e');
        showSnackbar(
          context,
          'Ошибка отправки: $e',
          backgroundColor: Colors.red,
        );
      }
    } else {
      logger.w('No active connection or channel is null!');
      showSnackbar(context, 'Нет соединения!', backgroundColor: Colors.red);
    }
  }

  void reconnectIfNeeded() {
    if (channel == null || channel.closeCode != null) {
      logger.w('Reconnecting to WebSocket...');
      connectToController(context);
    }
  }

  void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void connectToController(BuildContext context) async {
    if (isConnecting) {
      logger.i('Подключение уже в процессе...');
      return;
    }
    setState(() {
      isConnecting = true;
    });
    try {
      if (isConnected) {
        logger.i('Закрытие предыдущего соединения...');
        await channel.sink.close(status.goingAway);
        showSnackBar(context, 'Закрытие старого соединения');
      }
      logger.i('Подключение к ws://192.168.4.1:80...');
      final socket = await Socket.connect(
        '192.168.4.1',
        80,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy(); // Закрываем соединение
      logger.i('Сервер доступен, продолжаем подключение.');
      channel = WebSocketChannel.connect(Uri.parse('ws://192.168.4.1:80'));
      logger.i('Канал WebSocket успешно подключен.');
      setState(() {
        isConnected = true;
        isConnecting = false;
      });
      channel.stream.listen(
        (message) {
          logger.i('Получено сообщение: $message');
          final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(message);
          if (match != null && match.group(0) != null) {
            final String numericValue = match.group(0)!;
            final double? value = double.tryParse(numericValue);
            if (value != null) {
              setFrequency(value); // Обновляется только из данных контроллера
            } else {
              logger.e('Не удалось преобразовать в число: $numericValue');
            }
          } else {
            logger.e('Частота не найдена в строке: $message');
          }
        },
        onError: (error) {
          logger.e('Ошибка соединения: $error');
          showSnackBar(context, 'Ошибка соединения');
          setState(() {
            isConnected = false;
          });
        },
        onDone: () {
          logger.i('Соединение закрыто.');
          showSnackBar(context, 'Соединение закрыто');
          setState(() {
            isConnected = false;
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      logger.e('Ошибка при подключении: $e');
      showSnackBar(context, 'Ошибка при подключении: $e');
      setState(() {
        isConnected = false;
        isConnecting = false;
      });
    }
  }

  void sendMessage(String message) {
    if (isConnected) {
      logger.i('Отправка сообщения: $message');
      channel.sink.add(message);
    } else {
      logger.e('Ошибка: Нет активного соединения!');
      showSnackBar(context, 'Нет активного соединения!');
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
                      child: Image.asset('assets/1.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 2,
                          color: Colors.teal,
                        ),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Отображение частоты (только данные с контроллера)
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
                                        setState(() {
                                          _inputFrequency = value;
                                        });
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
                                onPressed: () => sendFrequency(context),
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
                                  size: 32,
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
                      final double baseFontSize = constraints.maxWidth * 0.035;
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
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed:
                                        () => connectToController(context),
                                    label: Text(
                                      isConnected
                                          ? 'Отключиться'
                                          : 'Подключиться',
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
