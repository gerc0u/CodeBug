class Exercise {
  Exercise(
    this.id,
    this.language,
    this.title,
    this.topic,
    this.level,
    this.minutes,
    this.description,
    this.code,
    this.errorLine,
    this.hint,
    this.explanation,
    this.correctedLine,
  );
  final String id, language, title, topic, description, hint;
  String explanation, correctedLine;
  int errorLine;
  final int level, minutes;
  final List<String> code;
  factory Exercise.fromJson(Map<String, dynamic> data) => Exercise(
    data['id'],
    data['language'],
    data['title'],
    data['topic'],
    data['level'],
    data['minutes'],
    data['description'],
    List<String>.from(data['code']),
    0,
    data['hint'],
    '',
    '',
  );
  void applySolution(Map<String, dynamic> data) {
    errorLine = data['errorLine'];
    explanation = data['explanation'];
    correctedLine = data['correctedLine'];
  }

  int get xp => level * 15 + 10;
  String get difficulty => ['Легко', 'Средне', 'Сложно'][level - 1];
  List<String> get correctedCode => [
    for (var i = 0; i < code.length; i++)
      i == errorLine - 1 ? correctedLine : code[i],
  ];
}

final exercises = <Exercise>[];

class Lesson {
  const Lesson(this.title, this.subtitle, this.body, this.example, this.topic);
  final String title, subtitle, body, example, topic;
}

const lessons = [
  Lesson(
    'Границы имеют значение',
    'Циклы и индексы · 3 минуты',
    'Первый индекс списка — 0, последний — length − 1. Ошибка на единицу возникает, когда цикл захватывает лишний элемент или пропускает последний.\n\nПри обходе по индексам обычно нужно условие i < length. Если индекс не нужен, используй for-in: это уменьшает число мест, где можно ошибиться.\n\nПеред проверкой мысленно выполни код для пустого списка, одного элемента и последнего элемента. В Python правая граница range также не включается.',
    'for (final language in languages) {\n  print(language);\n}',
    'Циклы и коллекции',
  ),
  Lesson(
    'Null — тоже значение',
    'Безопасность в Dart · 4 минуты',
    'String хранит строку, а String? — строку или null. Система типов заставляет обработать отсутствие значения до его использования.\n\nОператор ?. вызывает метод только для ненулевого значения. Оператор ?? подставляет запасное значение. Оператор ! не проверяет значение заранее: он утверждает, что null нет, и приводит к ошибке во время выполнения, если это не так.\n\nСначала выбери поведение для отсутствующих данных, затем выражай его явно в коде.',
    "String? name;\nfinal label = name?.trim() ?? 'Гость';",
    'Null safety',
  ),
  Lesson(
    'Почему «100» + 20 ≠ 120',
    'Преобразование типов · 3 минуты',
    'Внешние данные часто приходят строками. В JavaScript оператор + складывает числа, но склеивает строки. Преобразование должно предшествовать вычислению.\n\nВ Java деление двух int отбрасывает дробную часть ещё до присваивания double. Преобразуй один из операндов до деления.\n\nВсегда проверяй входные значения. Number("hello") вернёт NaN: явное преобразование само по себе не гарантирует корректные данные.',
    'const price = Number(input);\nif (Number.isFinite(price)) {\n  console.log(price + 20);\n}',
    'Типы данных',
  ),
  Lesson(
    'Не торопи Future',
    'Асинхронность · 4 минуты',
    'Асинхронная операция возвращает обещание будущего результата: Future в Dart или Promise в JavaScript. Это ещё не само значение.\n\nawait получает результат после завершения операции, приостанавливая текущую async-функцию. Остальная программа может продолжать работу.\n\nОшибки асинхронных операций обрабатывай с try/catch вокруг await. Не забывай про состояние загрузки, если результат показывается в интерфейсе.',
    'try {\n  final data = await load();\n  print(data);\n} catch (error) {\n  print(error);\n}',
    'Асинхронность',
  ),
  Lesson(
    'Функции без сюрпризов',
    'return и состояние · 4 минуты',
    'return завершает всю функцию, даже если находится внутри цикла. Когда нужно накопить результат, возвращай его после завершения обхода.\n\nВ Python отступы определяют структуру программы. Один лишний уровень отступа может превратить корректный алгоритм в преждевременный выход.\n\nИзменяемые аргументы по умолчанию создаются один раз. Используй None и создавай новый список внутри функции, чтобы вызовы не делили состояние.',
    'def total(numbers):\n    result = 0\n    for number in numbers:\n        result += number\n    return result',
    'Функции',
  ),
  Lesson(
    'Условия и сравнения',
    'Логика и строки · 3 минуты',
    'Оператор И (&&) требует истинности обоих условий. Оператор ИЛИ (||) — хотя бы одного. Для попадания в диапазон нужны сразу нижняя и верхняя границы.\n\nВ Java == сравнивает ссылки объектов, а equals — их содержимое. Две отдельные строки с одинаковым текстом могут иметь разные ссылки.\n\nПроверяй условия на граничных значениях и на значениях за пределами диапазона.',
    'boolean allowed = age >= 18 && age <= 65;\nboolean admin = "admin".equals(name);',
    'Логика',
  ),
];
