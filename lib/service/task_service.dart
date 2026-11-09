import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/task_item.dart';

/// Stores tasks in Firestore under `users/{uid}/tasks`.
class TaskService {
  TaskService._();

  static CollectionReference<Map<String, dynamic>> _collectionFor(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks');

  static CollectionReference<Map<String, dynamic>> _collection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Firebase user is not signed in');
    }
    return _collectionFor(uid);
  }

  /// Live list of the signed-in user's tasks, ordered by start time.
  ///
  /// Follows the Firebase sign-in: Firebase signs in a moment after the
  /// home screen appears, so the list starts once a user is available and
  /// switches (or empties, on sign-out) when the user changes.
  static Stream<List<TaskItem>> watch() {
    StreamSubscription<User?>? authSubscription;
    StreamSubscription<List<TaskItem>>? dataSubscription;
    late final StreamController<List<TaskItem>> controller;

    controller = StreamController<List<TaskItem>>(
      onListen: () {
        authSubscription = FirebaseAuth.instance.authStateChanges().listen((
          user,
        ) {
          dataSubscription?.cancel();
          dataSubscription = null;
          if (user == null) {
            controller.add(const []);
            return;
          }
          dataSubscription = _collectionFor(user.uid)
              .snapshots()
              .map(
                (snapshot) => [
                  for (final doc in snapshot.docs)
                    TaskItem.fromFirestore(doc.id, doc.data()),
                ]..sort((a, b) => a.startAt.compareTo(b.startAt)),
              )
              .listen(controller.add, onError: controller.addError);
        }, onError: controller.addError);
      },
      onCancel: () async {
        await dataSubscription?.cancel();
        await authSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  /// Creates the task when it has no id yet, otherwise replaces it.
  static Future<void> save(TaskItem task) async {
    final collection = _collection();
    if (task.id.isEmpty) {
      await collection.add({
        ...task.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await collection.doc(task.id).set({
        ...task.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  static Future<void> delete(String id) => _collection().doc(id).delete();
}
