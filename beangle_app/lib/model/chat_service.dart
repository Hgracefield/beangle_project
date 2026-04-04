import 'package:beangle_app/settings/firebase_bootstrap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  ChatService._();

  static const String roomCollection = 'chat_rooms';
  static const String adminParticipantId = 'admin';
  static const String _userRole = 'user';
  static const String _adminRole = 'admin';

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
      'lastSenderRole': '',
      'unreadCounts': <String, int>{_userRole: 0, _adminRole: 0},
      'userUnreadCount': 0,
      'adminUnreadCount': 0,
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

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(
    String roomId,
  ) {
    _assertReady();

    return _firestore.collection(roomCollection).doc(roomId).snapshots();
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

    final DocumentReference<Map<String, dynamic>> roomRef = _firestore
        .collection(roomCollection)
        .doc(roomId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> roomSnapshot =
          await transaction.get(roomRef);
      final Map<String, dynamic>? roomData = roomSnapshot.data();

      final int nextUserUnreadCount = senderRole == _adminRole
          ? unreadCountForRole(roomData, _userRole) + 1
          : 0;
      final int nextAdminUnreadCount = senderRole == _userRole
          ? unreadCountForRole(roomData, _adminRole) + 1
          : 0;

      transaction.set(roomRef, <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': trimmed,
        'lastSenderId': senderId,
        'lastSenderName': senderName,
        'lastSenderRole': senderRole,
        'unreadCounts': <String, int>{
          _userRole: nextUserUnreadCount,
          _adminRole: nextAdminUnreadCount,
        },
        'userUnreadCount': nextUserUnreadCount,
        'adminUnreadCount': nextAdminUnreadCount,
      }, SetOptions(merge: true));
    });
  }

  static int unreadCountForRole(Map<String, dynamic>? data, String role) {
    if (data == null) {
      return 0;
    }

    final dynamic unreadCounts = data['unreadCounts'];
    if (unreadCounts is Map) {
      final dynamic count = unreadCounts[role];
      final int? parsed = int.tryParse(count?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }

    final String camelKey = '${role}UnreadCount';
    final String pascalKey =
        '${role[0].toUpperCase()}${role.substring(1)}UnreadCount';
    return int.tryParse(
          data[camelKey]?.toString() ?? data[pascalKey]?.toString() ?? '',
        ) ??
        0;
  }

  static Future<void> markRoomRead({
    required String roomId,
    required String role,
  }) async {
    _assertReady();

    final String legacyKey = '${role}UnreadCount';
    await _firestore.collection(roomCollection).doc(roomId).set(
      <String, dynamic>{
        'unreadCounts': <String, int>{role: 0},
        legacyKey: 0,
      },
      SetOptions(merge: true),
    );
  }

  static void _assertReady() {
    if (!isAvailable) {
      throw StateError(
        FirebaseBootstrap.errorMessage ?? 'Firebase is not initialized.',
      );
    }
  }
}
