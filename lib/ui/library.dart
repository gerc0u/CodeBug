import 'package:flutter/material.dart';

import '../data/exercises.dart';
import '../models/progress.dart';
import 'design.dart';
import 'home.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.store,
    this.initialLanguage = 'Все',
    this.topic,
    this.favoritesOnly = false,
  });
  final ProgressStore store;
  final String initialLanguage;
  final String? topic;
  final bool favoritesOnly;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late String language = widget.initialLanguage;
  String query = '', status = 'Все задания';
  int difficulty = 0;
  late bool favoritesOnly = widget.favoritesOnly;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final filtered = exercises
          .where(
            (e) =>
                (language == 'Все' || e.language == language) &&
                (difficulty == 0 || e.level == difficulty) &&
                (widget.topic == null || widget.topic == e.topic) &&
                (!favoritesOnly || widget.store.favorites.contains(e.id)) &&
                (status == 'Все задания' ||
                    (status == 'Решённые') ==
                        widget.store.solved.contains(e.id)) &&
                '${e.title} ${e.topic} ${e.language}'.toLowerCase().contains(
                  query.toLowerCase(),
                ),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.topic ??
                (widget.favoritesOnly ? 'Избранное' : 'Все задания'),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                TextField(
                  controller: search,
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Название, язык или тема',
                  ),
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final l in [
                      'Все',
                      'Dart',
                      'Python',
                      'JavaScript',
                      'Java',
                    ])
                      ChoiceChip(
                        label: Text(l),
                        selected: language == l,
                        onSelected: (_) => setState(() => language = l),
                      ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(difficulty),
                        isExpanded: true,
                        initialValue: difficulty,
                        decoration: const InputDecoration(
                          labelText: 'Сложность',
                        ),
                        items: [
                          for (var i = 0; i < 4; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                ['Любая', 'Легко', 'Средне', 'Сложно'][i],
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => difficulty = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(status),
                        isExpanded: true,
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'Прогресс',
                        ),
                        items: [
                          for (final item in [
                            'Все задания',
                            'Нерешённые',
                            'Решённые',
                          ])
                            DropdownMenuItem(
                              value: item,
                              child: Text(
                                item,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => status = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    FilterChip(
                      label: Text(
                        'Избранное · ${widget.store.favorites.length}',
                      ),
                      avatar: const Icon(Icons.bookmark_border, size: 18),
                      selected: favoritesOnly,
                      onSelected: (v) => setState(() => favoritesOnly = v),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        search.clear();
                        query = '';
                        language = 'Все';
                        difficulty = 0;
                        status = 'Все задания';
                        favoritesOnly = false;
                      }),
                      child: const Text('Сбросить фильтры'),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Text(
                  'Найдено: ${filtered.length}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 15),
                if (filtered.isEmpty)
                  const Surface(
                    child: Column(
                      children: [
                        Icon(Icons.search_off_rounded, size: 38, color: muted),
                        SizedBox(height: 14),
                        Text('Ничего не нашлось'),
                        SizedBox(height: 8),
                        Text(
                          'Попробуй другой запрос или измени фильтры.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                for (final e in filtered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ExerciseCard(exercise: e, store: widget.store),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class TheoryPage extends StatefulWidget {
  const TheoryPage({super.key, required this.store});
  final ProgressStore store;
  @override
  State<TheoryPage> createState() => _TheoryPageState();
}

class _TheoryPageState extends State<TheoryPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 15),
          const Tag('БИБЛИОТЕКА ЗНАНИЙ'),
          const SizedBox(height: 18),
          Text('Понимай,\nа не запоминай.', style: heading(34)),
          const SizedBox(height: 12),
          const Text(
            'Короткие разборы, которые делают практику осмысленной.',
            style: TextStyle(color: muted, height: 1.6),
          ),
          const SizedBox(height: 26),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Найти тему',
            ),
          ),
          SectionTitle(
            'Основы отладки',
            action: '${widget.store.read.length}/${lessons.length} прочитано',
          ),
          if (lessons
              .where(
                (l) => '${l.title} ${l.subtitle} ${l.topic}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
              )
              .isEmpty)
            const Surface(
              child: Text('Такой темы пока нет. Попробуй другой запрос.'),
            ),
          for (final lesson in lessons.where(
            (l) => '${l.title} ${l.subtitle} ${l.topic}'.toLowerCase().contains(
              query.toLowerCase(),
            ),
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Surface(
                onTap: () => openLesson(context, widget.store, lesson),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 50,
                      decoration: BoxDecoration(
                        color: violet.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.store.read.contains(lesson.title)
                            ? Icons.check_rounded
                            : Icons.auto_stories_outlined,
                        color: violet,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lesson.subtitle,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

void openLesson(BuildContext context, ProgressStore store, Lesson lesson) =>
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Теория')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Tag(lesson.subtitle),
                  const SizedBox(height: 22),
                  Text(lesson.title, style: heading(33)),
                  const SizedBox(height: 24),
                  Text(
                    lesson.body,
                    style: const TextStyle(fontSize: 16, height: 1.9),
                  ),
                  const SizedBox(height: 24),
                  CodeView(lines: lesson.example.split('\n')),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    'Понятно, к практике',
                    onPressed: () {
                      store.read.add(lesson.title);
                      store.save();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CatalogPage(store: store, topic: lesson.topic),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      store.read.add(lesson.title);
                      store.save();
                      Navigator.pop(context);
                    },
                    child: const Text('Отметить прочитанным'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
