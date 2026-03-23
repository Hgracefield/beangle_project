import 'package:beangle_app/worker/view/map_for_worker.dart';
import 'package:beangle_app/worker/view/worker_chat_list.dart';
import 'package:beangle_app/worker/view/worker_theme.dart';
import 'package:flutter/material.dart';

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});

  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: workerThemeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        title: const Text(
          '따릉이 재배치',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        // actions: const [
        //   Padding(
        //     padding: EdgeInsets.only(right: 8),
        //     child: GlobalRouteMenu(currentPageLabel: 'Worker Map'),
        //   ),
        // ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          MapForWorkerPage(),
          WorkerChatListPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: workerThemeColor.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '채팅 리스트',
          ),
        ],
      ),
    );
  }
}
