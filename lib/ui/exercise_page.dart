import 'package:flutter/material.dart';

import '../data/exercises.dart';
import '../models/progress.dart';
import 'design.dart';
import 'notebook.dart';

void openExercise(
  BuildContext context,
  ProgressStore store,
  Exercise exercise,
) {
  store.start(exercise);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExercisePage(store: store, exercise: exercise),
    ),
  );
}

class ExercisePage extends StatefulWidget {
  const ExercisePage({super.key, required this.store, required this.exercise});
  final ProgressStore store;
  final Exercise exercise;
  @override
  State<ExercisePage> createState() => _ExercisePageState();
}

class _ExercisePageState extends State<ExercisePage> {
  int? selected;
  bool wrong = false, done = false, repeat = false, busy = false;
  String? requestId;
  int? requestLine;
  @override
  void initState() {
    super.initState();
    repeat = widget.store.solved.contains(widget.exercise.id);
  }

  Future<void> check() async {
    if (selected == null || done || busy) return;
    final line = selected!;
    if (requestLine != line) {
      requestId = ProgressStore.newRequestId();
      requestLine = line;
    }
    setState(() => busy = true);
    bool success;
    try {
      success = await widget.store.answer(
        widget.exercise,
        line,
        requestId: requestId,
      );
      if (!mounted) return;
      repeat = widget.store.lastAward == 0;
      requestId = null;
      requestLine = null;
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      wrong = !success;
      done = success;
    });
    if (success) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 6, 28, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mint.withValues(alpha: .14),
                  ),
                  child: const Icon(Icons.check_rounded, color: mint, size: 40),
                ),
                const SizedBox(height: 20),
                Text('Ошибка найдена!', style: heading(27)),
                const SizedBox(height: 10),
                Text(
                  repeat
                      ? 'Отличное повторение. XP за это задание уже начислены.'
                      : 'Ещё один шаг к уверенному коду.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Tag(
                  repeat ? 'Навык закреплён' : '+${widget.store.lastAward} XP',
                  color: mint,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    'Посмотреть разбор',
                    onPressed: () => Navigator.pop(c),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void hint() {
    widget.store.hinted.add(widget.exercise.id);
    widget.store.save();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 8, 26, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: violet,
                size: 32,
              ),
              const SizedBox(height: 16),
              Text('Небольшая подсказка', style: heading(23)),
              const SizedBox(height: 14),
              Text(
                widget.exercise.hint,
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
              const SizedBox(height: 22),
              PrimaryButton('Попробую ещё', onPressed: () => Navigator.pop(c)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Задание ${exercises.indexOf(e) + 1} / ${exercises.length}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          FavoriteButton(store: widget.store, id: e.id),
          if (widget.store.api != null)
            IconButton(
              tooltip: 'Заметки к заданию',
              icon: const Icon(Icons.edit_note),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => NotesPage(store: widget.store, exercise: e),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Tag('+${e.xp} XP')),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 35),
            children: [
              Row(
                children: [
                  Tag(e.language),
                  const SizedBox(width: 8),
                  Tag(
                    e.difficulty,
                    color: e.level == 1 ? mint : const Color(0xFFEBC18B),
                  ),
                  const Spacer(),
                  const Icon(Icons.schedule_rounded, size: 15, color: muted),
                  const SizedBox(width: 5),
                  Text(
                    '${e.minutes} мин',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(e.title, style: heading(32)),
              const SizedBox(height: 14),
              Text(
                e.description,
                style: const TextStyle(fontSize: 15, height: 1.7),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle_outline
                        : Icons.touch_app_outlined,
                    color: done ? mint : violet,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      done
                          ? 'Верно! Ошибка в строке ${e.errorLine}'
                          : 'Нажми на строку с ошибкой',
                      style: TextStyle(
                        color: done ? mint : muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CodeView(
                lines: e.code,
                selected: selected,
                large: widget.store.largeCode,
                correct: done,
                onSelect: done || busy
                    ? null
                    : (value) => setState(() {
                        selected = value;
                        wrong = false;
                      }),
              ),
              if (wrong)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Surface(
                    color: const Color(0xFF442B39),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.refresh, color: Color(0xFFFFB5C2)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Не совсем. Проследи выполнение кода ещё раз или открой подсказку.',
                            style: TextStyle(
                              color: Color(0xFFFFDCE3),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (!done)
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : hint,
                      icon: const Icon(Icons.lightbulb_outline, size: 18),
                      label: const Text('Подсказка'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        busy ? 'Проверяем…' : 'Проверить',
                        icon: Icons.check_rounded,
                        onPressed: selected == null || busy ? null : check,
                      ),
                    ),
                  ],
                ),
              if (done) ...[
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Tag('РАЗБОР РЕШЕНИЯ', color: mint),
                      const SizedBox(height: 15),
                      Text(
                        e.explanation,
                        style: const TextStyle(fontSize: 15, height: 1.7),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Исправленный код'),
                CodeView(
                  lines: e.correctedCode,
                  large: widget.store.largeCode,
                  selected: e.errorLine,
                  correct: true,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  widget.store.solved.length == exercises.length
                      ? 'Вернуться к тренировкам'
                      : 'Следующее задание',
                  onPressed: () {
                    final next = widget.store.next;
                    Navigator.pop(context);
                    if (widget.store.solved.length < exercises.length) {
                      openExercise(context, widget.store, next);
                    }
                  },
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Учебный пример • код не выполняется на устройстве',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
