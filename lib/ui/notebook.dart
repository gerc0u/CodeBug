import 'package:flutter/material.dart';

import '../data/exercises.dart';
import '../models/notebook.dart';
import '../models/progress.dart';
import 'design.dart';
import 'exercise_page.dart';

String shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.store, required this.id});
  final ProgressStore store;
  final String id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final saved = store.favorites.contains(id);
      return IconButton(
        key: ValueKey('favorite-$id'),
        tooltip: saved ? 'Убрать из избранного' : 'В избранное',
        isSelected: saved,
        icon: const Icon(Icons.bookmark_border_rounded),
        selectedIcon: Icon(
          Icons.bookmark_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: store.savingFavorites.contains(id)
            ? null
            : () async {
                try {
                  await store.setFavorite(id, !saved);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
      );
    },
  );
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.store, this.exercise});
  final ProgressStore store;
  final Exercise? exercise;
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final repository = Notebook(widget.store.api!);
  List<LearningNote> notes = [];
  String query = '';
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await repository.notes();
      if (!mounted) return;
      setState(() => notes = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([LearningNote? note]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditor(
          repository: repository,
          note: note,
          exerciseId: widget.exercise?.id,
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> remove(LearningNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: Text('«${note.title}» будет удалена из твоего аккаунта.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await repository.delete(note);
      if (!mounted) return;
      setState(() => notes.removeWhere((n) => n.id == note.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Заметка удалена')));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = notes
        .where(
          (n) =>
              (widget.exercise == null ||
                  n.exerciseId == widget.exercise!.id) &&
              '${n.title} ${n.body}'.toLowerCase().contains(
                query.toLowerCase().trim(),
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заметки'),
        actions: [
          IconButton(
            tooltip: 'Обновить заметки',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                widget.exercise?.title ?? 'Сохрани то, что понял.',
                style: heading(27),
              ),
              const SizedBox(height: 10),
              const Text(
                'Свои объяснения, вопросы и выводы после практики. Заметки видны только тебе.',
                style: TextStyle(color: muted, height: 1.6),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                'Новая заметка',
                icon: Icons.add,
                onPressed: loading ? null : () => edit(),
              ),
              const SizedBox(height: 20),
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  labelText: 'Поиск по заметкам',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 20),
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                ErrorNotice(message: error!, retry: loading ? null : load),
              if (!loading && error == null && filtered.isEmpty)
                EmptyNotice(
                  icon: Icons.edit_note,
                  title: query.isEmpty
                      ? 'Здесь будут твои открытия'
                      : 'Ничего не нашлось',
                  body: query.isEmpty
                      ? 'Создай первую заметку. Её можно связать с заданием и дополнить позже.'
                      : 'Попробуй другое слово.',
                ),
              for (final note in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    onTap: loading ? null : () => edit(note),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(note.title, style: heading(18)),
                            ),
                            IconButton(
                              tooltip: 'Удалить заметку',
                              onPressed: loading ? null : () => remove(note),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        Text(
                          note.body,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 14),
                        if (note.exerciseId != null)
                          Text(
                            exercises
                                    .where((e) => e.id == note.exerciseId)
                                    .map((e) => '${e.language} · ${e.title}')
                                    .firstOrNull ??
                                'Задание',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'Изменено ${shortDate(note.updatedAt)}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.repository,
    this.note,
    this.exerciseId,
  });
  final Notebook repository;
  final LearningNote? note;
  final String? exerciseId;
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final title = TextEditingController(text: widget.note?.title ?? '');
  late final body = TextEditingController(text: widget.note?.body ?? '');
  late String? exerciseId = widget.note?.exerciseId ?? widget.exerciseId;
  late final id = widget.note?.id ?? ProgressStore.newRequestId();
  final form = GlobalKey<FormState>();
  bool busy = false, allowLeave = false;
  String? error;
  bool get dirty =>
      title.text != (widget.note?.title ?? '') ||
      body.text != (widget.note?.body ?? '') ||
      exerciseId != (widget.note?.exerciseId ?? widget.exerciseId);
  @override
  void initState() {
    super.initState();
    title.addListener(changed);
    body.addListener(changed);
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (busy) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Выйти без сохранения?'),
        content: const Text('Изменения в этой заметке будут потеряны.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Продолжить редактирование'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => allowLeave = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.save(
        id: id,
        title: title.text,
        body: body.text,
        exerciseId: exerciseId,
        revision: widget.note?.revision,
      );
      if (!mounted) return;
      setState(() {
        allowLeave = true;
        busy = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Заметка сохранена')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowLeave || (!dirty && !busy),
    onPopInvokedWithResult: (popped, _) {
      if (!popped && !busy) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.note == null ? 'Новая заметка' : 'Редактировать заметку',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('note-title'),
                    controller: title,
                    enabled: !busy,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Заголовок',
                      hintText: 'Например, границы массива',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Добавь заголовок' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: exerciseId ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Связать с заданием',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Общая заметка'),
                      ),
                      for (final e in exercises)
                        DropdownMenuItem(
                          value: e.id,
                          child: Text(
                            '${e.language} · ${e.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) =>
                              setState(() => exerciseId = v == '' ? null : v),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    key: const ValueKey('note-body'),
                    controller: body,
                    enabled: !busy,
                    minLines: 7,
                    maxLines: 15,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Текст заметки',
                      alignLabelWithHint: true,
                      hintText: 'Что вызвало ошибку? Как её избежать в следующий раз?',
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Добавь текст заметки' : null,
                  ),
                  if (error != null) ErrorNotice(message: error!),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    busy ? 'Сохраняем…' : 'Сохранить заметку',
                    icon: Icons.check,
                    onPressed:
                        busy ||
                            title.text.trim().isEmpty ||
                            body.text.trim().isEmpty
                        ? null
                        : save,
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

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.store});
  final ProgressStore store;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final List<AttemptRecord> items = [];
  int total = 0;
  bool loading = true;
  String? error;
  String filter = 'Все';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Notebook(widget.store.api!)
          .history(more ? items.length : 0);
      if (!mounted) return;
      setState(() {
        if (!more) items.clear();
        // Concurrent attempts may shift offset pages; display each attempt once.
        final known = items.map((e) => e.id).toSet();
        items.addAll(result.items.where((e) => known.add(e.id)));
        total = result.total;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = items.where(
      (a) => filter == 'Все' || (filter == 'Верные') == a.correct,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('История попыток'),
        actions: [
          IconButton(
            tooltip: 'Обновить историю',
            onPressed: loading ? null : () => load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text('Каждая попытка — опыт.', style: heading(27)),
              const SizedBox(height: 10),
              Text(
                'Всего попыток: $total. Время показано в часовом поясе устройства.',
                style: const TextStyle(color: muted, height: 1.6),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in ['Все', 'Верные', 'Ошибки'])
                    ChoiceChip(
                      label: Text(item),
                      selected: filter == item,
                      onSelected: (_) => setState(() => filter = item),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                ErrorNotice(
                  message: error!,
                  retry: loading ? null : () => load(),
                ),
              if (!loading && error == null && shown.isEmpty)
                EmptyNotice(
                  icon: Icons.history,
                  title: items.isEmpty
                      ? 'Практика начинается с попытки'
                      : 'Нет попыток с этим результатом',
                  body: items.isEmpty
                      ? 'Реши задание — здесь появятся выбранная строка, результат и полученные XP.'
                      : 'Измени фильтр или загрузи более ранние попытки.',
                ),
              for (final attempt in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Tag(attempt.language),
                            Tag(
                              attempt.correct ? 'Верно' : 'Попробуй ещё',
                              color: attempt.correct
                                  ? mint
                                  : const Color(0xFFFFC78D),
                            ),
                            if (attempt.xp > 0)
                              Tag('+${attempt.xp} XP', color: mint),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(attempt.title, style: heading(18)),
                        const SizedBox(height: 8),
                        Text(
                          'Строка ${attempt.line} · ${shortDate(attempt.createdAt)}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            final exercise = exercises
                                .where((e) => e.id == attempt.exerciseId)
                                .firstOrNull;
                            if (exercise != null) {
                              openExercise(context, widget.store, exercise);
                            }
                          },
                          icon: const Icon(Icons.replay),
                          label: const Text('Повторить задание'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (items.length < total)
                OutlinedButton(
                  onPressed: loading ? null : () => load(more: true),
                  child: const Text('Загрузить ещё'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyNotice extends StatelessWidget {
  const EmptyNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: heading(20)),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.6),
        ),
      ],
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (retry != null)
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
      ],
    ),
  );
}
