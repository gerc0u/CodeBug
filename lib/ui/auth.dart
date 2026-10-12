import 'package:flutter/material.dart';

import '../models/progress.dart';
import 'design.dart';
import 'anketa_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store});
  final ProgressStore store;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  final form = GlobalKey<FormState>();
  bool registering = false, busy = false, hide = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.signIn(
        email.text,
        password.text,
        displayName: registering ? name.text : null,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.bug_report_outlined,
                      size: 64,
                      color: violet,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'CodeBug',
                      textAlign: TextAlign.center,
                      style: heading(38),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Находи ошибки. Прокачивай навыки.\nСохраняй прогресс в своём аккаунте.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, height: 1.6),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      registering ? 'Создать аккаунт' : 'Войти в аккаунт',
                      style: heading(24),
                    ),
                    const SizedBox(height: 20),
                    if (registering) ...[
                      TextFormField(
                        key: const ValueKey("registration-name"),
                        controller: name,
                        enabled: !busy,
                        maxLength: 24,
                        decoration: const InputDecoration(
                          labelText: 'Имя в рейтинге',
                        ),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Укажи имя' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      key: const ValueKey("account-email"),
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v!.trim())
                          ? null
                          : 'Укажи корректный email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey("account-password"),
                      controller: password,
                      enabled: !busy,
                      obscureText: hide,
                      autofillHints: [
                        registering
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        helperText: 'От 8 до 128 символов',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => hide = !hide),
                          icon: Icon(
                            hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => v!.length < 8 || v.length > 128
                          ? 'Нужно от 8 до 128 символов'
                          : null,
                      onFieldSubmitted: (_) => submit(),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      busy
                          ? 'Подключение…'
                          : registering
                          ? 'Зарегистрироваться'
                          : 'Войти',
                      onPressed: busy ? null : submit,
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              registering = !registering;
                              error = null;
                            }),
                      child: Text(
                        registering
                            ? 'Уже есть аккаунт? Войти'
                            : 'Нет аккаунта? Создать',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const AnketaPage(),
                              ),
                            ),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Анкета без входа'),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Имя и XP видны в рейтинге. Email не публикуется.\nПосле перезапуска потребуется войти снова.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
