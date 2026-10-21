import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/meter_reading.dart';
import 'services/gas_client.dart';
import 'services/github_updater.dart';
import 'services/meter_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CommuCalcApp());
}

class CommuCalcApp extends StatelessWidget {
  const CommuCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Commu-Calc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF131B2E),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
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

class _CalculatorScreenState extends State<CalculatorScreen> with SingleTickerProviderStateMixin {
  final _lightDayCtrl = TextEditingController();
  final _lightNightCtrl = TextEditingController();
  final _heatingCtrl = TextEditingController();
  final _waterHotCtrl = TextEditingController();
  final _waterColdCtrl = TextEditingController();

  final _lightDayFocus = FocusNode();
  final _lightNightFocus = FocusNode();
  final _heatingFocus = FocusNode();
  final _waterHotFocus = FocusNode();
  final _waterColdFocus = FocusNode();

  final _storage = MeterStorage();
  final _gasClient = GasClient();

  final bool _isLoading = false;
  bool _isSaving = false;
  ReleaseInfo? _availableUpdate;
  bool _isCheckingUpdate = false;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeController.value = 1.0;
    _bootstrapData();
    _checkAppUpdate(silent: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _lightDayCtrl.dispose();
    _lightNightCtrl.dispose();
    _heatingCtrl.dispose();
    _waterHotCtrl.dispose();
    _waterColdCtrl.dispose();
    _lightDayFocus.dispose();
    _lightNightFocus.dispose();
    _heatingFocus.dispose();
    _waterHotFocus.dispose();
    _waterColdFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrapData() async {
    await _storage.load();
    if (mounted) setState(() {});
    _syncWithRemote();
  }

  Future<void> _syncWithRemote() async {
    try {
      final remoteList = await _gasClient.fetchHistory();
      if (remoteList.isNotEmpty && mounted) {
        setState(() {
          _storage.mergeFromRemote(remoteList);
        });
      }
    } catch (e) {
      debugPrint('Sync warning: $e');
    }
  }

  Future<void> _checkAppUpdate({bool silent = true}) async {
    if (_isCheckingUpdate) return;
    _isCheckingUpdate = true;
    try {
      final release = await GitHubUpdater.checkForUpdate();
      if (mounted) {
        setState(() {
          _availableUpdate = release;
        });
        if (release != null && !silent) {
          _showUpdateDialog(release);
        } else if (release == null && !silent) {
          _showFeedback('У вас установлена последняя версия (v${GitHubUpdater.currentVersion})', isError: false);
        }
      }
    } catch (e) {
      if (!silent && mounted) {
        _showFeedback('Ошибка проверки обновлений: $e', isError: true);
      }
    } finally {
      _isCheckingUpdate = false;
    }
  }

  void _showUpdateDialog(ReleaseInfo release) async {
    final alreadyDownloaded = await GitHubUpdater.isApkAlreadyDownloaded(release);
    double downloadProgress = alreadyDownloaded ? 1.0 : 0.0;
    bool isDownloading = false;
    String statusText = alreadyDownloaded ? 'Файл обновления готов к установке (46.9 МБ)' : 'Доступна версия ${release.tagName}';

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !isDownloading,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.2)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF38BDF8), size: 24),
              ),
              const SizedBox(width: 12),
              Text('Обновление', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.2)),
                ),
                child: Text(
                  'v${GitHubUpdater.currentVersion}  ➔  ${release.tagName}',
                  style: GoogleFonts.robotoMono(color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              if (release.notes.isNotEmpty) ...[
                Text(
                  release.notes,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.4),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
              ],
              Text(statusText, style: const TextStyle(fontSize: 12, color: Colors.white60)),
              if (isDownloading) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: downloadProgress > 0 ? downloadProgress : null,
                    backgroundColor: Colors.white10,
                    color: const Color(0xFF38BDF8),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(downloadProgress * 100).toInt()}%',
                    style: GoogleFonts.robotoMono(fontSize: 12, color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDownloading ? null : () => Navigator.pop(ctx),
              child: Text('Позже', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0A0F1D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: isDownloading
                  ? null
                  : () async {
                      setDlgState(() {
                        isDownloading = true;
                        statusText = 'Подготовка пакета...';
                      });
                      try {
                        final result = await GitHubUpdater.downloadAndInstall(
                          release,
                          onProgress: (prog, rec, tot) {
                            setDlgState(() {
                              downloadProgress = prog;
                              final mbRec = (rec / 1048576).toStringAsFixed(1);
                              final mbTot = (tot / 1048576).toStringAsFixed(1);
                              statusText = 'Загружено: $mbRec / $mbTot МБ';
                            });
                          },
                        );

                        if (result == 'INSTALLED') {
                          if (context.mounted) Navigator.pop(ctx);
                          _showFeedback('Запущен системный установщик...', isError: false);
                        } else if (result == 'NEEDS_PERMISSION') {
                          setDlgState(() {
                            isDownloading = false;
                            statusText = 'Разрешите установку из источника и нажмите УСТАНОВИТЬ';
                          });
                        } else {
                          setDlgState(() {
                            isDownloading = false;
                            statusText = 'Статус: $result';
                          });
                        }
                      } catch (e) {
                        setDlgState(() {
                          isDownloading = false;
                          statusText = 'Сбой: $e';
                        });
                      }
                    },
              child: Text(alreadyDownloaded ? 'УСТАНОВИТЬ' : 'ОБНОВИТЬ', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveData() async {
    final last = _storage.lastReading;

    final lightDay = _parseNum(_lightDayCtrl.text, last.lightDay);
    final lightNight = _parseNum(_lightNightCtrl.text, last.lightNight);
    final heating = _parseDouble(_heatingCtrl.text, last.heating);
    final waterHot = _parseNum(_waterHotCtrl.text, last.waterHot);
    final waterCold = _parseNum(_waterColdCtrl.text, last.waterCold);

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${(now.year % 100).toString().padLeft(2, '0')}';

    final newReading = MeterReading(
      date: dateStr,
      lightDay: lightDay,
      lightNight: lightNight,
      heating: heating,
      waterHot: waterHot,
      waterCold: waterCold,
    );

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    await _storage.addReading(newReading);

    bool remoteSuccess = false;
    String? remoteError;
    try {
      await _gasClient.sendReading(newReading);
      remoteSuccess = true;
    } catch (e) {
      remoteError = e.toString();
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (remoteSuccess) {
        HapticFeedback.lightImpact();
        _showFeedback('Показания успешно сохранены и синхронизированы!', isError: false);
        _clearInputs();
      } else {
        _showFeedback('Сохранено локально! Облако временно недоступно: $remoteError', isError: true);
        _clearInputs();
      }
    }
  }

  void _clearInputs() {
    _lightDayCtrl.clear();
    _lightNightCtrl.clear();
    _heatingCtrl.clear();
    _waterHotCtrl.clear();
    _waterColdCtrl.clear();
  }

  num _parseNum(String text, num fallback) {
    if (text.trim().isEmpty) return fallback;
    return num.tryParse(text.trim().replaceAll(',', '.')) ?? fallback;
  }

  double _parseDouble(String text, double fallback) {
    if (text.trim().isEmpty) return fallback;
    return double.tryParse(text.trim().replaceAll(',', '.')) ?? fallback;
  }

  void _showFeedback(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.cloud_off_rounded : Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
      backgroundColor: isError ? const Color(0xFFD97706) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    ));
  }

  MeterConsumptionBreakdown _computeBreakdown(MeterType type, String currentText) {
    num? inputVal;
    if (currentText.trim().isNotEmpty) {
      final normalized = currentText.replaceAll(',', '.');
      inputVal = type.isDecimal ? (double.tryParse(normalized) ?? 0.0) : (num.tryParse(normalized) ?? 0);
    }
    return MeterConsumptionBreakdown.calculate(
      type: type,
      lastReading: _storage.lastReading,
      previousReading: _storage.previousReading,
      prePreviousReading: _storage.prePreviousReading,
      currentInputVal: inputVal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastReading = _storage.lastReading;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF090D16),
                    Color(0xFF0F172A),
                    Color(0xFF090D16),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    const Color(0xFF38BDF8).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -100,
            child: Container(
              width: 440,
              height: 440,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF818CF8).withValues(alpha: 0.10),
                    const Color(0xFF818CF8).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2))
                    : FadeTransition(
                        opacity: _fadeController,
                        child: Column(
                          children: [
                            _buildHeader(lastReading.date),
                            Expanded(
                              child: ListView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(18.0, 4.0, 18.0, 96.0),
                                children: [
                                  _buildMeterCard(
                                    type: MeterType.lightDay,
                                    controller: _lightDayCtrl,
                                    focusNode: _lightDayFocus,
                                    nextFocus: _lightNightFocus,
                                    icon: Icons.wb_sunny_rounded,
                                    accentColor: const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildMeterCard(
                                    type: MeterType.lightNight,
                                    controller: _lightNightCtrl,
                                    focusNode: _lightNightFocus,
                                    nextFocus: _heatingFocus,
                                    icon: Icons.nights_stay_rounded,
                                    accentColor: const Color(0xFF818CF8),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildMeterCard(
                                    type: MeterType.heating,
                                    controller: _heatingCtrl,
                                    focusNode: _heatingFocus,
                                    nextFocus: _waterHotFocus,
                                    icon: Icons.local_fire_department_rounded,
                                    accentColor: const Color(0xFFF43F5E),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildMeterCard(
                                    type: MeterType.waterHot,
                                    controller: _waterHotCtrl,
                                    focusNode: _waterHotFocus,
                                    nextFocus: _waterColdFocus,
                                    icon: Icons.water_drop_rounded,
                                    accentColor: const Color(0xFFFB923C),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildMeterCard(
                                    type: MeterType.waterCold,
                                    controller: _waterColdCtrl,
                                    focusNode: _waterColdFocus,
                                    nextFocus: null,
                                    icon: Icons.water_drop_outlined,
                                    accentColor: const Color(0xFF38BDF8),
                                    isLast: true,
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: _buildStickyBottomBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String lastDate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commu-Calc',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (lastDate.isNotEmpty)
                    Text(
                      'База: $lastDate',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (_availableUpdate != null)
                IconButton(
                  icon: const Badge(
                    backgroundColor: Color(0xFF38BDF8),
                    smallSize: 8,
                    child: Icon(Icons.cloud_download_rounded, color: Color(0xFF38BDF8), size: 22),
                  ),
                  tooltip: 'Доступно обновление ${_availableUpdate!.tagName}',
                  onPressed: () => _showUpdateDialog(_availableUpdate!),
                ),
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white70, size: 22),
                tooltip: 'История показаний',
                onPressed: _showHistorySheet,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 22),
                color: const Color(0xFF131B2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                onSelected: (val) {
                  if (val == 'refresh') _bootstrapData();
                  if (val == 'update') _checkAppUpdate(silent: false);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 18, color: Colors.white70),
                        SizedBox(width: 10),
                        Text('Обновить данные', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'update',
                    child: Row(
                      children: [
                        Icon(Icons.cloud_sync_rounded, size: 18, color: Color(0xFF38BDF8)),
                        SizedBox(width: 10),
                        Text('Проверить обновление', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeterCard({
    required MeterType type,
    required TextEditingController controller,
    required FocusNode focusNode,
    required FocusNode? nextFocus,
    required IconData icon,
    required Color accentColor,
    bool isLast = false,
  }) {
    final lastReading = _storage.lastReading;
    final lastVal = type.getValue(lastReading);
    final breakdown = _computeBreakdown(type, controller.text);
    final isLowerThanPrevious = breakdown.currentConsumption != null && breakdown.currentConsumption! < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowerThanPrevious
              ? Colors.amber.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Шапка карточки: Иконка, Имя счетчика и Базовые показания
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  type.label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Text(
                  'Счетчик: $lastVal ${type.unit}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Поле ввода + бейдж текущего расхода
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060912),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Center(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                      onSubmitted: (_) {
                        if (nextFocus != null) {
                          FocusScope.of(context).requestFocus(nextFocus);
                        } else {
                          focusNode.unfocus();
                        }
                      },
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d*')),
                      ],
                      style: GoogleFonts.robotoMono(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: lastVal.toString(),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.16),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildCurrentConsumptionBadge(type, breakdown),
            ],
          ),

          const SizedBox(height: 10),

          // 3. Панель помесячного расхода: Прошлый месяц vs Предпрошлый месяц
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMonthConsumptionItem(
                  label: 'Прошлый расход:',
                  value: breakdown.previousMonthConsumption != null
                      ? '${_formatVal(breakdown.previousMonthConsumption!, type.isDecimal)} ${type.unit}'
                      : '—',
                  color: const Color(0xFF38BDF8),
                ),
                Container(width: 1, height: 22, color: Colors.white10),
                _buildMonthConsumptionItem(
                  label: 'Предпрошлый:',
                  value: breakdown.prePreviousMonthConsumption != null
                      ? '${_formatVal(breakdown.prePreviousMonthConsumption!, type.isDecimal)} ${type.unit}'
                      : '—',
                  color: Colors.white60,
                ),
                if (breakdown.deltaDiff != null) ...[
                  Container(width: 1, height: 22, color: Colors.white10),
                  _buildTrendDiffChip(type, breakdown),
                ],
              ],
            ),
          ),

          if (isLowerThanPrevious) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Показание меньше предыдущего ($lastVal)!',
                    style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentConsumptionBadge(MeterType type, MeterConsumptionBreakdown breakdown) {
    final curr = breakdown.currentConsumption;
    if (curr == null) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Расход сейчас', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
            Text('— ${type.unit}', style: GoogleFonts.robotoMono(fontSize: 14, color: Colors.white24, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final currStr = _formatVal(curr, type.isDecimal);
    final color = curr >= 0 ? const Color(0xFF38BDF8) : const Color(0xFFFB7185);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Расход сейчас', style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
          Text(
            curr >= 0 ? '+$currStr ${type.unit}' : '$currStr ${type.unit}',
            style: GoogleFonts.robotoMono(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthConsumptionItem({required String label, required String value, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.45))),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildTrendDiffChip(MeterType type, MeterConsumptionBreakdown breakdown) {
    final diff = breakdown.deltaDiff ?? 0;
    final pct = breakdown.percentChange;
    final isDecreased = breakdown.isDecreased;
    final isIncreased = breakdown.isIncreased;

    Color color;
    IconData? icon;
    String text;

    if (isDecreased) {
      color = const Color(0xFF34D399);
      icon = Icons.arrow_downward_rounded;
      final diffStr = _formatVal(diff.abs(), type.isDecimal);
      final pctStr = pct != null ? ' (${pct.abs()}%)' : '';
      text = '-$diffStr$pctStr';
    } else if (isIncreased) {
      color = const Color(0xFFFB7185);
      icon = Icons.arrow_upward_rounded;
      final diffStr = _formatVal(diff.abs(), type.isDecimal);
      final pctStr = pct != null ? ' (+${pct.abs()}%)' : '';
      text = '+$diffStr$pctStr';
    } else {
      color = Colors.white54;
      text = '= 0%';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          text,
          style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16).withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isSaving
                  ? [Colors.grey.shade700, Colors.grey.shade800]
                  : [const Color(0xFF0284C7), const Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isSaving
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isSaving ? null : _saveData,
              child: Center(
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'СОХРАНИТЬ ПОКАЗАНИЯ',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHistorySheet() {
    final history = _storage.history;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timeline_rounded, color: Color(0xFF38BDF8), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'История показаний',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: history.length,
                separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.08)),
                itemBuilder: (_, index) {
                  final item = history[index];
                  final nextItem = index + 1 < history.length ? history[index + 1] : null;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.date,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildHistoryItem('Свет Д', item.lightDay, nextItem?.lightDay, 'кВт'),
                            _buildHistoryItem('Свет Н', item.lightNight, nextItem?.lightNight, 'кВт'),
                            _buildHistoryItem('Тепло', item.heating, nextItem?.heating, 'Гкал', isDecimal: true),
                            _buildHistoryItem('ГВС', item.waterHot, nextItem?.waterHot, 'м³'),
                            _buildHistoryItem('ХВС', item.waterCold, nextItem?.waterCold, 'м³'),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, num val, num? prevVal, String unit, {bool isDecimal = false}) {
    final delta = prevVal != null ? val - prevVal : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
        Text(
          _formatVal(val, isDecimal),
          style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        if (delta != null)
          Text(
            '+${_formatVal(delta, isDecimal)}',
            style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF34D399), fontWeight: FontWeight.w700),
          ),
      ],
    );
  }

  static String _formatVal(num val, bool isDecimal) {
    if (isDecimal) {
      return val.toDouble().toStringAsFixed(3);
    }
    return val.toInt().toString();
  }
}
