import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class NoteService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUserId => _auth.currentUser?.uid;

  // ============ CHUNG CHO CẢ NOTE VÀ TODO ============

  static Future<bool> addNote({
    required String title,
    required String content,
    bool hasNotification = false,
    DateTime? notificationDate,
    bool isRecurring = false,
    List<int> recurringDays = const [],
    bool isNote = true, // true = Note, false = Todo
  }) async {
    try {
      if (currentUserId == null) return false;

      final note = {
        'userId': currentUserId,
        'title': title,
        'content': content,
        'hasNotification': hasNotification,
        'notificationDate': notificationDate,
        'isRecurring': isRecurring,
        'recurringDays': recurringDays,
        'isNote': isNote,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('notes').add(note);
      return true;
    } catch (e) {
      debugPrint('Error adding note: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllNotes() async {
    try {
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: currentUserId)
          .where('isNote', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error getting notes: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllTodos() async {
    try {
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: currentUserId)
          .where('isNote', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error getting todos: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getNotesWithNotification() async {
    try {
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: currentUserId)
          .where('isNote', isEqualTo: true)
          .where('hasNotification', isEqualTo: true)
          .orderBy('notificationDate')
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error getting notes with notification: $e');
      return [];
    }
  }

  static Future<bool> deleteNote(String noteId) async {
    try {
      // Xóa note/todo
      await _firestore.collection('notes').doc(noteId).delete();

      // Nếu là todo, xóa luôn tất cả completion
      await _firestore
          .collection('todo_completions')
          .where('todoId', isEqualTo: noteId)
          .get()
          .then((snapshot) {
            for (var doc in snapshot.docs) {
              doc.reference.delete();
            }
          });

      return true;
    } catch (e) {
      debugPrint('Error deleting note: $e');
      return false;
    }
  }

  static Future<bool> updateNote({
    required String noteId,
    String? title,
    String? content,
    bool? hasNotification,
    DateTime? notificationDate,
    bool? isRecurring,
    List<int>? recurringDays,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (title != null) updateData['title'] = title;
      if (content != null) updateData['content'] = content;
      if (hasNotification != null)
        updateData['hasNotification'] = hasNotification;
      if (notificationDate != null)
        updateData['notificationDate'] = notificationDate;
      if (isRecurring != null) updateData['isRecurring'] = isRecurring;
      if (recurringDays != null) updateData['recurringDays'] = recurringDays;

      if (updateData.isNotEmpty) {
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('notes').doc(noteId).update(updateData);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating note: $e');
      return false;
    }
  }

  static Stream<List<Map<String, dynamic>>> watchAllNotes() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notes')
        .where('userId', isEqualTo: currentUserId)
        .where('isNote', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  static Stream<List<Map<String, dynamic>>> watchAllTodos() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('notes')
        .where('userId', isEqualTo: currentUserId)
        .where('isNote', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  static Future<Map<String, dynamic>?> getNoteById(String noteId) async {
    try {
      final doc = await _firestore.collection('notes').doc(noteId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      debugPrint('Error getting note by id: $e');
      return null;
    }
  }

  // ============ PHẦN XỬ LÝ HOÀN THÀNH TODO ============

  /// Đánh dấu todo hoàn thành cho một ngày cụ thể
  static Future<bool> completeTodo({
    required String todoId,
    required DateTime completedDate,
  }) async {
    try {
      if (currentUserId == null) return false;

      // Chuẩn hóa ngày về 00:00:00
      final normalizedDate = DateTime(
        completedDate.year,
        completedDate.month,
        completedDate.day,
      );

      // Kiểm tra xem đã hoàn thành ngày này chưa
      final existing = await _firestore
          .collection('todo_completions')
          .where('todoId', isEqualTo: todoId)
          .where('completedDate', isEqualTo: Timestamp.fromDate(normalizedDate))
          .get();

      if (existing.docs.isNotEmpty) {
        debugPrint('Todo already completed for this date');
        return true;
      }

      // Thêm completion mới
      await _firestore.collection('todo_completions').add({
        'todoId': todoId,
        'completedDate': Timestamp.fromDate(normalizedDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error completing todo: $e');
      return false;
    }
  }

  /// Bỏ đánh dấu hoàn thành cho một ngày cụ thể
  static Future<bool> uncompleteTodo({
    required String todoId,
    required DateTime completedDate,
  }) async {
    try {
      // Chuẩn hóa ngày
      final normalizedDate = DateTime(
        completedDate.year,
        completedDate.month,
        completedDate.day,
      );

      // Tìm và xóa completion
      final snapshot = await _firestore
          .collection('todo_completions')
          .where('todoId', isEqualTo: todoId)
          .where('completedDate', isEqualTo: Timestamp.fromDate(normalizedDate))
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error uncompleting todo: $e');
      return false;
    }
  }

  /// Kiểm tra todo đã hoàn thành cho ngày cụ thể chưa
  static Future<bool> isTodoCompleted({
    required String todoId,
    required DateTime date,
  }) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);

      final snapshot = await _firestore
          .collection('todo_completions')
          .where('todoId', isEqualTo: todoId)
          .where('completedDate', isEqualTo: Timestamp.fromDate(normalizedDate))
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking todo completion: $e');
      return false;
    }
  }

  /// Lấy tất cả các ngày đã hoàn thành của một todo
  static Future<List<DateTime>> getTodoCompletedDates(String todoId) async {
    try {
      final snapshot = await _firestore
          .collection('todo_completions')
          .where('todoId', isEqualTo: todoId)
          .orderBy('completedDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => (doc.data()['completedDate'] as Timestamp).toDate())
          .toList();
    } catch (e) {
      debugPrint('Error getting completed dates: $e');
      return [];
    }
  }

  /// Lấy số lần hoàn thành của todo trong khoảng thời gian
  static Future<int> getTodoCompletionCount({
    required String todoId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('todo_completions')
          .where('todoId', isEqualTo: todoId);

      if (startDate != null) {
        final normalizedStart = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        query = query.where(
          'completedDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedStart),
        );
      }

      if (endDate != null) {
        final normalizedEnd = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        query = query.where(
          'completedDate',
          isLessThanOrEqualTo: Timestamp.fromDate(normalizedEnd),
        );
      }

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting completion count: $e');
      return 0;
    }
  }

  /// Stream theo dõi trạng thái hoàn thành của todo cho một ngày
  static Stream<bool> watchTodoCompletion({
    required String todoId,
    required DateTime date,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    return _firestore
        .collection('todo_completions')
        .where('todoId', isEqualTo: todoId)
        .where('completedDate', isEqualTo: Timestamp.fromDate(normalizedDate))
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// Lấy tất cả todo completions trong khoảng thời gian
  static Future<Map<String, List<DateTime>>> getTodosCompletionMap({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (currentUserId == null) return {};

      // Lấy tất cả todos của user
      final todosSnapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: currentUserId)
          .where('isNote', isEqualTo: false)
          .get();

      final Map<String, List<DateTime>> completionMap = {};

      for (var todoDoc in todosSnapshot.docs) {
        final todoId = todoDoc.id;
        Query query = _firestore
            .collection('todo_completions')
            .where('todoId', isEqualTo: todoId);

        if (startDate != null) {
          final normalizedStart = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          query = query.where(
            'completedDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedStart),
          );
        }

        if (endDate != null) {
          final normalizedEnd = DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
            23,
            59,
            59,
          );
          query = query.where(
            'completedDate',
            isLessThanOrEqualTo: Timestamp.fromDate(normalizedEnd),
          );
        }

        final completionSnapshot = await query.get();
        final dates = completionSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['completedDate'] as Timestamp).toDate();
        }).toList();

        if (dates.isNotEmpty) {
          completionMap[todoId] = dates;
        }
      }

      return completionMap;
    } catch (e) {
      debugPrint('Error getting todos completion map: $e');
      return {};
    }
  }
}
