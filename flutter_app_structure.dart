import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const CommuCalcApp());
}

class CommuCalcApp extends StatelessWidget {
  const CommuCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Commu-Calc',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.tealAccent,
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  // Контроллеры ввода
  final _lightDayCtrl = TextEditingController();
  final _lightNightCtrl = TextEditingController();
  final _heatingCtrl = TextEditingController();
  final _waterHotCtrl = TextEditingController();
  final _waterColdCtrl = TextEditingController();

  // Предыдущие показания
  Map<String, dynamic> _lastMonthData = {
    'lightDay': 3917, 'lightNight': 1609, 'heating': 4.249, 'waterHot': 173, 'waterCold': 225
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commu-Calc', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInputField('Свет (День)', _lightDayCtrl, _lastMonthData['lightDay']),
            const SizedBox(height: 16),
            _buildInputField('Свет (Ночь)', _lightNightCtrl, _lastMonthData['lightNight']),
            const SizedBox(height: 16),
            _buildInputField('Отопление', _heatingCtrl, _lastMonthData['heating'], isDouble: true),
            const SizedBox(height: 16),
            _buildInputField('Вода ГВС', _waterHotCtrl, _lastMonthData['waterHot']),
            const SizedBox(height: 16),
            _buildInputField('Вода ХВС', _waterColdCtrl, _lastMonthData['waterCold']),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                // Логика отправки POST запроса к GAS
              },
              child: const Text('Сохранить показания', style: TextStyle(fontSize: 18)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, num lastValue, {bool isDouble = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, fontFamily: 'RobotoMono'),
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              onChanged: (val) {
                setState(() {}); // Перестроение для анимации дельты
              },
            ),
          ),
          const SizedBox(width: 16),
          _buildDeltaDisplay(controller.text, lastValue, isDouble),
        ],
      ),
    );
  }

  Widget _buildDeltaDisplay(String currentText, num lastValue, bool isDouble) {
    num current = isDouble ? (double.tryParse(currentText) ?? 0) : (int.tryParse(currentText) ?? 0);
    num delta = current > 0 ? current - lastValue : 0;
    
    // Форматирование
    String deltaStr = isDouble ? delta.toStringAsFixed(3) : delta.toInt().toString();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('Разница', style: TextStyle(fontSize: 12, color: Colors.grey)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            delta > 0 ? '+$deltaStr' : '0',
            key: ValueKey(deltaStr),
            style: TextStyle(
              fontSize: 28, 
              fontWeight: FontWeight.bold,
              color: delta > 0 ? Colors.tealAccent : Colors.white38,
              fontFamily: 'RobotoMono'
            ),
          ),
        ),
      ],
    );
  }
}
