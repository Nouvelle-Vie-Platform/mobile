/// Modèles de données simples (immuables) servant à alimenter les écrans.
library;

class ChurchEvent {
  const ChurchEvent({
    required this.title,
    required this.day,
    required this.month,
    required this.time,
    required this.place,
    this.tag,
  });

  final String title;
  final String day;
  final String month;
  final String time;
  final String place;
  final String? tag;
}

class Teaching {
  const Teaching({
    required this.title,
    required this.author,
    required this.duration,
    this.seed = 0,
  });

  final String title;
  final String author;
  final String duration;
  final int seed;
}

class CommunityGroup {
  const CommunityGroup({
    required this.name,
    required this.members,
    this.role,
  });

  final String name;
  final int members;
  final String? role;
}

class PrayerRequest {
  const PrayerRequest({
    required this.title,
    required this.body,
    required this.status,
    required this.prayingCount,
    required this.age,
    this.confidential = true,
  });

  final String title;
  final String body;
  final String status;
  final int prayingCount;
  final String age;
  final bool confidential;
}

class SpiritualNote {
  const SpiritualNote({required this.title, required this.preview});
  final String title;
  final String preview;
}

class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    required this.time,
    required this.mine,
    this.system = false,
  });

  final String author;
  final String text;
  final String time;
  final bool mine;
  final bool system;
}
