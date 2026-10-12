import '../data/api.dart';

class LearningNote {
  LearningNote.fromJson(Map<String, dynamic> data)
    : id = data['id'],
      title = data['title'],
      body = data['body'],
      exerciseId = data['exercise_id'],
      revision = data['revision'],
      updatedAt = DateTime.fromMillisecondsSinceEpoch(
        data['updated_at'] * 1000,
      );
  final String id, title, body;
  final String? exerciseId;
  final int revision;
  final DateTime updatedAt;
}

class AttemptRecord {
  AttemptRecord.fromJson(Map<String, dynamic> data)
    : id = data['id'],
      exerciseId = data['exercise_id'],
      title = data['title'],
      language = data['language'],
      line = data['line'],
      correct = data['correct'],
      xp = data['awarded_xp'],
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        data['created_at'] * 1000,
      );
  final String id, exerciseId, title, language;
  final int line, xp;
  final bool correct;
  final DateTime createdAt;
}

class Notebook {
  Notebook(this.api);
  final CodeBugApi api;
  Future<List<LearningNote>> notes() async =>
      (await api.request('GET', '/notes') as List)
          .map((e) => LearningNote.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  Future<LearningNote> save({
    required String id,
    required String title,
    required String body,
    String? exerciseId,
    int? revision,
  }) async {
    final data = await api.request(
      revision == null ? 'POST' : 'PATCH',
      revision == null ? '/notes' : '/notes/$id',
      {
        if (revision == null) 'id': id else 'revision': revision,
        'title': title.trim(),
        'body': body.trim(),
        'exercise_id': exerciseId,
      },
    );
    return LearningNote.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> delete(LearningNote note) async =>
      api.request('DELETE', '/notes/${note.id}?revision=${note.revision}');

  Future<({List<AttemptRecord> items, int total})> history(int offset) async {
    final data = await api.request('GET', '/history?offset=$offset&limit=30');
    return (
      items: (data['items'] as List)
          .map((e) => AttemptRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: data['total'] as int,
    );
  }
}
