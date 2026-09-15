import 'package:beangle_app/settings/firebase_bootstrap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  ChatService._();

  static const String roomCollection = 'chat_rooms';
  static const String adminParticipantId = 'admin';

  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static bool get isAvailable => FirebaseBootstrap.isReady;

  static String roomIdForUser(String userId) => 'user_$userId';

  static Future<String> ensureUserRoom({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    _assertReady();

    final String roomId = roomIdForUser(userId);
    final DocumentReference<Map<String, dynamic>> roomRef = _firestore
        .collection(roomCollection)
        .doc(roomId);

    await roomRef.set(<String, dynamic>{
      'roomId': roomId,
      'userId': userId,
      'userName': userName.isEmpty ? '사용자 $userId' : userName,
      'userEmail': userEmail,
      'participants': <String>['user_$userId', adminParticipantId],
      'participantRoles': <String>['user', 'admin'],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastSenderId': '',
      'lastSenderName': '',
      'isClosed': false,
    }, SetOptions(merge: true));

    return roomId;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchRooms() {
    _assertReady();

    return _firestore
        .collection(roomCollection)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
    String roomId,
  ) {
    _assertReady();

    return _firestore
        .collection(roomCollection)
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  static Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
  }) async {
    _assertReady();

    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final CollectionReference<Map<String, dynamic>> messagesRef = _firestore
        .collection(roomCollection)
        .doc(roomId)
        .collection('messages');

    await messagesRef.add(<String, dynamic>{
      'text': trimmed,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore
        .collection(roomCollection)
        .doc(roomId)
        .set(<String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': trimmed,
          'lastSenderId': senderId,
          'lastSenderName': senderName,
        }, SetOptions(merge: true));
  }

  static void _assertReady() {
    if (!isAvailable) {
      throw StateError(
        FirebaseBootstrap.errorMessage ?? 'Firebase is not initialized.',
      );
    }
  }
}
