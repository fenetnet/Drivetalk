import '../domain/models.dart';
import 'observable.dart';

/// The signed-in user's profile and preferences.
abstract class ProfileService implements ObservableService {
  Person get me;
  MyPreferences get prefs;
  Future<void> updateMe(Person me);
  Future<void> updatePrefs(MyPreferences prefs);
}
