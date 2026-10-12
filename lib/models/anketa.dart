/// The text format follows the assignment: four labeled lines and a separator.
class AnketaData {
  const AnketaData._(this.name, this.age, this.email, this.phone);

  factory AnketaData.fromInput({
    required String name,
    required String age,
    required String email,
    required String phone,
  }) {
    final errors = [
      validateName(name),
      validateAge(age),
      validateEmail(email),
      validatePhone(phone),
    ];
    if (errors.any((error) => error != null)) {
      throw const FormatException('Проверь поля анкеты');
    }
    return AnketaData._(
      name.trim(),
      int.parse(age.trim()),
      email.trim(),
      phone.trim().replaceAll(RegExp(r'[ ()-]'), ''),
    );
  }

  final String name, email, phone;
  final int age;

  static bool _hasControlCharacters(String value) =>
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(value);

  static String? validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Укажи имя';
    if (text.length > 80) return 'Имя должно быть не длиннее 80 символов';
    if (_hasControlCharacters(value!)) return 'Введи имя одной строкой';
    return null;
  }

  static String? validateAge(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Укажи возраст';
    final age = int.tryParse(text);
    if (!RegExp(r'^\d{1,3}$').hasMatch(text) ||
        age == null ||
        age < 1 ||
        age > 120) {
      return 'Введи целое число от 1 до 120';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Укажи email';
    if (text.length > 254 ||
        _hasControlCharacters(value!) ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'Укажи корректный email, например ivan@mail.com';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Укажи номер телефона';
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_hasControlCharacters(value!) ||
        !RegExp(r'^\+?[0-9 ()-]+$').hasMatch(text) ||
        digits.length < 10 ||
        digits.length > 15) {
      return 'Нужно 10–15 цифр, например +77001234567';
    }
    return null;
  }

  String toText() =>
      'Имя: $name\nВозраст: $age\nEmail: $email\nТелефон: $phone\n---\n';
}
