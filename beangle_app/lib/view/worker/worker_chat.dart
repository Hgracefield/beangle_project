import 'dart:async';

import 'package:beangle_app/model/chat_service.dart';
import 'package:beangle_app/settings/firebase_bootstrap.dart';
import 'package:beangle_app/view/worker/worker_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WorkerChatPage extends StatefulWidget {
  const WorkerChatPage({
    super.key,
    required this.roomId,
    required this.roomTitle,
    required this.currentSenderId,
    required this.currentSenderName,
  });

  final String roomId;
  final String roomTitle;
  final String currentSenderId;
  final String currentSenderName;

  @override
  State<WorkerChatPage> createState() => _WorkerChatPageState();
}

class _WorkerChatPageState extends State<WorkerChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _roomSubscription;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _startReadSync();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startReadSync() {
    if (!FirebaseBootstrap.isReady) {
      return;
    }

    _roomSubscription = ChatService.watchRoom(widget.roomId).listen((snapshot) {
      final Map<String, dynamic>? data = snapshot.data();
      if (ChatService.unreadCountForRole(data, 'admin') > 0) {
        ChatService.markRoomRead(roomId: widget.roomId, role: 'admin');
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
    if (_isSending || !FirebaseBootstrap.isReady) {
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
        roomId: widget.roomId,
        senderId: widget.currentSenderId,
        senderName: widget.currentSenderName,
        senderRole: 'admin',
        text: text,
      );
      _messageController.clear();
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
    if (!FirebaseBootstrap.isReady) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: workerThemeColor,
          foregroundColor: Colors.white,
          title: Text(widget.roomTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              FirebaseBootstrap.errorMessage ??
                  'Firebase 설정이 완료되지 않아 채팅을 사용할 수 없습니다.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: workerThemeColor,
        foregroundColor: Colors.white,
        title: Text(widget.roomTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: ChatService.watchMessages(widget.roomId),
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
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('아직 대화가 없습니다.'));
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
                        data['senderRole']?.toString() == 'admin';
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
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
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? workerThemeColor
                                  : const Color(0xFFF1F4F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['senderName']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isMine
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['text']?.toString() ?? '',
                                  style: TextStyle(
                                    color: isMine ? Colors.white : Colors.black87,
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
                                            : Colors.black45,
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
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x10000000),
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
                        hintText: '답변을 입력하세요',
                        filled: true,
                        fillColor: const Color(0xFFF3F5F7),
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
                      backgroundColor: workerThemeColor,
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
