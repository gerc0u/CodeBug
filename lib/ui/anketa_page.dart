import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/anketa_file.dart';
import '../models/anketa.dart';
import 'design.dart';

class AnketaPage extends StatefulWidget {
  const AnketaPage({
    super.key,
    this.initialName = '',
    this.initialEmail = '',
    this.save = saveAnketa,
  });

  final String initialName, initialEmail;
  final Future<String> Function(AnketaData) save;

  @override
  State<AnketaPage> createState() => _AnketaPageState();
}

class _AnketaPageState extends State<AnketaPage> {
  var _form = GlobalKey<FormState>();
  late final TextEditingController _name, _email;
  final _age = TextEditingController(), _phone = TextEditingController();
  bool _saving = false;
  String? _savedPath, _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _email = TextEditingController(text: widget.initialEmail);
    for (final controller in [_name, _age, _email, _phone]) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    setState(() {});
  }

  bool get _valid =>
      AnketaData.validateName(_name.text) == null &&
      AnketaData.validateAge(_age.text) == null &&
      AnketaData.validateEmail(_email.text) == null &&
      AnketaData.validatePhone(_phone.text) == null;

  @override
  void dispose() {
    for (final controller in [_name, _age, _email, _phone]) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final data = AnketaData.fromInput(
      name: _name.text,
      age: _age.text,
      email: _email.text,
      phone: _phone.text,
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final path = await widget.save(data);
      if (!mounted) return;
      setState(() => _savedPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Файл anketa.txt передан браузеру для скачивания.'
                : 'Данные успешно сохранены!',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Не удалось сохранить файл. Проверь свободное место и доступ к папке, затем повтори. Данные остались в форме.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clear() {
    if (_saving) return;
    for (final controller in [_name, _age, _email, _phone]) {
      controller.clear();
    }
    setState(() {
      _form = GlobalKey<FormState>();
      _error = null;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Анкета')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Твои данные', style: heading(30)),
                const SizedBox(height: 12),
                const Text(
                  'Заполни все поля, чтобы сохранить анкету в текстовый файл.',
                  style: TextStyle(color: muted, height: 1.6),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('anketa-name'),
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    hintText: 'Иван Иванов',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: AnketaData.validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('anketa-age'),
                  controller: _age,
                  enabled: !_saving,
                  maxLength: 3,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Возраст',
                    hintText: '25',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  validator: AnketaData.validateAge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('anketa-email'),
                  controller: _email,
                  enabled: !_saving,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'ivan@mail.com',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: AnketaData.validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('anketa-phone'),
                  controller: _phone,
                  enabled: !_saving,
                  maxLength: 32,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+77001234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: AnketaData.validatePhone,
                  onFieldSubmitted: (_) {
                    if (_valid) _save();
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('anketa-save'),
                  onPressed: _valid && !_saving ? _save : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Сохранение…' : 'Сохранить данные'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('anketa-clear'),
                  onPressed: _saving ? null : _clear,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Очистить форму'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        height: 1.5,
                      ),
                    ),
                  ),
                if (_savedPath != null) ...[
                  const SizedBox(height: 16),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kIsWeb
                              ? 'Файл подготовлен'
                              : 'Данные успешно сохранены!',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          _savedPath!,
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                        if (!kIsWeb)
                          TextButton.icon(
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Скопировать путь'),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: _savedPath!),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Путь скопирован'),
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  kIsWeb
                      ? 'Браузер скачает anketa.txt в выбранную папку. Каждое скачивание содержит одну анкету.'
                      : 'Каждое сохранение добавляет запись в anketa.txt в папке документов приложения. Очистка формы не удаляет сохранённые записи.',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Анкета хранится на устройстве и не отправляется на сервер.',
                  style: TextStyle(color: muted, fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
