import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  double frequency = 0.0;
  bool isOn = false;
  String currentFrequency = '0';

  late AnimationController _animationController;
  late Animation<double> _animation;

  final double baseWidthFactor = 0.5;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
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
                    child: Text(
                      'ЧелГУ/Нефт.сервис',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium!.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
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
                                onPressed: () {},
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
                  SwitchListTile(
                    title: const Text('Питание'),
                    value: isOn,
                    onChanged: (value) => togglePower(),
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
