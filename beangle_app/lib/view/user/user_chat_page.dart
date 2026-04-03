import 'dart:async';

import 'package:beangle_app/model/chat_service.dart';
import 'package:beangle_app/settings/firebase_bootstrap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserChatPage extends StatefulWidget {
  const UserChatPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  final String userId;
  final String userName;
  final String userEmail;

  @override
  State<UserChatPage> createState() => _UserChatPageState();
}

class _UserChatPageState extends State<UserChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _roomSubscription;

  String? _roomId;
  String? _errorMessage;
  bool _isPreparing = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _prepareRoom();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _prepareRoom() async {
    if (!FirebaseBootstrap.isReady) {
      setState(() {
        _isPreparing = false;
        _errorMessage =
            FirebaseBootstrap.errorMessage ??
            'Firebase 설정이 완료되지 않아 채팅을 사용할 수 없습니다.';
      });
      return;
    }

    try {
      final String roomId = await ChatService.ensureUserRoom(
        userId: widget.userId,
        userName: widget.userName,
        userEmail: widget.userEmail,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _roomId = roomId;
        _isPreparing = false;
      });
      _startReadSync(roomId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _errorMessage = '채팅방을 준비하지 못했습니다.\n$error';
      });
    }
  }

  void _startReadSync(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = ChatService.watchRoom(roomId).listen((snapshot) {
      final Map<String, dynamic>? data = snapshot.data();
      if (ChatService.unreadCountForRole(data, 'user') > 0) {
        ChatService.markRoomRead(roomId: roomId, role: 'user');
      }
    });
  }

  String _formatMessageTime(dynamic rawTimestamp) {
    final Timestamp? timestamp = rawTimestamp as Timestamp?;
    if (timestamp == null) {
      return '';
    }

    final DateTime sentAt = timestamp.toDate().toLocal();
    final DateTime now = DateTime.now();
    final String month = sentAt.month.toString().padLeft(2, '0');
    final String day = sentAt.day.toString().padLeft(2, '0');
    final String hour = sentAt.hour.toString().padLeft(2, '0');
    final String minute = sentAt.minute.toString().padLeft(2, '0');

    if (sentAt.year == now.year &&
        sentAt.month == now.month &&
        sentAt.day == now.day) {
      return '$hour:$minute';
    }

    return '$month/$day $hour:$minute';
  }

  DateTime? _messageDate(dynamic rawTimestamp) {
    final Timestamp? timestamp = rawTimestamp as Timestamp?;
    return timestamp?.toDate().toLocal();
  }

  bool _shouldShowDateDivider({
    required List docs,
    required int index,
  }) {
    final DateTime? current = _messageDate(docs[index].data()['createdAt']);
    if (current == null) {
      return false;
    }

    if (index == 0) {
      return true;
    }

    final DateTime? previous = _messageDate(docs[index - 1].data()['createdAt']);
    if (previous == null) {
      return true;
    }

    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  String _formatDateDivider(dynamic rawTimestamp) {
    final DateTime? date = _messageDate(rawTimestamp);
    if (date == null) {
      return '';
    }

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(date.year, date.month, date.day);
    final int difference = today.difference(target).inDays;

    if (difference == 0) {
      return '오늘';
    }

    if (difference == 1) {
      return '어제';
    }

    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  Future<void> _sendMessage() async {
    final String? roomId = _roomId;
    if (roomId == null || _isSending) {
      return;
    }

    final String text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await ChatService.sendMessage(
        roomId: roomId,
        senderId: 'user_${widget.userId}',
        senderName: widget.userName.isEmpty
            ? '사용자 ${widget.userId}'
            : widget.userName,
        senderRole: 'user',
        text: text,
      );
      _messageController.clear();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('메시지를 전송하지 못했습니다. $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bubbleBackground = const Color(0xFFE8F3E2);
    final Color surfaceColor = const Color(0xFFF7FBF4);
    final Color accentColor = const Color(0xFF49992E);
    final Color textColor = const Color(0xFF1F3516);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        title: const Text('관리자와 채팅'),
      ),
      body: _isPreparing
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, height: 1.5),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Container(
                    color: surfaceColor,
                    child: StreamBuilder(
                      stream: ChatService.watchMessages(_roomId!),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '메시지를 불러오지 못했습니다.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('관리자에게 첫 메시지를 보내보세요.'),
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.jumpTo(
                              _scrollController.position.maxScrollExtent,
                            );
                          }
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final bool isMine =
                                data['senderRole']?.toString() == 'user';
                            final String sentTime = _formatMessageTime(
                              data['createdAt'],
                            );
                            final bool showDateDivider = _shouldShowDateDivider(
                              docs: docs,
                              index: index,
                            );
                            final String dateDividerText = _formatDateDivider(
                              data['createdAt'],
                            );

                            return Column(
                              children: [
                                if (showDateDivider && dateDividerText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 14,
                                    ),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          dateDividerText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: textColor.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: isMine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    constraints: const BoxConstraints(
                                      maxWidth: 300,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? accentColor
                                          : bubbleBackground,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['senderName']?.toString() ??
                                              (isMine ? '나' : '관리자'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isMine
                                                ? Colors.white70
                                                : textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['text']?.toString() ?? '',
                                          style: TextStyle(
                                            color: isMine
                                                ? Colors.white
                                                : textColor,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (sentTime.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              sentTime,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isMine
                                                    ? Colors.white70
                                                    : textColor.withValues(
                                                        alpha: 0.65,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x11000000),
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: '관리자에게 문의할 내용을 입력하세요',
                              filled: true,
                              fillColor: surfaceColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _isSending ? null : _sendMessage,
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                            minimumSize: const Size(56, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
