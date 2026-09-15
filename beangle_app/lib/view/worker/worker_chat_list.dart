import 'package:beangle_app/model/chat_service.dart';
import 'package:beangle_app/settings/firebase_bootstrap.dart';
import 'package:beangle_app/view/worker/worker_chat.dart';
import 'package:beangle_app/view/worker/worker_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class WorkerChatListPage extends StatelessWidget {
  const WorkerChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final GetStorage storage = GetStorage();
    final String workerId = storage.read('worker_id')?.toString() ?? 'manager';
    final colorScheme = Theme.of(context).colorScheme;

    if (!FirebaseBootstrap.isReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            FirebaseBootstrap.errorMessage ??
                'Firebase 설정이 완료되지 않아 채팅 목록을 불러올 수 없습니다.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '어드민 채팅',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '사용자가 남긴 문의를 확인하고 바로 답변할 수 있습니다.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder(
              stream: ChatService.watchRooms(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '채팅방을 불러오지 못했습니다.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.forum_rounded,
                          size: 56,
                          color: workerThemeColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '아직 생성된 채팅방이 없습니다',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '사용자가 관리자 채팅을 시작하면 여기에 대화방이 나타납니다.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final String roomId =
                        data['roomId']?.toString().isNotEmpty == true
                        ? data['roomId'].toString()
                        : docs[index].id;
                    final String userName =
                        data['userName']?.toString() ?? '사용자';
                    final String userEmail =
                        data['userEmail']?.toString() ?? '';
                    final String lastMessage =
                        data['lastMessage']?.toString().trim() ?? '';

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: workerThemeColor.withValues(
                            alpha: 0.14,
                          ),
                          foregroundColor: workerThemeColor,
                          child: const Icon(Icons.person),
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          lastMessage.isEmpty
                              ? (userEmail.isEmpty ? '새 대화방' : userEmail)
                              : lastMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ChatService.unreadCountForRole(data, 'admin') >
                                0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: workerThemeColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  ChatService.unreadCountForRole(data, 'admin') >
                                          99
                                      ? '99+'
                                      : '${ChatService.unreadCountForRole(data, 'admin')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: workerThemeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Get.to(
                            () => WorkerChatPage(
                              roomId: roomId,
                              roomTitle: '$userName 채팅',
                              currentSenderId: 'admin_$workerId',
                              currentSenderName: '관리자',
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
