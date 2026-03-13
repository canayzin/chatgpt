class AnalyticsEvent {
  const AnalyticsEvent({
    required this.userId,
    required this.eventType,
    required this.timestamp,
    required this.sessionId,
    required this.deviceInfo,
    this.contentId,
    this.category,
    this.properties = const {},
    this.eventId,
  });

  final String userId;
  final String eventType;
  final String? contentId;
  final String? category;
  final DateTime timestamp;
  final String sessionId;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> properties;
  final String? eventId;

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'eventType': eventType,
      'contentId': contentId,
      'category': category,
      'timestamp': timestamp.toUtc(),
      'sessionId': sessionId,
      'deviceInfo': deviceInfo,
      'properties': properties,
      'eventId': eventId,
    };
  }
}
