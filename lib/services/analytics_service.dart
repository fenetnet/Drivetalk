/// Privacy-respecting product metrics: counts of meaningful events only.
/// Never location, call content, or contact lists.
class AnalyticsEvent {
  const AnalyticsEvent(this.name, this.at, [this.props = const {}]);
  final String name;
  final DateTime at;
  final Map<String, Object> props;
}

abstract class AnalyticsService {
  void log(String name, [Map<String, Object> props = const {}]);
  List<AnalyticsEvent> get events;
}
