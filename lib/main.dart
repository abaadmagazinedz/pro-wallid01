import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:archive/archive.dart' as arc;
import 'package:archive/archive_io.dart' as arcio;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = WalidStore();
  await store.load();
  runApp(WalidApp(store: store));
}

// ============================================================
// نماذج البيانات
// ============================================================

class Student {
  String id, name, section, gender, notes;
  Student({
    required this.id,
    required this.name,
    required this.section,
    this.gender = 'ذكر',
    this.notes = '',
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'section': section,
        'gender': gender,
        'notes': notes,
      };
  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'],
        name: j['name'],
        section: j['section'],
        gender: j['gender'] ?? 'ذكر',
        notes: j['notes'] ?? '',
      );
}

class Attendance {
  String studentId, date, status;
  Attendance({
    required this.studentId,
    required this.date,
    required this.status,
  });
  Map<String, dynamic> toJson() =>
      {'studentId': studentId, 'date': date, 'status': status};
  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
        studentId: j['studentId'],
        date: j['date'],
        status: j['status'],
      );
}

class Grade {
  String studentId, activity;
  double score;
  Grade({
    required this.studentId,
    required this.activity,
    required this.score,
  });
  Map<String, dynamic> toJson() =>
      {'studentId': studentId, 'activity': activity, 'score': score};
  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
        studentId: j['studentId'],
        activity: j['activity'],
        score: (j['score'] as num).toDouble(),
      );
}

class NotebookEntry {
  String text;
  String? fileName;
  String? filePath;
  NotebookEntry({this.text = '', this.fileName, this.filePath});
  Map<String, dynamic> toJson() =>
      {'text': text, 'fileName': fileName, 'filePath': filePath};
  factory NotebookEntry.fromJson(Map<String, dynamic> j) => NotebookEntry(
        text: j['text'] ?? '',
        fileName: j['fileName'],
        filePath: j['filePath'],
      );
}


class ScheduleEntry {
  String id, day, start, end, section, activity;
  ScheduleEntry({required this.id, required this.day, required this.start, required this.end, required this.section, this.activity = ''});
  Map<String,dynamic> toJson()=>{'id':id,'day':day,'start':start,'end':end,'section':section,'activity':activity};
  factory ScheduleEntry.fromJson(Map<String,dynamic> j)=>ScheduleEntry(id:j['id'],day:j['day'],start:j['start'],end:j['end'],section:j['section'],activity:j['activity']??'');
}

class LessonRecord {
  String id, date, section, title, objective, activity, notes;
  LessonRecord({required this.id,required this.date,required this.section,required this.title, this.objective='',this.activity='',this.notes=''});
  Map<String,dynamic> toJson()=>{'id':id,'date':date,'section':section,'title':title,'objective':objective,'activity':activity,'notes':notes};
  factory LessonRecord.fromJson(Map<String,dynamic> j)=>LessonRecord(id:j['id'],date:j['date'],section:j['section'],title:j['title'],objective:j['objective']??'',activity:j['activity']??'',notes:j['notes']??'');
}

// ============================================================
// المخزن (الحفظ المحلي)
// ============================================================

class WalidStore extends ChangeNotifier {
  final sections = <String>[];
  final students = <Student>[];
  final attendance = <Attendance>[];
  final grades = <Grade>[];
  final schedule = <ScheduleEntry>[];
  final lessons = <LessonRecord>[];
  bool loaded = false;
  int _counter = 0;

  NotebookEntry yearlyProgram = NotebookEntry();
  NotebookEntry yearlyDistribution = NotebookEntry();
  NotebookEntry term1Notebook = NotebookEntry();
  NotebookEntry term2Notebook = NotebookEntry();
  NotebookEntry term3Notebook = NotebookEntry();

  NotebookEntry _loadNotebook(SharedPreferences p, String key) {
    final raw = p.getString(key);
    if (raw == null) return NotebookEntry();
    try {
      return NotebookEntry.fromJson(jsonDecode(raw));
    } catch (_) {
      return NotebookEntry();
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    sections.addAll(p.getStringList('sections') ?? []);
    students.addAll(
      (p.getStringList('students') ?? [])
          .map((x) => Student.fromJson(jsonDecode(x))),
    );
    attendance.addAll(
      (p.getStringList('attendance') ?? [])
          .map((x) => Attendance.fromJson(jsonDecode(x))),
    );
    grades.addAll(
      (p.getStringList('grades') ?? [])
          .map((x) => Grade.fromJson(jsonDecode(x))),
    );
    schedule.addAll((p.getStringList('schedule') ?? []).map((x) => ScheduleEntry.fromJson(jsonDecode(x))));
    lessons.addAll((p.getStringList('lessons') ?? []).map((x) => LessonRecord.fromJson(jsonDecode(x))));
    yearlyProgram = _loadNotebook(p, 'nb_yearlyProgram');
    yearlyDistribution = _loadNotebook(p, 'nb_yearlyDistribution');
    term1Notebook = _loadNotebook(p, 'nb_term1');
    term2Notebook = _loadNotebook(p, 'nb_term2');
    term3Notebook = _loadNotebook(p, 'nb_term3');
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('sections', sections);
    await p.setStringList(
      'students',
      students.map((x) => jsonEncode(x.toJson())).toList(),
    );
    await p.setStringList(
      'attendance',
      attendance.map((x) => jsonEncode(x.toJson())).toList(),
    );
    await p.setStringList(
      'grades',
      grades.map((x) => jsonEncode(x.toJson())).toList(),
    );
    await p.setStringList('schedule', schedule.map((x) => jsonEncode(x.toJson())).toList());
    await p.setStringList('lessons', lessons.map((x) => jsonEncode(x.toJson())).toList());
    await p.setString('nb_yearlyProgram', jsonEncode(yearlyProgram.toJson()));
    await p.setString(
      'nb_yearlyDistribution',
      jsonEncode(yearlyDistribution.toJson()),
    );
    await p.setString('nb_term1', jsonEncode(term1Notebook.toJson()));
    await p.setString('nb_term2', jsonEncode(term2Notebook.toJson()));
    await p.setString('nb_term3', jsonEncode(term3Notebook.toJson()));
    notifyListeners();
  }

  String id() {
    _counter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_counter';
  }
}

// ============================================================
// الهوية البصرية
// ============================================================

class AppColors {
  static const primary = Color(0xFF176B87);
  static const accent = Color(0xFF20A4A9);
  static const bg = Color(0xFFF5F8FA);
  static const gold = Color(0xFFF5A623);
  static const tardy = Color(0xFFE8A33D);
  static const absent = Color(0xFFE85D5D);
  static const excused = Color(0xFF5B8DEF);
  static const present = Color(0xFF2FAE6B);

  static const avatarPalette = [
    Color(0xFF176B87),
    Color(0xFF20A4A9),
    Color(0xFFE8A33D),
    Color(0xFF6C63C4),
    Color(0xFF5B8DEF),
  ];

  static Color forStatus(String status) {
    switch (status) {
      case 'حاضر':
        return present;
      case 'غائب':
        return absent;
      case 'متأخر':
        return tardy;
      case 'معذور':
        return excused;
      default:
        return Colors.grey;
    }
  }
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '؟';
  if (parts.length == 1) return parts.first.substring(0, 1);
  return parts[0].substring(0, 1) + parts[1].substring(0, 1);
}

Color avatarColorFor(String seed) {
  var sum = 0;
  for (final r in seed.runes) {
    sum += r;
  }
  return AppColors.avatarPalette[sum % AppColors.avatarPalette.length];
}

double? averageFor(WalidStore store, String studentId) {
  final g = store.grades.where((x) => x.studentId == studentId).toList();
  if (g.isEmpty) return null;
  final total = g.fold<double>(0, (sum, x) => sum + x.score);
  return total / g.length;
}

String unescapeXml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'");

String arabicDate(DateTime d) {
  const months = [
    'جانفي',
    'فيفري',
    'مارس',
    'أفريل',
    'ماي',
    'جوان',
    'جويلية',
    'أوت',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

// ============================================================
// التطبيق
// ============================================================

class WalidApp extends StatelessWidget {
  final WalidStore store;
  const WalidApp({super.key, required this.store});

  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WALID',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          scaffoldBackgroundColor: AppColors.bg,
        ),
        home: WalidHome(store: store),
      );
}

class WalidHome extends StatefulWidget {
  final WalidStore store;
  const WalidHome({super.key, required this.store});
  @override
  State<WalidHome> createState() => _WalidHomeState();
}

class _WalidHomeState extends State<WalidHome> {
  int page = 0;
  final labels = [
    'لوحة التحكم',
    'الأقسام',
    'التلاميذ',
    'الحضور',
    'التقييم',
    'الأنشطة',
    'مذكراتي',
    'التقارير',
    'الإعدادات',
    'مركز الأستاذ',
  ];
  final icons = [
    Icons.dashboard_rounded,
    Icons.school_rounded,
    Icons.groups_rounded,
    Icons.fact_check_rounded,
    Icons.assessment_rounded,
    Icons.emoji_events_rounded,
    Icons.menu_book_rounded,
    Icons.description_rounded,
    Icons.settings_rounded,
    Icons.auto_awesome_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                ),
                child: const Icon(Icons.directions_run, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WALID',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  Text(
                    'إدارة التربية البدنية والرياضية',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: page,
              labelType: NavigationRailLabelType.all,
              minWidth: 82,
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: [
                for (int i = 0; i < labels.length; i++)
                  NavigationRailDestination(
                    icon: Icon(icons[i]),
                    selectedIcon: Icon(icons[i]),
                    label: Text(labels[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (_, __) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(page),
                    child: _buildPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (page) {
      case 1:
        return SectionsPage(store: widget.store);
      case 2:
        return StudentsPage(store: widget.store);
      case 3:
        return AttendancePage(store: widget.store);
      case 4:
        return GradesPage(store: widget.store);
      case 5:
        return const ActivitiesPage();
      case 6:
        return NotebooksPage(store: widget.store);
      case 7:
        return ReportsPage(store: widget.store);
      case 8:
        return SettingsPage(store: widget.store);
      case 9:
        return TeacherToolsPage(store: widget.store);
      default:
        return Dashboard(
          store: widget.store,
          onNavigate: (p) => setState(() => page = p),
        );
    }
  }
}

// ============================================================
// لوحة التحكم
// ============================================================

class Dashboard extends StatelessWidget {
  final WalidStore store;
  final void Function(int page) onNavigate;
  const Dashboard({super.key, required this.store, required this.onNavigate});

  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                  ),
                  child: const Text(
                    'مرحبًا بك في WALID 👋\nكل أدوات التربية البدنية في مكان واحد.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.6,
                    ),
                  ),
                ),
                Positioned(top: -30, left: -30, child: _decoCircle(120, 0.10)),
                Positioned(bottom: -46, right: -20, child: _decoCircle(150, 0.08)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              Stat('الأقسام', '${store.sections.length}', Icons.school),
              Stat('التلاميذ', '${store.students.length}', Icons.groups),
              Stat(
                'الحضور اليوم',
                '${_attendancePercent(store)}%',
                Icons.fact_check,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'الوصول السريع',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Quick('إضافة تلميذ', Icons.person_add_alt_1, onTap: () => onNavigate(2)),
              Quick('تسجيل الحضور', Icons.fact_check, onTap: () => onNavigate(3)),
              Quick('إدخال تقييم', Icons.edit_note, onTap: () => onNavigate(4)),
              Quick('إنشاء تقرير', Icons.summarize, onTap: () => onNavigate(7)),
            ],
          ),
        ],
      );

  static Widget _decoCircle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  static String _attendancePercent(WalidStore s) {
    final d = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final a = s.attendance.where((x) => x.date == d).toList();
    if (a.isEmpty) return '0';
    return ((a.where((x) => x.status == 'حاضر').length / a.length) * 100)
        .round()
        .toString();
  }
}

class Stat extends StatelessWidget {
  final String a, b;
  final IconData i;
  const Stat(this.a, this.b, this.i, {super.key});

  @override
  Widget build(BuildContext c) => Container(
        width: 205,
        height: 122,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(i, color: AppColors.primary, size: 18),
            ),
            const Spacer(),
            Text(a, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            Text(b, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class Quick extends StatelessWidget {
  final String t;
  final IconData i;
  final VoidCallback? onTap;
  const Quick(this.t, this.i, {super.key, this.onTap});

  @override
  Widget build(BuildContext c) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(i, color: AppColors.primary, size: 19),
                const SizedBox(width: 10),
                Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
}

// ============================================================
// الأقسام
// ============================================================

class SectionsPage extends StatelessWidget {
  final WalidStore store;
  const SectionsPage({super.key, required this.store});

  @override
  Widget build(BuildContext c) => PageShell(
        title: 'الأقسام',
        icon: Icons.school,
        action: 'إضافة قسم',
        onAdd: () => addOrEdit(c),
        child: store.sections.isEmpty
            ? const Empty(icon: Icons.school_outlined, text: 'لا توجد أقسام بعد.')
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          AppColors.primary.withOpacity(.12),
                          Colors.white,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'كل قسم له ملف مستقل: التلاميذ، الحضور، المعدلات والتقييمات.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final section in store.sections)
                    _SectionDashboardCard(
                      store: store,
                      section: section,
                      onOpen: () => Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) => SectionDetailPage(
                            store: store,
                            section: section,
                          ),
                        ),
                      ),
                      onEdit: () => addOrEdit(c, existing: section),
                      onDelete: () => confirm(
                        c,
                        'حذف القسم "$section" وكل تلاميذه؟',
                        () {
                          store.sections.remove(section);
                          store.students.removeWhere((x) => x.section == section);
                          store.attendance.removeWhere(
                            (a) => !store.students.any((s) => s.id == a.studentId),
                          );
                          store.grades.removeWhere(
                            (g) => !store.students.any((s) => s.id == g.studentId),
                          );
                          store.save();
                        },
                      ),
                    ),
                ],
              ),
      );

  Future<void> addOrEdit(BuildContext c, {String? existing}) async {
    final x = TextEditingController(text: existing ?? '');
    await showDialog(
      context: c,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'إضافة قسم' : 'تعديل اسم القسم'),
        content: TextField(
          controller: x,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم القسم'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final v = x.text.trim().replaceAll(RegExp(r'\s+'), ' ');
              if (v.isEmpty) return;
              if (existing == null) {
                if (!store.sections.contains(v)) {
                  store.sections.add(v);
                  store.save();
                }
              } else if (v != existing && !store.sections.contains(v)) {
                final idx = store.sections.indexOf(existing);
                if (idx != -1) store.sections[idx] = v;
                for (final st in store.students) {
                  if (st.section == existing) st.section = v;
                }
                store.save();
              }
              Navigator.pop(c);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    x.dispose();
  }
}

class _SectionDashboardCard extends StatelessWidget {
  final WalidStore store;
  final String section;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SectionDashboardCard({
    required this.store,
    required this.section,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext c) {
    final students = store.students.where((s) => s.section == section).toList();
    final color = avatarColorFor(section);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int present = 0;
    for (final s in students) {
      final a = store.attendance.where((x) => x.studentId == s.id && x.date == today);
      if (a.isNotEmpty && a.first.status == 'حاضر') present++;
    }
    final avgs = students.map((s) => averageFor(store, s.id)).whereType<double>().toList();
    final avg = avgs.isEmpty ? null : avgs.reduce((a, b) => a + b) / avgs.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border(right: BorderSide(color: color, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: color.withOpacity(.12),
                    child: Icon(Icons.school_rounded, color: color, size: 27),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('${students.length} تلميذ', style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: color),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل القسم')),
                      PopupMenuItem(value: 'delete', child: Text('حذف القسم')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _MiniMetric(icon: Icons.fact_check_rounded, label: 'حاضر اليوم', value: '$present/${students.length}', color: color)),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniMetric(icon: Icons.trending_up_rounded, label: 'متوسط القسم', value: avg == null ? '—' : '${avg.toStringAsFixed(1)}/20', color: color)),
                ],
              ),
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('فتح ملف القسم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniMetric({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(.06), borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 7),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54))),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );
}

class SectionDetailPage extends StatefulWidget {
  final WalidStore store;
  final String section;
  const SectionDetailPage({super.key, required this.store, required this.section});
  @override
  State<SectionDetailPage> createState() => _SectionDetailState();
}

class _SectionDetailState extends State<SectionDetailPage> {
  String q = '';

  @override
  Widget build(BuildContext c) {
    final students = widget.store.students
        .where((s) => s.section == widget.section && s.name.contains(q))
        .toList();
    final color = avatarColorFor(widget.section);
    final allStudents = widget.store.students.where((s) => s.section == widget.section).toList();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int present = 0, absent = 0, late = 0, excused = 0;
    for (final s in allStudents) {
      final r = widget.store.attendance.where((a) => a.studentId == s.id && a.date == today);
      if (r.isEmpty) continue;
      switch (r.first.status) {
        case 'حاضر': present++; break;
        case 'غائب': absent++; break;
        case 'متأخر': late++; break;
        case 'معذور': excused++; break;
      }
    }
    final avgs = allStudents.map((s) => averageFor(widget.store, s.id)).whereType<double>().toList();
    final sectionAvg = avgs.isEmpty ? null : avgs.reduce((a, b) => a + b) / avgs.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(widget.section, style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(tooltip: 'نسخ قائمة التلاميذ', onPressed: () => _copyRoster(c, allStudents), icon: const Icon(Icons.copy_outlined)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [color, AppColors.primary]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(widget.section, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('${allStudents.length} تلميذ • ملف متابعة مستقل', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailStat('حاضر اليوم', present, AppColors.present),
                _DetailStat('غائب', absent, AppColors.absent),
                _DetailStat('متأخر', late, AppColors.tardy),
                _DetailStat('معذور', excused, AppColors.excused),
                _DetailStat('المعدل', sectionAvg == null ? '—' : sectionAvg.toStringAsFixed(1), color),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'بحث داخل القسم', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: students.isEmpty
                  ? const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('لا توجد نتائج داخل هذا القسم.')))
                  : Column(
                      children: [
                        for (int i = 0; i < students.length; i++) ...[
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: CircleAvatar(backgroundColor: avatarColorFor(students[i].name), child: Text(initials(students[i].name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            title: Text(students[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(students[i].gender + (averageFor(widget.store, students[i].id) == null ? '' : ' • ${averageFor(widget.store, students[i].id)!.toStringAsFixed(1)}/20')),
                            trailing: _todayStatus(widget.store, students[i].id, today),
                          ),
                          if (i < students.length - 1) const Divider(height: 1, indent: 72),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todayStatus(WalidStore store, String id, String date) {
    final r = store.attendance.where((a) => a.studentId == id && a.date == date);
    final status = r.isEmpty ? 'غير مسجل' : r.first.status;
    final color = AppColors.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _copyRoster(BuildContext c, List<Student> list) {
    final buffer = StringBuffer('قائمة تلاميذ: ${widget.section}\n\n');
    for (var i = 0; i < list.length; i++) buffer.writeln('${i + 1}. ${list[i].name}');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تم نسخ قائمة القسم')));
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;
  const _DetailStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(16)),
        child: Text('$label: $value', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
      );
}

// ============================================================
// التلاميذ
// ============================================================

class StudentsPage extends StatefulWidget {
  final WalidStore store;
  const StudentsPage({super.key, required this.store});
  @override
  State<StudentsPage> createState() => _StudentsState();
}

class _StudentsState extends State<StudentsPage> {
  String q = '';

  String _subtitleFor(Student s) {
    final avg = averageFor(widget.store, s.id);
    final base = '${s.section} • ${s.gender}';
    return avg == null ? base : '$base • المعدل: ${avg.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext c) {
    final filtered = widget.store.students
        .where((s) => s.name.contains(q))
        .toList();
    final grouped = <String, List<Student>>{};
    for (final section in widget.store.sections) {
      grouped[section] = filtered.where((s) => s.section == section).toList();
    }
    for (final s in filtered) {
      if (!grouped.containsKey(s.section)) grouped[s.section] = [s];
    }

    return PageShell(
      title: 'التلاميذ',
      icon: Icons.groups,
      action: 'إضافة تلميذ',
      onAdd: () => addOrEdit(c),
      extraActions: [
        OutlinedButton.icon(
          onPressed: () => importDialog(c),
          icon: const Icon(Icons.file_upload_outlined, size: 18),
          label: const Text('استيراد'),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'بحث عن تلميذ',
                border: const OutlineInputBorder(),
                suffixText: '${filtered.length} تلميذ',
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Empty(icon: Icons.person_search, text: 'لا توجد نتائج.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    children: [
                      for (final entry in grouped.entries)
                        if (entry.value.isNotEmpty)
                          _SectionStudentsCard(
                            section: entry.key,
                            students: entry.value,
                            store: widget.store,
                            onEdit: (s) => addOrEdit(c, existing: s),
                            onDelete: (s) => confirm(
                              c,
                              'حذف التلميذ "${s.name}"؟',
                              () {
                                widget.store.students.remove(s);
                                widget.store.attendance.removeWhere((a) => a.studentId == s.id);
                                widget.store.grades.removeWhere((g) => g.studentId == s.id);
                                widget.store.save();
                              },
                            ),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // إضافة / تعديل تلميذ واحد
  // ------------------------------------------------------------
  Future<void> addOrEdit(BuildContext c, {Student? existing}) async {
    if (widget.store.sections.isEmpty) {
      ScaffoldMessenger.of(c).showSnackBar(
        const SnackBar(content: Text('أضف قسمًا أولًا من صفحة الأقسام')),
      );
      return;
    }
    final n = TextEditingController(text: existing?.name ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String sec = existing?.section ?? widget.store.sections.first;
    String gender = existing?.gender ?? 'ذكر';
    await showDialog(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (c2, setD) => AlertDialog(
          title: Text(existing == null ? 'إضافة تلميذ' : 'تعديل بيانات التلميذ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: n,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'الاسم واللقب'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: sec,
                  items: widget.store.sections
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setD(() => sec = v!),
                  decoration: const InputDecoration(labelText: 'القسم'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: gender,
                  items: const [
                    DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                    DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                  ],
                  onChanged: (v) => setD(() => gender = v!),
                  decoration: const InputDecoration(labelText: 'الجنس'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c2),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final name = n.text.trim();
                if (name.isEmpty) return;
                if (existing == null) {
                  widget.store.students.add(
                    Student(
                      id: widget.store.id(),
                      name: name,
                      section: sec,
                      gender: gender,
                      notes: notesCtrl.text.trim(),
                    ),
                  );
                } else {
                  existing.name = name;
                  existing.section = sec;
                  existing.gender = gender;
                  existing.notes = notesCtrl.text.trim();
                }
                widget.store.save();
                Navigator.pop(c2);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    n.dispose();
    notesCtrl.dispose();
  }

  // ------------------------------------------------------------
  // استيراد قائمة تلاميذ (لصق نص / Excel / CSV / Word)
  // ------------------------------------------------------------
  Future<void> importDialog(BuildContext c) async {
    if (widget.store.sections.isEmpty) {
      ScaffoldMessenger.of(c).showSnackBar(
        const SnackBar(content: Text('أضف قسمًا أولًا من صفحة الأقسام')),
      );
      return;
    }
    String sec = widget.store.sections.first;
    final pasteCtrl = TextEditingController();
    bool busy = false;

    await showDialog(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (c2, setD) => AlertDialog(
          title: const Text('استيراد قائمة تلاميذ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: sec,
                  items: widget.store.sections
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setD(() => sec = v!),
                  decoration: const InputDecoration(labelText: 'القسم الافتراضي'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            setD(() => busy = true);
                            final lines = await _pickAndParseFile(c2);
                            setD(() => busy = false);
                            if (lines == null) return;
                            if (lines.isEmpty) {
                              ScaffoldMessenger.of(c2).showSnackBar(
                                const SnackBar(
                                  content: Text('لم يتم العثور على أسماء في الملف'),
                                ),
                              );
                              return;
                            }
                            final added = _applyImport(lines, sec);
                            if (context.mounted) Navigator.pop(c2);
                            ScaffoldMessenger.of(c).showSnackBar(
                              SnackBar(content: Text('تمت إضافة $added تلميذ')),
                            );
                          },
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label: Text(busy ? 'جارٍ القراءة...' : 'اختيار ملف'),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'صيغ مدعومة: Excel (xlsx)، CSV، Word (docx).\n'
                  'ضع اسم التلميذ فقط في كل سطر/صف — سيُضاف الجميع تلقائيًا '
                  'إلى القسم الذي اخترته أعلاه. لا تضف القسم أو الجنس في نفس الملف.',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const Divider(height: 30),
                const Text(
                  'أو الصق الأسماء يدويًا (اسم في كل سطر):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pasteCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'أحمد بلقاسم\nسارة مرابط\n...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c2),
              child: const Text('إغلاق'),
            ),
            FilledButton(
              onPressed: () {
                final lines = pasteCtrl.text
                    .split(RegExp(r'\r\n|\r|\n'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (lines.isEmpty) {
                  ScaffoldMessenger.of(c2).showSnackBar(
                    const SnackBar(content: Text('الصق أسماء أولًا أو اختر ملفًا')),
                  );
                  return;
                }
                final added = _applyImport(lines, sec);
                Navigator.pop(c2);
                ScaffoldMessenger.of(c).showSnackBar(
                  SnackBar(content: Text('تمت إضافة $added تلميذ')),
                );
              },
              child: const Text('استيراد من النص'),
            ),
          ],
        ),
      ),
    );
    pasteCtrl.dispose();
  }

  int _applyImport(List<String> rawLines, String defaultSection) {
    var lines = rawLines;
    if (lines.isNotEmpty) {
      final firstToken = lines.first.split(',').first.trim().toLowerCase();
      if (firstToken == 'name' || firstToken == 'الاسم') {
        lines = lines.sublist(1);
      }
    }
    var added = 0;
    for (final raw in lines) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      widget.store.students.add(
        Student(
          id: widget.store.id(),
          name: name,
          section: defaultSection,
          gender: 'ذكر',
        ),
      );
      added++;
    }
    if (added > 0) {
      widget.store.save();
      setState(() {});
    }
    return added;
  }

  Future<List<String>?> _pickAndParseFile(BuildContext dialogContext) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'docx'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      final lowerName = file.name.toLowerCase();

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        _showImportError(dialogContext, 'تعذّرت قراءة الملف');
        return null;
      }

      if (lowerName.endsWith('.csv')) {
        return _parseCsv(bytes);
      } else if (lowerName.endsWith('.xlsx')) {
        return _parseXlsx(bytes);
      } else if (lowerName.endsWith('.docx')) {
        return _parseDocx(bytes);
      }
      _showImportError(dialogContext, 'صيغة الملف غير مدعومة');
      return null;
    } catch (_) {
      _showImportError(dialogContext, 'حدث خطأ أثناء قراءة الملف');
      return null;
    }
  }

  void _showImportError(BuildContext dialogContext, String msg) {
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  List<String> _parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return text
        .split(RegExp(r'\r\n|\r|\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  List<String> _parseXlsx(Uint8List bytes) {
    final excelFile = xlsx.Excel.decodeBytes(bytes);
    final lines = <String>[];
    for (final tableName in excelFile.tables.keys) {
      final sheet = excelFile.tables[tableName];
      if (sheet == null) continue;
      for (final row in sheet.rows) {
        for (final cell in row) {
          final v = cell?.value;
          final text = v == null ? '' : v.toString().trim();
          if (text.isNotEmpty) {
            lines.add(text);
            break;
          }
        }
      }
      break;
    }
    return lines;
  }

  List<String> _parseDocx(Uint8List bytes) {
    final archive = arc.ZipDecoder().decodeBytes(bytes);
    arc.ArchiveFile? docFile;
    for (final f in archive) {
      if (f.name == 'word/document.xml') {
        docFile = f;
        break;
      }
    }
    if (docFile == null) return [];

    final content = docFile.content;
    if (content is! List<int>) return [];
    final xml = utf8.decode(content, allowMalformed: true);

    final paragraphs = xml.split('</w:p>');
    final textReg = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
    final lines = <String>[];
    for (final p in paragraphs) {
      final buffer = StringBuffer();
      for (final m in textReg.allMatches(p)) {
        buffer.write(unescapeXml(m.group(1) ?? ''));
      }
      final line = buffer.toString().trim();
      if (line.isNotEmpty) lines.add(line);
    }
    return lines;
  }
}

class _SectionStudentsCard extends StatelessWidget {
  final String section;
  final List<Student> students;
  final WalidStore store;
  final void Function(Student) onEdit;
  final void Function(Student) onDelete;
  const _SectionStudentsCard({
    required this.section,
    required this.students,
    required this.store,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sectionColor = avatarColorFor(section);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(right: BorderSide(color: sectionColor, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            decoration: BoxDecoration(color: sectionColor.withOpacity(.07), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: sectionColor.withOpacity(.15), child: Icon(Icons.school_rounded, color: sectionColor)),
                const SizedBox(width: 12),
                Expanded(child: Text(section, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: sectionColor.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text('${students.length} تلميذ', style: TextStyle(color: sectionColor, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          for (int i = 0; i < students.length; i++) ...[
            ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfilePage(store: store, student: students[i]))),
              dense: true,
              leading: CircleAvatar(backgroundColor: avatarColorFor(students[i].name), radius: 18, child: Text(initials(students[i].name), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
              title: Text(students[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(students[i].gender + (averageFor(store, students[i].id) == null ? '' : ' • المعدل ${averageFor(store, students[i].id)!.toStringAsFixed(1)}/20')),
              trailing: rowMenu(onEdit: () => onEdit(students[i]), onDelete: () => onDelete(students[i])),
            ),
            if (i < students.length - 1) const Divider(height: 1, indent: 60),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// الحضور والغياب
// ============================================================

class AttendancePage extends StatefulWidget {
  final WalidStore store;
  const AttendancePage({super.key, required this.store});
  @override
  State<AttendancePage> createState() => _AttendanceState();
}

class _AttendanceState extends State<AttendancePage> {
  DateTime selectedDate = DateTime.now();
  String get dateKey => DateFormat('yyyy-MM-dd').format(selectedDate);

  @override
  Widget build(BuildContext c) {
    final grouped = <String, List<Student>>{};
    for (final section in widget.store.sections) {
      final list = widget.store.students.where((s) => s.section == section).toList();
      if (list.isNotEmpty) grouped[section] = list;
    }
    for (final s in widget.store.students) {
      grouped.putIfAbsent(s.section, () => []).add(s);
    }
    // منع التكرار للأقسام الموجودة مسبقًا.
    for (final key in grouped.keys.toList()) {
      final seen = <String>{};
      grouped[key] = grouped[key]!.where((s) => seen.add(s.id)).toList();
    }

    return PageShell(
      title: 'الحضور والغياب',
      icon: Icons.fact_check,
      action: 'حفظ الحضور',
      onAdd: save,
      extraActions: [
        OutlinedButton.icon(onPressed: copySheet, icon: const Icon(Icons.copy_outlined, size: 18), label: const Text('نسخ الكشف')),
      ],
      child: Column(
        children: [
          _dateBar(),
          _attendanceSummary(grouped.values.expand((x) => x)),
          Expanded(
            child: widget.store.students.isEmpty
                ? const Empty(icon: Icons.groups_outlined, text: 'أضف تلاميذ أولًا.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    children: [
                      for (final entry in grouped.entries)
                        _AttendanceSectionCard(store: widget.store, section: entry.key, students: entry.value, date: dateKey),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceSummary(Iterable<Student> students) {
    final list = students.toList();
    int present = 0, absent = 0, late = 0, excused = 0;
    for (final s in list) {
      final r = widget.store.attendance.where((a) => a.studentId == s.id && a.date == dateKey);
      final st = r.isEmpty ? 'غير مسجل' : r.first.status;
      if (st == 'حاضر') present++; else if (st == 'غائب') absent++; else if (st == 'متأخر') late++; else if (st == 'معذور') excused++;
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Wrap(spacing: 10, runSpacing: 8, children: [
        _StatusChip('حاضر', present, AppColors.present), _StatusChip('غائب', absent, AppColors.absent),
        _StatusChip('متأخر', late, AppColors.tardy), _StatusChip('معذور', excused, AppColors.excused),
        _StatusChip('غير مسجل', list.length - present - absent - late - excused, Colors.grey),
      ]),
    );
  }

  Widget _dateBar() {
    final base = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    const days = ['الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Row(children: [
          IconButton(tooltip:'اليوم السابق', icon:const Icon(Icons.chevron_right), onPressed:()=>setState(()=>selectedDate=selectedDate.subtract(const Duration(days:1)))),
          Expanded(child: InkWell(onTap:pickDate, borderRadius:BorderRadius.circular(12), child: Padding(padding:const EdgeInsets.symmetric(vertical:8), child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.calendar_month_rounded,size:18,color:AppColors.primary),const SizedBox(width:8),Text(arabicDate(selectedDate),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16))])))),
          IconButton(tooltip:'اليوم التالي', icon:const Icon(Icons.chevron_left), onPressed:()=>setState(()=>selectedDate=selectedDate.add(const Duration(days:1)))),
        ]),
        const SizedBox(height:4),
        SizedBox(height:72, child: Row(children:[for(int i=0;i<7;i++) Expanded(child: _AgendaDay(label:days[i], date:base.add(Duration(days:i)), selected:selectedDate, onTap:(d)=>setState(()=>selectedDate=d))) ])),
        const SizedBox(height:4),
        OutlinedButton.icon(onPressed:()=>setState(()=>selectedDate=DateTime.now()), icon:const Icon(Icons.today,size:17), label:const Text('العودة إلى اليوم')),
      ]),
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void save() {
    widget.store.save();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الحضور بنجاح')),
    );
  }

  void copySheet() {
    final buffer = StringBuffer('كشف الحضور — ${arabicDate(selectedDate)}\n\n');
    for (final s in widget.store.students) {
      final rec = widget.store.attendance.where(
        (x) => x.studentId == s.id && x.date == dateKey,
      );
      final status = rec.isNotEmpty ? rec.first.status : 'غير مسجل';
      buffer.writeln('${s.name} — $status');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ كشف الحضور — يمكنك لصقه في أي مستند للطباعة')),
    );
  }
}

class _AgendaDay extends StatelessWidget {
  final String label; final DateTime date; final DateTime selected; final ValueChanged<DateTime> onTap;
  const _AgendaDay({required this.label,required this.date,required this.selected,required this.onTap});
  @override
  Widget build(BuildContext c){ final active=DateUtils.isSameDay(date,selected); return InkWell(onTap:()=>onTap(date),borderRadius:BorderRadius.circular(14),child:Container(margin:const EdgeInsets.symmetric(horizontal:2),padding:const EdgeInsets.symmetric(vertical:6),decoration:BoxDecoration(color:active?AppColors.primary.withOpacity(.12):Colors.transparent,borderRadius:BorderRadius.circular(14),border:Border.all(color:active?AppColors.primary:Colors.transparent)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(label.substring(0,3),style:TextStyle(fontSize:11,color:active?AppColors.primary:Colors.black54,fontWeight:FontWeight.bold)),const SizedBox(height:4),Text('${date.day}',style:TextStyle(fontSize:18,color:active?AppColors.primary:Colors.black87,fontWeight:FontWeight.w900)),Text('${date.month}',style:TextStyle(fontSize:10,color:active?AppColors.primary:Colors.black45))]))); }
}

class _StatusChip extends StatelessWidget {
  final String label; final int value; final Color color;
  const _StatusChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(20)), child: Text('$label: $value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)));
}

class _AttendanceSectionCard extends StatelessWidget {
  final WalidStore store; final String section; final List<Student> students; final String date;
  const _AttendanceSectionCard({required this.store, required this.section, required this.students, required this.date});
  @override
  Widget build(BuildContext c) {
    final color = avatarColorFor(section);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border(right: BorderSide(color: color, width: 5))),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: color.withOpacity(.07), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Row(children: [Icon(Icons.school_rounded, color: color), const SizedBox(width: 10), Expanded(child: Text(section, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))), Text('${students.length} تلميذ', style: TextStyle(color: color, fontWeight: FontWeight.bold))])),
        for (int i=0;i<students.length;i++) _AttendanceRow(key: ValueKey('${students[i].id}_$date'), store: store, student: students[i], date: date),
      ]),
    );
  }
}

class _AttendanceRow extends StatefulWidget {
  final WalidStore store;
  final Student student;
  final String date;
  const _AttendanceRow({
    super.key,
    required this.store,
    required this.student,
    required this.date,
  });
  @override
  State<_AttendanceRow> createState() => _AttendanceRowState();
}

class _AttendanceRowState extends State<_AttendanceRow> {
  String status = 'غير مسجل';

  @override
  void initState() {
    super.initState();
    final a = widget.store.attendance.where(
      (x) => x.studentId == widget.student.id && x.date == widget.date,
    );
    if (a.isNotEmpty) status = a.first.status;
  }

  @override
  Widget build(BuildContext c) {
    final color = AppColors.forStatus(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarColorFor(widget.student.name),
          child: Text(
            initials(widget.student.name),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(widget.student.name),
        subtitle: Text(widget.student.section),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: status,
              icon: Icon(Icons.expand_more, color: color, size: 18),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              dropdownColor: Colors.white,
              items: const ['غير مسجل', 'حاضر', 'غائب', 'متأخر', 'معذور']
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (v) {
                setState(() => status = v!);
                widget.store.attendance.removeWhere(
                  (x) =>
                      x.studentId == widget.student.id &&
                      x.date == widget.date,
                );
                if (status != 'غير مسجل') {
                  widget.store.attendance.add(
                    Attendance(
                      studentId: widget.student.id,
                      date: widget.date,
                      status: status,
                    ),
                  );
                }
                widget.store.save();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// التقييم والنقاط
// ============================================================

class GradesPage extends StatefulWidget {
  final WalidStore store;
  const GradesPage({super.key, required this.store});
  @override
  State<GradesPage> createState() => _GradesState();
}

class _GradesState extends State<GradesPage> {
  @override
  Widget build(BuildContext c) => PageShell(
        title: 'التقييم والنقاط',
        icon: Icons.assessment,
        action: 'إضافة تقييم',
        onAdd: () => addOrEdit(c),
        child: widget.store.grades.isEmpty
            ? const Empty(icon: Icons.assessment_outlined, text: 'لا توجد تقييمات بعد.')
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final g in widget.store.grades)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: avatarColorFor(_name(g.studentId)),
                          child: Text(
                            initials(_name(g.studentId)),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          _name(g.studentId),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(g.activity),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (g.score >= 16)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.emoji_events_rounded,
                                  color: AppColors.gold,
                                  size: 20,
                                ),
                              ),
                            Text(
                              '${g.score.toStringAsFixed(1)}/20',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            rowMenu(
                              onEdit: () => addOrEdit(c, existing: g),
                              onDelete: () => confirm(
                                c,
                                'حذف هذا التقييم؟',
                                () {
                                  widget.store.grades.remove(g);
                                  widget.store.save();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      );

  String _name(String id) => widget.store.students
      .firstWhere(
        (s) => s.id == id,
        orElse: () => Student(id: '', name: 'غير معروف', section: ''),
      )
      .name;

  Future<void> addOrEdit(BuildContext c, {Grade? existing}) async {
    if (widget.store.students.isEmpty) {
      ScaffoldMessenger.of(c).showSnackBar(
        const SnackBar(content: Text('أضف تلاميذ أولًا')),
      );
      return;
    }
    final presetTitles = ActivitiesPage.activities.map((a) => a.title).toList();
    String st = existing?.studentId ?? widget.store.students.first.id;
    String actChoice =
        (existing != null && !presetTitles.contains(existing.activity))
            ? 'أخرى'
            : (existing?.activity ?? presetTitles.first);
    final customCtrl = TextEditingController(
      text: (existing != null && !presetTitles.contains(existing.activity))
          ? existing.activity
          : '',
    );
    final score = TextEditingController(
      text: existing == null ? '' : existing.score.toString(),
    );
    await showDialog(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (c2, setD) => AlertDialog(
          title: Text(existing == null ? 'إضافة تقييم' : 'تعديل التقييم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: st,
                items: widget.store.students
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setD(() => st = v!),
                decoration: const InputDecoration(labelText: 'التلميذ'),
              ),
              TextField(
                controller: score,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'النقطة / 20'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: actChoice,
                items: [
                  for (final a in ActivitiesPage.activities)
                    DropdownMenuItem(
                      value: a.title,
                      child: Text('${a.title} (${a.term})'),
                    ),
                  const DropdownMenuItem(value: 'أخرى', child: Text('نشاط آخر...')),
                ],
                onChanged: (v) => setD(() => actChoice = v!),
                decoration: const InputDecoration(labelText: 'النشاط'),
              ),
              if (actChoice == 'أخرى') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: customCtrl,
                  decoration: const InputDecoration(labelText: 'اسم النشاط'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c2),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final x = double.tryParse(score.text);
                final actText =
                    actChoice == 'أخرى' ? customCtrl.text.trim() : actChoice;
                if (x == null || x < 0 || x > 20 || actText.isEmpty) return;
                if (existing == null) {
                  widget.store.grades.add(
                    Grade(studentId: st, activity: actText, score: x),
                  );
                } else {
                  existing.studentId = st;
                  existing.activity = actText;
                  existing.score = x;
                }
                widget.store.save();
                Navigator.pop(c2);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    score.dispose();
    customCtrl.dispose();
  }
}

// ============================================================
// الأنشطة
// ============================================================

class ActivityInfo {
  final String term, title;
  final IconData icon;
  const ActivityInfo(this.term, this.title, this.icon);
}

class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  static const activities = [
    ActivityInfo('الفصل الأول', 'كرة اليد مع السرعة', Icons.sports_handball),
    ActivityInfo('الفصل الثاني', 'كرة السلة مع دفع الجلة', Icons.sports_basketball),
    ActivityInfo('الفصل الثالث', 'كرة الطائرة مع القفز الطويل', Icons.sports_volleyball),
  ];

  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'الأنشطة الرياضية',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'البرنامج السنوي موزّع على الفصول الثلاثة',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          for (final a in activities)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(a.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.term,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          a.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}

// ============================================================
// مذكراتي
// ============================================================

class NotebooksPage extends StatefulWidget {
  final WalidStore store;
  const NotebooksPage({super.key, required this.store});
  @override
  State<NotebooksPage> createState() => _NotebooksState();
}

class _NotebooksState extends State<NotebooksPage> {
  int tab = 0;
  bool busy = false;
  final labels = [
    'البرنامج السنوي',
    'التوزيع السنوي',
    'الفصل الأول',
    'الفصل الثاني',
    'الفصل الثالث',
  ];
  late final List<TextEditingController> controllers;

  List<NotebookEntry> get _entries => [
        widget.store.yearlyProgram,
        widget.store.yearlyDistribution,
        widget.store.term1Notebook,
        widget.store.term2Notebook,
        widget.store.term3Notebook,
      ];

  void _setEntry(int i, NotebookEntry e) {
    switch (i) {
      case 0:
        widget.store.yearlyProgram = e;
        break;
      case 1:
        widget.store.yearlyDistribution = e;
        break;
      case 2:
        widget.store.term1Notebook = e;
        break;
      case 3:
        widget.store.term2Notebook = e;
        break;
      case 4:
        widget.store.term3Notebook = e;
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    controllers = [for (final e in _entries) TextEditingController(text: e.text)];
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    for (var i = 0; i < labels.length; i++) {
      final current = _entries[i];
      _setEntry(
        i,
        NotebookEntry(
          text: controllers[i].text,
          fileName: current.fileName,
          filePath: current.filePath,
        ),
      );
    }
    widget.store.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ')),
      );
    }
  }

  Future<void> _attachFile(int i) async {
    setState(() => busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null) {
        _toast('تعذّرت قراءة الملف');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'pdf';
      final savePath = '${dir.path}/notebook_$i.$ext';
      await File(savePath).writeAsBytes(bytes);
      setState(() {
        _setEntry(
          i,
          NotebookEntry(
            text: _entries[i].text,
            fileName: picked.name,
            filePath: savePath,
          ),
        );
      });
      widget.store.save();
      _toast('تم إرفاق الملف بنجاح');
    } catch (_) {
      _toast('حدث خطأ أثناء إرفاق الملف');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openFile(int i) async {
    final path = _entries[i].filePath;
    if (path == null) return;
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      _toast('تعذّر فتح الملف: ${result.message}');
    }
  }

  void _removeFile(int i) {
    final path = _entries[i].filePath;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _setEntry(i, NotebookEntry(text: _entries[i].text));
    });
    widget.store.save();
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext c) {
    final entry = _entries[tab];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'مذكراتي',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (int i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(labels[i]),
                    selected: tab == i,
                    onSelected: (_) => setState(() => tab = i),
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: tab == i ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _attachFile(tab),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file, size: 18),
                  label: Text(
                    entry.fileName == null
                        ? 'إرفاق ملف Word / PDF'
                        : 'استبدال الملف المرفق',
                  ),
                ),
                if (entry.fileName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE7ECEF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.fileName!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openFile(tab),
                          child: const Text('فتح'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeFile(tab),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    key: ValueKey(tab),
                    controller: controllers[tab],
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: 'اكتب أو الصق ملاحظات إضافية هنا (اختياري)...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// التقارير
// ============================================================

class ReportsPage extends StatelessWidget {
  final WalidStore store;
  const ReportsPage({super.key, required this.store});

  List<MapEntry<Student, double>> get _ranked {
    final entries = <MapEntry<Student, double>>[];
    for (final s in store.students) {
      final avg = averageFor(store, s.id);
      if (avg != null) entries.add(MapEntry(s, avg));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'التقارير',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          _reportCard(
            Icons.groups,
            'تقرير التلاميذ',
            '${store.students.length} تلميذ في ${store.sections.length} قسم',
          ),
          _reportCard(
            Icons.assessment,
            'ملخص التقييمات',
            '${store.grades.length} تقييم مسجل',
          ),
          _reportCard(
            Icons.fact_check,
            'ملخص الحضور',
            '${store.attendance.length} سجل حضور',
          ),
          if (_ranked.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'معدلات التلاميذ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copySheet(c),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('نسخ الكشف'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in _ranked)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: avatarColorFor(e.key.name),
                    child: Text(
                      initials(e.key.name),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(e.key.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(e.key.section),
                  trailing: Text(
                    e.value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ],
      );

  void _copySheet(BuildContext c) {
    final buffer = StringBuffer('كشف معدلات التلاميذ — WALID\n\n');
    for (final e in _ranked) {
      buffer.writeln('${e.key.name} (${e.key.section}) — ${e.value.toStringAsFixed(1)}/20');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(c).showSnackBar(
      const SnackBar(content: Text('تم نسخ الكشف — يمكنك لصقه في أي مستند للطباعة')),
    );
  }

  Widget _reportCard(IconData icon, String title, String subtitle) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
        ),
      );
}


// ============================================================
// مركز الأستاذ — v14
// ============================================================

class TeacherToolsPage extends StatelessWidget {
  final WalidStore store;
  const TeacherToolsPage({super.key, required this.store});
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const Text('مركز الأستاذ', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('أدوات يومية متكاملة تساعدك على التخطيط والمتابعة والتحليل.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 18),
      Wrap(spacing:12,runSpacing:12,children:[
        _ToolCard(Icons.person_search,'ملف التلميذ الذكي','الحضور والتقييمات والملاحظات',()=>_push(c,StudentDirectoryPage(store:store))),
        _ToolCard(Icons.calendar_month,'أجندة الأستاذ','الجدول الأسبوعي والحصص',()=>_push(c,TeacherAgendaPage(store:store))),
        _ToolCard(Icons.directions_run,'سجل الحصص','وثّق كل حصة وهدفها وأنشطتها',()=>_push(c,LessonLogPage(store:store))),
        _ToolCard(Icons.bar_chart,'الإحصائيات','مؤشرات الأقسام والتلاميذ والحضور',()=>_push(c,StatisticsPage(store:store))),
        _ToolCard(Icons.picture_as_pdf,'التقارير PDF','أنشئ تقريرًا جاهزًا للطباعة',()=>_push(c,PdfReportsPage(store:store))),
        _ToolCard(Icons.library_books,'مكتبة المذكرات','برامجك ومذكراتك وملفاتك في مكان واحد',()=>_push(c,NotebookLibraryPage(store:store))),
        _ToolCard(Icons.auto_awesome,'المساعد الذكي','مولّد مقترح لحصة التربية البدنية',()=>_push(c,AiAssistantPage(store:store))),
        _ToolCard(Icons.backup_outlined,'نسخة احتياطية واسترجاع','احفظ كل بياناتك أو استعدها',()=>_push(c,BackupRestorePage(store:store))),
      ]),
    ],
  );
  static void _push(BuildContext c, Widget w)=>Navigator.push(c,MaterialPageRoute(builder:(_)=>w));
}

class _ToolCard extends StatelessWidget {
  final IconData icon; final String title,sub; final VoidCallback onTap;
  const _ToolCard(this.icon,this.title,this.sub,this.onTap);
  @override Widget build(BuildContext c)=>SizedBox(width:280,child:Card(elevation:0,child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:AppColors.primary.withOpacity(.10),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:AppColors.primary)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(sub,style:const TextStyle(fontSize:11,color:Colors.black54))])),const Icon(Icons.chevron_left)])))));
}

class StudentDirectoryPage extends StatelessWidget {
  final WalidStore store; const StudentDirectoryPage({super.key,required this.store});
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('ملف التلميذ الذكي')),body:ListView(padding:const EdgeInsets.all(14),children:[
    const Text('اختر تلميذًا لفتح ملفه الكامل',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:10),
    for(final s in store.students) Card(child:ListTile(onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>StudentProfilePage(store:store,student:s))),leading:CircleAvatar(backgroundColor:avatarColorFor(s.name),child:Text(initials(s.name),style:const TextStyle(color:Colors.white))),title:Text(s.name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${s.section} • ${s.gender}'),trailing:const Icon(Icons.chevron_left))),
    if(store.students.isEmpty) const Empty(text:'أضف التلاميذ أولًا.'),
  ]));
}

class StudentProfilePage extends StatelessWidget {
  final WalidStore store; final Student student;
  const StudentProfilePage({super.key,required this.store,required this.student});
  @override Widget build(BuildContext c){
    final gs=store.grades.where((g)=>g.studentId==student.id).toList();
    final at=store.attendance.where((a)=>a.studentId==student.id).toList();
    final avg=averageFor(store,student.id);
    final present=at.where((a)=>a.status=='حاضر').length;
    final absent=at.where((a)=>a.status=='غائب').length;
    return Scaffold(appBar:AppBar(title:const Text('ملف التلميذ')),body:ListView(padding:const EdgeInsets.all(14),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppColors.primary,AppColors.accent]),borderRadius:BorderRadius.circular(24)),child:Row(children:[CircleAvatar(radius:30,backgroundColor:Colors.white24,child:Text(initials(student.name),style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900))),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(student.name,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),Text('${student.section} • ${student.gender}',style:const TextStyle(color:Colors.white70))]))])),
      const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[_DetailStat('المعدل',avg==null?'—':avg.toStringAsFixed(1),AppColors.primary),_DetailStat('حاضر',present,AppColors.present),_DetailStat('غائب',absent,AppColors.absent),_DetailStat('التقييمات',gs.length,AppColors.accent)]),
      const SizedBox(height:14),_ProfileBlock(title:'الملاحظات',icon:Icons.notes,child:Text(student.notes.isEmpty?'لا توجد ملاحظات.':student.notes)),
      _ProfileBlock(title:'التقييمات',icon:Icons.assessment,child:gs.isEmpty?const Text('لا توجد تقييمات بعد.'):Column(children:[for(final g in gs)ListTile(contentPadding:EdgeInsets.zero,title:Text(g.activity),trailing:Text('${g.score.toStringAsFixed(1)}/20',style:const TextStyle(fontWeight:FontWeight.w900))) ])),
      _ProfileBlock(title:'سجل الحضور',icon:Icons.fact_check,child:at.isEmpty?const Text('لا يوجد سجل حضور.'):Column(children:[for(final a in at.reversed.take(20))ListTile(contentPadding:EdgeInsets.zero,title:Text(a.date),trailing:Text(a.status,style:TextStyle(color:AppColors.forStatus(a.status),fontWeight:FontWeight.bold)))])),
      FilledButton.icon(onPressed:(){final b=StringBuffer('ملف التلميذ: ${student.name}\nالقسم: ${student.section}\nالمعدل: ${avg?.toStringAsFixed(1)??'—'}/20\nحاضر: $present\nغائب: $absent\n\nملاحظات: ${student.notes}');Clipboard.setData(ClipboardData(text:b.toString()));ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('تم نسخ ملف التلميذ')));},icon:const Icon(Icons.copy),label:const Text('نسخ ملخص الملف'))
    ]));
  }
}
class _ProfileBlock extends StatelessWidget {final String title;final IconData icon;final Widget child;const _ProfileBlock({required this.title,required this.icon,required this.child});@override Widget build(BuildContext c)=>Card(elevation:0,margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:AppColors.primary),const SizedBox(width:8),Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16))]),const Divider(),child])));}

class TeacherAgendaPage extends StatefulWidget {final WalidStore store;const TeacherAgendaPage({super.key,required this.store});@override State<TeacherAgendaPage> createState()=>_TeacherAgendaState();}
class _TeacherAgendaState extends State<TeacherAgendaPage> {
  final days = ['الأحد','الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];

  @override
  Widget build(BuildContext c) {
    final grouped = <String, List<ScheduleEntry>>{};
    for (final d in days) {
      grouped[d] = widget.store.schedule.where((x) => x.day == d).toList();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('أجندة الأستاذ'),
        actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          for (final d in days)
            if (grouped[d]!.isNotEmpty)
              Card(
                elevation: 0,
                child: ExpansionTile(
                  title: Text(d, style: const TextStyle(fontWeight: FontWeight.w900)),
                  children: [
                    for (final e in grouped[d]!)
                      ListTile(
                        title: Text('${e.start} – ${e.end}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${e.section}${e.activity.isEmpty ? '' : ' • ${e.activity}'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.absent),
                          onPressed: () {
                            widget.store.schedule.remove(e);
                            widget.store.save();
                            setState(() {});
                          },
                        ),
                      ),
                  ],
                ),
              ),
          if (widget.store.schedule.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text('أضف حصصك الأسبوعية لتظهر هنا.')),
            ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    if (widget.store.sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف قسمًا أولًا.')));
      return;
    }
    String day = days.first;
    String sec = widget.store.sections.first;
    final st = TextEditingController(text: '08:00');
    final en = TextEditingController(text: '09:00');
    final act = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة حصة'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: day,
                  items: days.map((d) => DropdownMenuItem<String>(value: d, child: Text(d))).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => day = v); },
                  decoration: const InputDecoration(labelText: 'اليوم'),
                ),
                DropdownButtonFormField<String>(
                  value: sec,
                  items: widget.store.sections.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                  onChanged: (v) { if (v != null) setDialogState(() => sec = v); },
                  decoration: const InputDecoration(labelText: 'القسم'),
                ),
                TextField(controller: st, decoration: const InputDecoration(labelText: 'من')),
                TextField(controller: en, decoration: const InputDecoration(labelText: 'إلى')),
                TextField(controller: act, decoration: const InputDecoration(labelText: 'النشاط/الهدف')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                widget.store.schedule.add(ScheduleEntry(
                  id: widget.store.id(),
                  day: day,
                  start: st.text.trim(),
                  end: en.text.trim(),
                  section: sec,
                  activity: act.text.trim(),
                ));
                widget.store.save();
                Navigator.pop(dialogContext);
                setState(() {});
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    st.dispose();
    en.dispose();
    act.dispose();
  }
}

class LessonLogPage extends StatefulWidget {
  final WalidStore store;
  const LessonLogPage({super.key, required this.store});
  @override State<LessonLogPage> createState() => _LessonLogState();
}

class _LessonLogState extends State<LessonLogPage> {
  @override
  Widget build(BuildContext c) {
    final lessons = widget.store.lessons.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الحصص'), actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add))]),
      body: lessons.isEmpty
          ? const Empty(text: 'لم تسجل أي حصة بعد.')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lessons.length,
              itemBuilder: (_, i) {
                final l = lessons[i];
                return Card(
                  elevation: 0,
                  child: ListTile(
                    title: Text(l.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${l.date} • ${l.section}\n${l.objective.isEmpty ? '' : l.objective}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.absent),
                      onPressed: () {
                        widget.store.lessons.remove(l);
                        widget.store.save();
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _add() async {
    if (widget.store.sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف قسمًا أولًا.')));
      return;
    }
    final title = TextEditingController();
    final obj = TextEditingController();
    final act = TextEditingController();
    final notes = TextEditingController();
    String sec = widget.store.sections.first;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل حصة'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الحصة')),
              DropdownButtonFormField<String>(
                value: sec,
                items: widget.store.sections.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                onChanged: (v) { if (v != null) sec = v; },
                decoration: const InputDecoration(labelText: 'القسم'),
              ),
              TextField(controller: obj, decoration: const InputDecoration(labelText: 'الهدف')),
              TextField(controller: act, maxLines: 3, decoration: const InputDecoration(labelText: 'النشاط والتطبيق')),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              widget.store.lessons.add(LessonRecord(
                id: widget.store.id(), date: date, section: sec,
                title: title.text.trim(), objective: obj.text.trim(),
                activity: act.text.trim(), notes: notes.text.trim(),
              ));
              widget.store.save();
              Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    title.dispose(); obj.dispose(); act.dispose(); notes.dispose();
  }
}

class StatisticsPage extends StatelessWidget{final WalidStore store;const StatisticsPage({super.key,required this.store});@override Widget build(BuildContext c){final today=DateFormat('yyyy-MM-dd').format(DateTime.now());final records=store.attendance.where((a)=>a.date==today).toList();final avgAll=_allAvg();return Scaffold(appBar:AppBar(title:const Text('الإحصائيات')),body:ListView(padding:const EdgeInsets.all(14),children:[Wrap(spacing:8,runSpacing:8,children:[_DetailStat('التلاميذ',store.students.length,AppColors.primary),_DetailStat('الأقسام',store.sections.length,AppColors.accent),_DetailStat('حاضر اليوم',records.where((a)=>a.status=='حاضر').length,AppColors.present),_DetailStat('غائب اليوم',records.where((a)=>a.status=='غائب').length,AppColors.absent),_DetailStat('المعدل العام',avgAll==null?'—':avgAll.toStringAsFixed(1),AppColors.gold)]),const SizedBox(height:18),const Text('معدل كل قسم',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),for(final sec in store.sections)_bar(sec),const SizedBox(height:18),const Text('توزيع الحضور اليوم',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),_statusBars(records)]));}
  double? _allAvg(){final a=store.students.map((s)=>averageFor(store,s.id)).whereType<double>().toList();return a.isEmpty?null:a.reduce((x,y)=>x+y)/a.length;}
  Widget _bar(String sec){final a=store.students.where((s)=>s.section==sec).map((s)=>averageFor(store,s.id)).whereType<double>().toList();final v=a.isEmpty?0:a.reduce((x,y)=>x+y)/a.length;return Padding(padding:const EdgeInsets.only(bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(sec)),Text(v==0?'—':v.toStringAsFixed(1))]),const SizedBox(height:4),LinearProgressIndicator(value:v/20,minHeight:8,borderRadius:BorderRadius.circular(8))]));}
  Widget _statusBars(List<Attendance> r){final counts={for(final s in ['حاضر','غائب','متأخر','معذور'])s:r.where((x)=>x.status==s).length};final total=r.length==0?1:r.length;return Column(children:[for(final e in counts.entries)Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[SizedBox(width:55,child:Text(e.key)),Expanded(child:LinearProgressIndicator(value:e.value/total,minHeight:8,borderRadius:BorderRadius.circular(8))),const SizedBox(width:8),Text('${e.value}')]))]);}
}

class PdfReportsPage extends StatelessWidget {
  final WalidStore store;
  const PdfReportsPage({super.key, required this.store});

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('التقارير PDF')),
    body: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(elevation: 0, child: ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
          title: const Text('تقرير عام للتلاميذ'),
          subtitle: Text('${store.students.length} تلميذ • ${store.sections.length} قسم'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _make(c, 'تقرير WALID العام'),
        )),
        Card(elevation: 0, child: ListTile(
          leading: const Icon(Icons.groups, color: AppColors.primary),
          title: const Text('كشف المعدلات'),
          subtitle: const Text('ترتيب التلاميذ حسب المعدل'),
          onTap: () => _make(c, 'كشف معدلات التلاميذ'),
        )),
        Card(elevation: 0, child: ListTile(
          leading: const Icon(Icons.fact_check, color: AppColors.primary),
          title: const Text('تقرير الحضور'),
          subtitle: const Text('ملخص سجلات الحضور والغياب'),
          onTap: () => _make(c, 'تقرير الحضور'),
        )),
      ],
    ),
  );

  Future<void> _make(BuildContext c, String title) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Text(title),
          pw.SizedBox(height: 12),
          pw.Text('WALID — إدارة التربية البدنية والرياضية'),
          pw.SizedBox(height: 12),
          ...store.students.map((s) {
            final a = averageFor(store, s.id);
            final at = store.attendance.where((x) => x.studentId == s.id).toList();
            return pw.Text('${s.name} | ${s.section} | المعدل ${a?.toStringAsFixed(1) ?? '—'}/20 | حاضر ${at.where((x) => x.status == 'حاضر').length} | غائب ${at.where((x) => x.status == 'غائب').length}');
          }),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}

class NotebookLibraryPage extends StatelessWidget{final WalidStore store;const NotebookLibraryPage({super.key,required this.store});@override Widget build(BuildContext c){final items=[['البرنامج السنوي',store.yearlyProgram],['التوزيع السنوي',store.yearlyDistribution],['الفصل الأول',store.term1Notebook],['الفصل الثاني',store.term2Notebook],['الفصل الثالث',store.term3Notebook]];return Scaffold(appBar:AppBar(title:const Text('مكتبة المذكرات')),body:ListView(padding:const EdgeInsets.all(14),children:[const Text('مكتبتك الشخصية للبرامج والمذكرات والملفات المرفقة.',style:TextStyle(color:Colors.black54)),const SizedBox(height:10),for(final x in items)Card(elevation:0,child:ListTile(leading:const Icon(Icons.menu_book,color:AppColors.primary),title:Text(x[0] as String,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text((x[1] as NotebookEntry).fileName??'ملاحظات نصية فقط'),trailing:const Icon(Icons.chevron_left),onTap:(){final e=x[1] as NotebookEntry;final text=e.text.isEmpty?'لا توجد ملاحظات.':e.text;showDialog(context:c,builder:(_)=>AlertDialog(title:Text(x[0] as String),content:SingleChildScrollView(child:Text(text)),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('إغلاق')),TextButton(onPressed:(){Clipboard.setData(ClipboardData(text:text));Navigator.pop(c);},child:const Text('نسخ'))]));}))]));}}

// ============================================================
// نسخة احتياطية واسترجاع
// ============================================================

class BackupRestorePage extends StatefulWidget {
  final WalidStore store;
  const BackupRestorePage({super.key, required this.store});
  @override
  State<BackupRestorePage> createState() => _BackupRestoreState();
}

class _BackupRestoreState extends State<BackupRestorePage> {
  bool busy = false;

  List<NotebookEntry> get _notebooks => [
        widget.store.yearlyProgram,
        widget.store.yearlyDistribution,
        widget.store.term1Notebook,
        widget.store.term2Notebook,
        widget.store.term3Notebook,
      ];

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _export() async {
    setState(() => busy = true);
    String? tempJsonPath;
    try {
      final data = {
        'sections': widget.store.sections,
        'students': widget.store.students.map((x) => x.toJson()).toList(),
        'attendance': widget.store.attendance.map((x) => x.toJson()).toList(),
        'grades': widget.store.grades.map((x) => x.toJson()).toList(),
        'schedule': widget.store.schedule.map((x) => x.toJson()).toList(),
        'lessons': widget.store.lessons.map((x) => x.toJson()).toList(),
        'notebooks': {
          for (var i = 0; i < _notebooks.length; i++)
            'n$i': {'text': _notebooks[i].text, 'fileName': _notebooks[i].fileName},
        },
      };

      final dir = await getApplicationDocumentsDirectory();
      tempJsonPath = '${dir.path}/_walid_export_data.json';
      await File(tempJsonPath).writeAsString(jsonEncode(data));

      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final zipPath = '${dir.path}/WALID_backup_$stamp.zip';

      final encoder = arcio.ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addFile(File(tempJsonPath), 'data.json');
      for (var i = 0; i < _notebooks.length; i++) {
        final path = _notebooks[i].filePath;
        if (path != null && File(path).existsSync()) {
          final ext = _notebooks[i].fileName != null && _notebooks[i].fileName!.contains('.')
              ? _notebooks[i].fileName!.split('.').last
              : 'dat';
          await encoder.addFile(File(path), 'files/n$i.$ext');
        }
      }
      await encoder.close();

      try {
        await File(tempJsonPath).delete();
      } catch (_) {}

      final result = await OpenFilex.open(zipPath);
      if (result.type != ResultType.done) {
        _toast('تم إنشاء النسخة الاحتياطية في: $zipPath');
      }
    } catch (_) {
      _toast('حدث خطأ أثناء إنشاء النسخة الاحتياطية');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        _toast('تعذّرت قراءة الملف');
        return;
      }

      final archive = arc.ZipDecoder().decodeBytes(bytes);
      arc.ArchiveFile? dataFile;
      for (final f in archive) {
        if (f.name == 'data.json') {
          dataFile = f;
          break;
        }
      }
      if (dataFile == null || dataFile.content is! List<int>) {
        _toast('ملف النسخة الاحتياطية غير صالح');
        return;
      }
      final data = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('استعادة نسخة احتياطية'),
          content: const Text('سيتم استبدال كل البيانات الحالية بمحتوى هذه النسخة. متابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('استعادة')),
          ],
        ),
      );
      if (confirmed != true) return;

      widget.store.sections
        ..clear()
        ..addAll((data['sections'] as List).map((x) => x.toString()));
      widget.store.students
        ..clear()
        ..addAll((data['students'] as List).map((x) => Student.fromJson(x as Map<String, dynamic>)));
      widget.store.attendance
        ..clear()
        ..addAll((data['attendance'] as List).map((x) => Attendance.fromJson(x as Map<String, dynamic>)));
      widget.store.grades
        ..clear()
        ..addAll((data['grades'] as List).map((x) => Grade.fromJson(x as Map<String, dynamic>)));
      widget.store.schedule
        ..clear()
        ..addAll((data['schedule'] as List? ?? []).map((x) => ScheduleEntry.fromJson(x as Map<String, dynamic>)));
      widget.store.lessons
        ..clear()
        ..addAll((data['lessons'] as List? ?? []).map((x) => LessonRecord.fromJson(x as Map<String, dynamic>)));

      final notebooksData = data['notebooks'] as Map<String, dynamic>? ?? {};
      final dir = await getApplicationDocumentsDirectory();
      final restored = <NotebookEntry>[];
      for (var i = 0; i < 5; i++) {
        final nd = notebooksData['n$i'] as Map<String, dynamic>?;
        final text = nd?['text'] as String? ?? '';
        final fileName = nd?['fileName'] as String?;
        String? filePath;
        if (fileName != null) {
          arc.ArchiveFile? af;
          for (final f in archive) {
            if (f.name.startsWith('files/n$i.')) {
              af = f;
              break;
            }
          }
          if (af != null && af.content is List<int>) {
            final ext = af.name.contains('.') ? af.name.split('.').last : 'dat';
            final savePath = '${dir.path}/notebook_$i.$ext';
            await File(savePath).writeAsBytes(af.content as List<int>);
            filePath = savePath;
          }
        }
        restored.add(NotebookEntry(text: text, fileName: fileName, filePath: filePath));
      }
      widget.store.yearlyProgram = restored[0];
      widget.store.yearlyDistribution = restored[1];
      widget.store.term1Notebook = restored[2];
      widget.store.term2Notebook = restored[3];
      widget.store.term3Notebook = restored[4];

      await widget.store.save();
      _toast('تمت الاستعادة بنجاح');
      if (mounted) setState(() {});
    } catch (_) {
      _toast('حدث خطأ أثناء الاستعادة — تأكد أن الملف نسخة احتياطية صحيحة من WALID');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('نسخة احتياطية واسترجاع')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'احفظ نسخة كاملة من كل بياناتك (الأقسام، التلاميذ، الحضور، التقييمات، مذكراتي وملفاتها المرفقة) في ملف واحد يمكنك حفظه في بريدك أو غوغل درايف، واستعادتها لاحقًا على نفس الهاتف أو هاتف آخر.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.backup_outlined, color: AppColors.primary),
                title: const Text('إنشاء نسخة احتياطية'),
                subtitle: const Text('يفتح خيارات المشاركة/الحفظ بعد الإنشاء'),
                trailing: busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_left),
                onTap: busy ? null : _export,
              ),
            ),
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.restore, color: AppColors.accent),
                title: const Text('استعادة من نسخة احتياطية'),
                subtitle: const Text('⚠️ سيستبدل كل البيانات الحالية'),
                trailing: busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_left),
                onTap: busy ? null : _import,
              ),
            ),
          ],
        ),
      );
}

class AiAssistantPage extends StatefulWidget{final WalidStore store;const AiAssistantPage({super.key,required this.store});@override State<AiAssistantPage> createState()=>_AiAssistantState();}

class _ActivityKit {
  final String warmup, mainEasy, mainMedium, mainHard, evaluation, equipment, safety;
  const _ActivityKit({
    required this.warmup,
    required this.mainEasy,
    required this.mainMedium,
    required this.mainHard,
    required this.evaluation,
    required this.equipment,
    required this.safety,
  });
}

class _AiAssistantState extends State<AiAssistantPage> {
  String level = 'الثانوي';
  final goalCtrl = TextEditingController(text: 'تنمية المهارة الأساسية');
  String activity = 'كرة اليد';
  int duration = 45;
  final output = TextEditingController();

  static const Map<String, _ActivityKit> _kits = {
    'كرة القدم': _ActivityKit(
      warmup: 'جري خفيف حول الملعب مع لمسات كرة متنوعة، ثم تمارين تصويب بسيطة بين لاعبين.',
      mainEasy: 'تمارين التمرير القصير بين ثنائيات، والتحكم بالكرة أثناء المشي.',
      mainMedium: 'تمارين التمرير والاستلام أثناء الحركة، ولعب 3 ضد 1 في مساحة محدودة.',
      mainHard: 'مباراة صغيرة 5 ضد 5 بمساحة مصغّرة مع التركيز على المراوغة والتصويب من الحركة.',
      evaluation: 'ملاحظة دقة التمرير، التحكم بالكرة، والتموقع أثناء اللعب.',
      equipment: 'كرات قدم، أقماع لتحديد المساحات، صدريات تمييز.',
      safety: 'التأكد من خلوّ الملعب من العوائق، وتهدئة الإيقاع عند الإرهاق.',
    ),
    'كرة اليد': _ActivityKit(
      warmup: 'جري خفيف مع تمارين حركية للكتفين والمعصمين، ثم رمي وتلقي الكرة بين ثنائيات وأنت واقف.',
      mainEasy: 'تمارين التمرير الثابت والتصويب من مكان ثابت نحو المرمى.',
      mainMedium: 'تمارين التمرير أثناء الجري، والتصويب بعد قفزة بسيطة.',
      mainHard: 'لعب جماعي 4 ضد 4 مع التركيز على الدفاع المتنقل والتصويب من زوايا مختلفة.',
      evaluation: 'دقة الرمي والتلقي، سرعة الأداء، والتنسيق الجماعي.',
      equipment: 'كرات يد، مرمى أو أهداف بديلة، أقماع.',
      safety: 'الإحماء الجيد للكتف قبل الرمي القوي، والانتباه عند القفز والهبوط.',
    ),
    'كرة السلة': _ActivityKit(
      warmup: 'جري خفيف مع تنطيط الكرة، ثم تمارين تمرير صدرية بين ثنائيات.',
      mainEasy: 'تنطيط الكرة أثناء المشي، وتمارين تصويب من قرب السلة.',
      mainMedium: 'تنطيط أثناء الجري مع تغيير الاتجاه، وتصويب بعد توقف مزدوج.',
      mainHard: 'لعب 3 ضد 3 مع التركيز على الدفاع الفردي والتصويب من مسافات متوسطة.',
      evaluation: 'التحكم بالكرة أثناء الحركة، دقة التصويب، والانضباط الدفاعي.',
      equipment: 'كرات سلة، ملعب بسلال أو أهداف بديلة.',
      safety: 'الانتباه للاصطدامات أثناء الدفاع، وربط الحذاء جيدًا لتفادي الانزلاق.',
    ),
    'ألعاب القوى': _ActivityKit(
      warmup: 'جري تدريجي مع تمارين إطالة ديناميكية للرجلين والظهر.',
      mainEasy: 'تمارين عدو قصيرة (20 م) بانطلاق حر، وتمارين وثب بسيطة.',
      mainMedium: 'عدو 40-60 م بانطلاق منخفض، وتمارين وثب طويل من الثبات.',
      mainHard: 'عدو سرعة مع قياس الزمن، ووثب طويل بمراحل تقنية كاملة (الانطلاق، الطيران، الهبوط).',
      evaluation: 'قياس الزمن أو المسافة، وملاحظة التقنية الحركية.',
      equipment: 'شريط قياس، صافرة، ساعة توقيت، حفرة أو منطقة وثب آمنة.',
      safety: 'التأكد من نظافة مسار العدو ومنطقة الهبوط، وإحماء كافٍ لتفادي الشد العضلي.',
    ),
    'الجمباز': _ActivityKit(
      warmup: 'إطالة شاملة للمفاصل والعضلات، وتمارين توازن بسيطة على الأرض.',
      mainEasy: 'تمارين تدحرج أمامي وخلفي على بساط، ووقفة على اليدين بمساعدة.',
      mainMedium: 'تمارين تدحرج مركّبة، ووقفة على اليدين مع محاولة اتزان قصيرة بدون مساعدة.',
      mainHard: 'تركيب حركي بسيط يجمع بين التدحرج والوقفة والقفز، أمام بقية التلاميذ.',
      evaluation: 'سلامة التنفيذ التقني، الاتزان، والثقة أثناء الأداء.',
      equipment: 'بُسط جمباز، مساحة آمنة وواسعة.',
      safety: 'إشراف مباشر ومساعدة يدوية أثناء كل حركة تحتوي على مخاطر سقوط.',
    ),
    'اللياقة البدنية': _ActivityKit(
      warmup: 'جري خفيف وتمارين حركية عامة لكل مفاصل الجسم.',
      mainEasy: 'دائرة تمارين خفيفة (ضغط، بطن، قفز بسيط) بفترات راحة كافية.',
      mainMedium: 'دائرة تمارين متوسطة الشدة بتكرارات محددة وفترات راحة قصيرة بين المحطات.',
      mainHard: 'تدريب فتري (Interval) بمحطات متعددة الشدة مع تحدٍ فردي أو ثنائي.',
      evaluation: 'عدد التكرارات المنجزة، الالتزام بالتقنية الصحيحة، والقدرة على الاستمرار.',
      equipment: 'حصائر، أقماع لتحديد المحطات، ساعة توقيت.',
      safety: 'مراقبة علامات الإرهاق الزائد، والسماح بالراحة عند الحاجة.',
    ),
  };

  @override
  void dispose() {
    output.dispose();
    goalCtrl.dispose();
    super.dispose();
  }

  void generate() {
    final kit = _kits[activity]!;
    final warmupMin = (duration * 0.2).round();
    final mainMin = (duration * 0.55).round();
    final evalMin = (duration * 0.15).round();
    final cooldownMin = duration - warmupMin - mainMin - evalMin;
    final mainContent = level == 'الابتدائي'
        ? kit.mainEasy
        : (level == 'المتوسط' ? kit.mainMedium : kit.mainHard);

    output.text = 'خطة حصة مقترحة\n\n'
        'المستوى: $level\n'
        'النشاط: $activity\n'
        'الهدف: ${goalCtrl.text}\n'
        'المدة الإجمالية: $duration دقيقة\n\n'
        '1) الإحماء — $warmupMin دقيقة:\n${kit.warmup}\n\n'
        '2) الجزء الرئيسي — $mainMin دقيقة:\n$mainContent\n\n'
        '3) التقويم — $evalMin دقيقة:\n${kit.evaluation}\n\n'
        '4) التهدئة — $cooldownMin دقيقة:\nتمارين تنفس وتمطيط خفيف وعودة تدريجية للهدوء.\n\n'
        'الأدوات اللازمة: ${kit.equipment}\n\n'
        'ملاحظات السلامة: ${kit.safety}\n\n'
        'معايير النجاح: المشاركة الفعّالة، سلامة الأداء التقني، احترام التعليمات، وتحسن ملحوظ في ${goalCtrl.text}.';
    setState(() {});
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('المساعد الذكي للأستاذ')),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const Text(
              'مولّد محلي فوري لخطة حصة كاملة — يعمل بدون إنترنت، ولا يرسل أي بيانات خارج هاتفك.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: level,
              items: ['الابتدائي', 'المتوسط', 'الثانوي']
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (v) => setState(() => level = v!),
              decoration: const InputDecoration(labelText: 'المستوى'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: activity,
              items: _kits.keys
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (v) => setState(() => activity = v!),
              decoration: const InputDecoration(labelText: 'النشاط'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: duration,
              items: [45, 60, 90]
                  .map((x) => DropdownMenuItem(value: x, child: Text('$x دقيقة')))
                  .toList(),
              onChanged: (v) => setState(() => duration = v!),
              decoration: const InputDecoration(labelText: 'مدة الحصة'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: goalCtrl,
              decoration: const InputDecoration(labelText: 'الهدف التعليمي'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('توليد الخطة'),
            ),
            if (output.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(output.text, style: const TextStyle(height: 1.6)),
                ),
              ),
              TextButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: output.text)),
                icon: const Icon(Icons.copy),
                label: const Text('نسخ الخطة'),
              ),
            ],
          ],
        ),
      );
}

// ============================================================
// الإعدادات
// ============================================================

class SettingsPage extends StatelessWidget {
  final WalidStore store;
  const SettingsPage({super.key, required this.store});

  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'الإعدادات',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 15),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const ListTile(
              title: Text('WALID'),
              subtitle: Text('نظام إدارة التربية البدنية والرياضية'),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.absent),
              title: const Text('مسح جميع البيانات'),
              onTap: () => confirm(
                c,
                'سيتم حذف جميع البيانات نهائيًا. متابعة؟',
                () {
                  store.sections.clear();
                  store.students.clear();
                  store.attendance.clear();
                  store.grades.clear();
                  store.schedule.clear();
                  store.lessons.clear();
                  for (final path in [
                    store.yearlyProgram.filePath,
                    store.yearlyDistribution.filePath,
                    store.term1Notebook.filePath,
                    store.term2Notebook.filePath,
                    store.term3Notebook.filePath,
                  ]) {
                    if (path != null) {
                      try {
                        File(path).deleteSync();
                      } catch (_) {}
                    }
                  }
                  store.yearlyProgram = NotebookEntry();
                  store.yearlyDistribution = NotebookEntry();
                  store.term1Notebook = NotebookEntry();
                  store.term2Notebook = NotebookEntry();
                  store.term3Notebook = NotebookEntry();
                  store.save();
                },
              ),
            ),
          ),
        ],
      );
}

// ============================================================
// عناصر مشتركة
// ============================================================

class PageShell extends StatelessWidget {
  final String title, action; final IconData icon; final VoidCallback onAdd; final Widget child; final List<Widget> extraActions;
  const PageShell({super.key, required this.title, required this.icon, required this.action, required this.onAdd, required this.child, this.extraActions=const []});
  @override
  Widget build(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 720;
      final actions = <Widget>[...extraActions, FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(action))];
      final titleRow = Row(children: [Container(width:44,height:44,decoration:BoxDecoration(color:AppColors.primary.withOpacity(.10),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:AppColors.primary)),const SizedBox(width:12),Expanded(child:Text(title,maxLines:1,overflow:TextOverflow.ellipsis,softWrap:false,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)))]);
      return Padding(padding: const EdgeInsets.fromLTRB(16,16,16,12), child: narrow ? Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[titleRow,const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,alignment:WrapAlignment.start,children:actions)]) : Row(children:[Expanded(child:titleRow),const SizedBox(width:12),...actions]));
    }),
    const Divider(height:1), Expanded(child:child),
  ]);
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const Empty({super.key, this.icon = Icons.inbox_outlined, this.text = 'لا توجد بيانات بعد.'});

  @override
  Widget build(BuildContext c) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Colors.black26),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      );
}

Widget rowMenu({required VoidCallback onEdit, required VoidCallback onDelete}) {
  return PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    onSelected: (v) {
      if (v == 'edit') onEdit();
      if (v == 'delete') onDelete();
    },
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 8),
            Text('تعديل'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: AppColors.absent),
            SizedBox(width: 8),
            Text('حذف', style: TextStyle(color: AppColors.absent)),
          ],
        ),
      ),
    ],
  );
}

void confirm(BuildContext c, String title, VoidCallback yes) {
  showDialog(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(c);
            yes();
          },
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
}
