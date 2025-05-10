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

class _OilPumpScreenState extends State<OilPumpScreen> {
  double frequency = 0.0;
  bool isOn = false;
  String currentFrequency = '0.0';

  void togglePower() {
    setState(() {
      isOn = !isOn;
    });
  }

  void setFrequency(double value) {
    setState(() {
      frequency = value;
      currentFrequency = value.toStringAsFixed(1);
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
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor:
                          isOn ? (frequency / 100.0).clamp(0.0, 1.0) : 0.0,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(color: Colors.teal, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$currentFrequency Гц',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(fontSize: 36),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),

                      // Поле ввода
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
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

                      // Кнопка отправки
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(
                              LucideIcons.send,
                              color: Colors.white,
                              size: 40,
                            ),
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
