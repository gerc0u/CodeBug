import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/exercises.dart';
import '../models/progress.dart';
import 'design.dart';
import 'exercise_page.dart';
import 'library.dart';
import 'profile.dart';
import 'notebook.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final ProgressStore store;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int page = 0;
  final labels = ['Тренажёр', 'Теория', 'Рейтинг', 'Профиль'];
  final icons = [
    Icons.dashboard_outlined,
    Icons.auto_stories_outlined,
    Icons.emoji_events_outlined,
    Icons.person_outline_rounded,
  ];
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= 900;
      final screens = [
        Dashboard(
          store: widget.store,
          onProfile: () => setState(() => page = 3),
        ),
        TheoryPage(store: widget.store),
        RatingPage(store: widget.store),
        ProfilePage(store: widget.store),
      ];
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (wide)
                Container(
                  width: 220,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: line(context))),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 30,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FittedBox(fit: BoxFit.scaleDown, child: Brand()),
                      const SizedBox(height: 55),
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'ТВОЁ ПРОСТРАНСТВО',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var i = 0; i < labels.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Material(
                            color: page == i
                                ? violet.withValues(alpha: .13)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(13),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                              leading: Icon(
                                icons[i],
                                color: page == i ? violet : muted,
                                size: 21,
                              ),
                              title: Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: page == i
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                              onTap: () => setState(() => page = i),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Surface(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.auto_awesome_outlined,
                              color: violet,
                            ),
                            const SizedBox(height: 13),
                            const Text(
                              'Маленькие шаги.\nБольшой прогресс.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${widget.store.solved.length} из ${exercises.length} ошибок найдено',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'CODE. DEBUG. GROW.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 9,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (widget.store.saveFailed)
                      MaterialBanner(
                        content: Text(
                          widget.store.syncError ?? 'Не удалось сохранить изменения. Повтори попытку.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: widget.store.save,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    Expanded(child: screens[page]),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: page,
                onDestinationSelected: (v) => setState(() => page = v),
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                ],
              ),
      );
    },
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: violet,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.bug_report_rounded,
          color: Color(0xFF2A1948),
          size: 24,
        ),
      ),
      const SizedBox(width: 11),
      Text('CodeBug', style: heading(23)),
    ],
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.store, required this.onProfile});
  final ProgressStore store;
  final VoidCallback onProfile;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String language = 'Все';
  void catalog() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) =>
          CatalogPage(store: widget.store, initialLanguage: language),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final wide = MediaQuery.sizeOf(context).width >= 1120;
    final filtered = exercises
        .where((e) => language == 'Все' || e.language == language)
        .toList();
    final featured = [
      ...filtered.where((e) => !s.solved.contains(e.id)),
      ...filtered.where((e) => s.solved.contains(e.id)),
    ].take(3).toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1300),
        child: ListView(
          padding: EdgeInsets.all(wide ? 38 : 22),
          children: [
            Row(
              children: [
                if (MediaQuery.sizeOf(context).width < 900)
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(fit: BoxFit.scaleDown, child: Brand()),
                    ),
                  )
                else
                  const Text(
                    'УЧИСЬ НАХОДИТЬ. УЧИСЬ ПОНИМАТЬ.',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.8,
                      color: muted,
                    ),
                  ),
                if (MediaQuery.sizeOf(context).width >= 900) const Spacer(),
                Tag('${s.streak} дн.', color: const Color(0xFFFFC78D)),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: widget.onProfile,
                  tooltip: 'Мой профиль',
                  icon: Text(
                    s.name.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            Text('Ошибаться — часть пути.', style: heading(wide ? 34 : 27)),
            const SizedBox(height: 10),
            const Text(
              'Находи баги. Прокачивай мышление разработчика.',
              style: TextStyle(color: muted, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hero(s, wide),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _stat(
                              context,
                              Icons.check_circle_outline_rounded,
                              '${s.solved.length}',
                              'Решено',
                              mint,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _stat(
                              context,
                              Icons.bolt_rounded,
                              '${s.xp}',
                              'Всего XP',
                              violet,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _stat(
                              context,
                              Icons.track_changes_rounded,
                              s.attempts == 0
                                  ? '—'
                                  : '${(s.correct / s.attempts * 100).round()}%',
                              'Точность',
                              const Color(0xFFFFC78D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.bookmark_border, size: 18),
                            label: const Text('Избранное'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    CatalogPage(store: s, favoritesOnly: true),
                              ),
                            ),
                          ),
                          if (s.api != null) ...[
                            ActionChip(
                              avatar: const Icon(Icons.edit_note, size: 18),
                              label: const Text('Мои заметки'),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => NotesPage(store: s),
                                ),
                              ),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.history, size: 18),
                              label: const Text('История'),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => HistoryPage(store: s),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SectionTitle(
                        'Практика',
                        action: 'Все задания →',
                        onTap: catalog,
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final item in [
                              'Все',
                              'Dart',
                              'Python',
                              'JavaScript',
                              'Java',
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(item),
                                  selected: language == item,
                                  onSelected: (_) =>
                                      setState(() => language = item),
                                  showCheckmark: false,
                                  selectedColor: violet,
                                  labelStyle: TextStyle(
                                    color: language == item
                                        ? const Color(0xFF281A45)
                                        : ink(context),
                                    fontSize: 12,
                                  ),
                                  side: BorderSide(color: line(context)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final e in featured)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: ExerciseCard(exercise: e, store: s),
                        ),
                      if (!wide) ...[
                        const SectionTitle('Твой ритм'),
                        _daily(s),
                        const SizedBox(height: 15),
                        _tip(context),
                      ],
                    ],
                  ),
                ),
                if (wide) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _daily(s),
                        const SizedBox(height: 20),
                        _tip(context),
                        const SizedBox(height: 20),
                        _path(s),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),
            const Center(
              child: Text(
                'Каждая найденная ошибка — новый навык.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(ProgressStore s, bool wide) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF6C49B7), Color(0xFF3B275E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFF8C68C7)),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -30,
          top: -16,
          child: SizedBox(
            width: wide ? 230 : 170,
            height: 260,
            child: CustomPaint(painter: OrbitPainter()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFE1D1FF), size: 15),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'ТВОЯ СЛЕДУЮЩАЯ ПОБЕДА',
                      style: TextStyle(
                        color: Color(0xFFE1D1FF),
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 21),
              const Text(
                'Меньше багов.\nБольше уверенности.',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                  letterSpacing: -.8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Одна задача сегодня —\nодин навык навсегда.',
                style: TextStyle(
                  color: Color(0xFFD3C3EA),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 23),
              PrimaryButton(
                s.active != null
                    ? 'Продолжить'
                    : s.solved.length == exercises.length
                    ? 'Повторить практику'
                    : 'Начать тренировку',
                onPressed: () => openExercise(context, s, s.next),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _stat(
    BuildContext c,
    IconData icon,
    String value,
    String label,
    Color color,
  ) => Surface(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 13),
        Text(value, style: heading(25)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: muted)),
      ],
    ),
  );
  Widget _daily(ProgressStore s) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Цель на сегодня', style: heading(18))),
            const SizedBox(width: 12),
            const Icon(
              Icons.wb_sunny_outlined,
              color: Color(0xFFFFC78D),
              size: 22,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: math.min(s.todayCount / 3, 1),
                      strokeWidth: 5,
                      backgroundColor: line(context),
                      color: violet,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text('${math.min(s.todayCount, 3)}/3', style: heading(19)),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.todayCount >= 3
                        ? 'Цель достигнута!'
                        : 'Три маленькие победы',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Реши 3 новых задания',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 21),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (var i = 6; i >= 0; i--) _day(s, i)],
        ),
        const SizedBox(height: 16),
        const Text(
          'Ритм важнее скорости. Ты справишься.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    ),
  );
  Widget _day(ProgressStore s, int ago) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day - ago);
    final complete = s.activity.containsKey(ProgressStore.dayKey(date));
    return Column(
      children: [
        Text(
          ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][date.weekday - 1],
          style: const TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 10),
        Container(
          width: 27,
          height: 30,
          decoration: BoxDecoration(
            color: complete ? violet : line(context).withValues(alpha: .45),
            borderRadius: BorderRadius.circular(8),
            border: ago == 0 ? Border.all(color: violet) : null,
          ),
          child: Icon(
            complete
                ? Icons.check_rounded
                : ago == 0
                ? Icons.circle
                : Icons.remove,
            size: ago == 0 && !complete ? 6 : 14,
            color: complete ? const Color(0xFF34234F) : muted,
          ),
        ),
      ],
    );
  }

  Widget _tip(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Tag('DEBUG / СОВЕТ ДНЯ'),
        const SizedBox(height: 18),
        Text('Думай как\nинтерпретатор.', style: heading(23)),
        const SizedBox(height: 12),
        const Text(
          'Пройди по коду строка за строкой. Записывай, как меняются значения переменных — ошибка станет заметнее.',
          style: TextStyle(color: muted, height: 1.7, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => openLesson(context, widget.store, lessons.first),
          icon: const Icon(Icons.auto_stories_outlined, size: 17),
          label: const Text('Разобраться в теории'),
        ),
      ],
    ),
  );
  Widget _path(ProgressStore s) => Surface(
    child: Row(
      children: [
        const Icon(Icons.workspace_premium_outlined, color: violet, size: 33),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Уровень ${s.level} · ${s.level == 1 ? 'Исследователь' : 'Баг-хантер'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: s.xp % 100 / 100,
                borderRadius: BorderRadius.circular(6),
                minHeight: 5,
              ),
              const SizedBox(height: 7),
              Text(
                '${100 - s.xp % 100} XP до нового уровня',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = violet.withValues(alpha: .12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width * .75, size.height * .48);
    for (final radius in [50.0, 85.0, 120.0]) {
      canvas.drawCircle(center, radius, p);
    }
    p
      ..style = PaintingStyle.fill
      ..color = violet.withValues(alpha: .22);
    canvas.drawCircle(center + const Offset(-65, -55), 8, p);
    canvas.drawCircle(center + const Offset(-40, 107), 5, p);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-38, -38, 76, 76),
        const Radius.circular(23),
      ),
      Paint()..color = violet.withValues(alpha: .16),
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: '</>',
        style: TextStyle(
          fontSize: 33,
          fontWeight: FontWeight.w700,
          color: Color(0xFFD9C5FF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({super.key, required this.exercise, required this.store});
  final Exercise exercise;
  final ProgressStore store;
  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final complete = store.solved.contains(e.id);
    return Surface(
      padding: const EdgeInsets.all(17),
      onTap: () => openExercise(context, store, e),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 48,
            decoration: BoxDecoration(
              color: violet.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              complete ? Icons.check_rounded : Icons.code_rounded,
              color: complete ? mint : violet,
              size: 23,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Tag(e.language),
                    const SizedBox(width: 8),
                    Text(
                      e.difficulty,
                      style: TextStyle(
                        fontSize: 10,
                        color: e.level == 1 ? mint : muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  e.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${e.topic}  ·  ${e.minutes} мин',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              FavoriteButton(store: store, id: e.id),
              const SizedBox(height: 13),
              Text(
                complete ? 'Готово' : '+${e.xp} XP',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
