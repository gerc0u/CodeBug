import 'package:flutter/material.dart';

import '../models/progress.dart';
import '../data/exercises.dart';
import 'design.dart';
import 'library.dart';
import 'anketa_page.dart';
import 'notebook.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.store});
  final ProgressStore store;
  Future<void> editName(BuildContext context) async {
    final controller = TextEditingController(text: store.name);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Как тебя называть?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(labelText: 'Имя'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(c, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(c, controller.text.trim());
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    // The route owns the field until its dismissal animation completes.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    if (name != null) {
      store.name = name;
      await store.save();
      if (context.mounted && !store.saveFailed) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Имя сохранено')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(child: Text('Мой профиль', style: heading(29))),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsPage(store: store),
                  ),
                ),
                tooltip: 'Настройки',
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          if (store.api != null) ...[
            Text(store.email, style: const TextStyle(color: muted)),
            Wrap(
              spacing: 12,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Обновить прогресс'),
                  onPressed: () async {
                    try {
                      await store.refresh();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Выйти'),
                  onPressed: () async {
                    try {
                      await store.logout();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          Surface(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: violet,
                  child: Text(
                    store.name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 30,
                      color: Color(0xFF33214E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(store.name, style: heading(24)),
                TextButton.icon(
                  onPressed: () => editName(context),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text(
                    'Изменить имя',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Tag('Уровень ${store.level} · ${store.xp} XP'),
                const SizedBox(height: 22),
                LinearProgressIndicator(
                  value: store.xp % 100 / 100,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ещё ${100 - store.xp % 100} XP до следующего уровня',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('Анкета · сохранить в файл'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AnketaPage(
                  initialName: store.name,
                  initialEmail: store.email,
                ),
              ),
            ),
          ),
          const SectionTitle('Моя библиотека'),
          Surface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_border),
                  title: const Text('Избранные задания'),
                  subtitle: Text('Сохранено: ${store.favorites.length}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CatalogPage(store: store, favoritesOnly: true),
                    ),
                  ),
                ),
                if (store.api != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: const Text('Мои заметки'),
                    subtitle: const Text('Твои выводы после практики'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => NotesPage(store: store),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('История попыток'),
                    subtitle: const Text('Результаты и начисленные XP'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => HistoryPage(store: store),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('Мой прогресс'),
          Surface(
            child: Column(
              children: [
                for (final lang in ['Dart', 'Python', 'JavaScript', 'Java'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 90, child: Text(lang)),
                        Expanded(
                          child: LinearProgressIndicator(
                            value:
                                exercises
                                    .where(
                                      (e) =>
                                          e.language == lang &&
                                          store.solved.contains(e.id),
                                    )
                                    .length /
                                3,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${exercises.where((e) => e.language == lang && store.solved.contains(e.id)).length}/3',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle('Достижения'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _badge(
                context,
                'Первый баг',
                'Реши 1 задание',
                Icons.bug_report_outlined,
                store.solved.isNotEmpty,
              ),
              _badge(
                context,
                'В потоке',
                'Реши 5 заданий',
                Icons.bolt_rounded,
                store.solved.length >= 5,
              ),
              _badge(
                context,
                'Эрудит',
                'Прочитай все темы',
                Icons.auto_stories_outlined,
                store.read.length == lessons.length,
              ),
              _badge(
                context,
                'Баг-хантер',
                'Реши все задания',
                Icons.workspace_premium_outlined,
                store.solved.length == exercises.length,
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CatalogPage(store: store),
              ),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Перейти к заданиям'),
          ),
          const SizedBox(height: 18),
          const Text(
            'Прогресс хранится на сервере · дневная серия по UTC',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
  Widget _badge(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool earned,
  ) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 400 ? double.infinity : 175,
    child: Surface(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(icon, size: 30, color: earned ? violet : muted),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          Text(
            earned ? 'Получено' : subtitle,
            style: TextStyle(color: earned ? violet : muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});
  final ProgressStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const SectionTitle('Внешний вид'),
              Surface(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Тёмная тема'),
                      subtitle: const Text(
                        'Фиолетовый после полуночи',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      value: store.dark,
                      onChanged: (v) {
                        store.dark = v;
                        store.save();
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Крупный код'),
                      subtitle: const Text(
                        'Увеличить шрифт в заданиях',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      value: store.largeCode,
                      onChanged: (v) {
                        store.largeCode = v;
                        store.save();
                      },
                    ),
                  ],
                ),
              ),
              const SectionTitle('О приложении'),
              const Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CodeBug 3.0',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Учебный тренажёр поиска ошибок в коде.\n\n12 заданий · 4 языка · 6 коротких уроков\nИзбранное · личные заметки · история попыток\n\nОтветы проверяются по подготовленным решениям. Приложение не запускает произвольный код и не анализирует загруженные проекты.',
                      style: TextStyle(height: 1.7, color: muted),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Данные'),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Начать с чистого листа?'),
                      content: const Text(
                        'Решённые задания, история попыток, XP, серия и отметки о прочтении будут удалены. Имя, заметки, избранное и настройки сохранятся.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Сбросить прогресс'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await store.reset();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                      return;
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Прогресс сброшен')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Сбросить прогресс'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class RatingPage extends StatefulWidget {
  const RatingPage({super.key, required this.store});
  final ProgressStore store;
  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.store.api != null) await widget.store.loadRanking();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 15),
          const Tag('РЕЙТИНГ'),
          const SizedBox(height: 20),
          Text('Расти в своём темпе.', style: heading(32)),
          const SizedBox(height: 13),
          const Text(
            'Реальные результаты участников. XP начисляются сервером за первое верное решение. Здесь отображаются первые 50 участников.',
            style: TextStyle(color: muted, height: 1.7),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить рейтинг'),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!busy && error == null && widget.store.ranking.isEmpty)
            const Text('Пока нет результатов'),
          for (var i = 0; i < widget.store.ranking.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Surface(
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: muted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${widget.store.ranking[i].name}${widget.store.ranking[i].you ? ' · ты' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text('${widget.store.ranking[i].xp} XP'),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
