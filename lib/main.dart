import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the notifications plugin
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomodoro App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: PomodoroScreen(),
    );
  }
}

class Task {
  String title;
  int priority; // 1 = High, 2 = Medium, 3 = Low
  bool isCompleted;
  int pomodoroCount; // Tracks how many Pomodoros have been spent on this task

  Task(
      {required this.title,
      required this.priority,
      this.isCompleted = false,
      this.pomodoroCount = 0});
}

class TaskScreen extends StatefulWidget {
  @override
  _TaskScreenState createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  List<Task> _tasks = [];
  final TextEditingController _taskController = TextEditingController();

  // Load tasks from SharedPreferences (if persistent storage is needed)
  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedTasks = prefs.getStringList('tasks');
    if (savedTasks != null) {
      setState(() {
        _tasks = savedTasks.map((task) {
          List<String> taskDetails = task.split('|');
          return Task(
            title: taskDetails[0],
            priority: int.parse(taskDetails[1]),
            isCompleted: taskDetails[2] == 'true',
            pomodoroCount: int.parse(taskDetails[3]),
          );
        }).toList();
      });
    }
  }

  void _saveTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> taskList = _tasks
        .map((task) =>
            '${task.title}|${task.priority}|${task.isCompleted}|${task.pomodoroCount}')
        .toList();
    prefs.setStringList('tasks', taskList);
  }

  // Add a new task to the list
  void _addTask(String name, int priority) {
    setState(() {
      _tasks.add(Task(title: name, priority: priority));
      _saveTasks();
    });
    _taskController.clear();
  }

  // Toggle task completion
  void _toggleTaskCompletion(Task task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
      _saveTasks();
    });
  }

  // Build the task list UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _taskController,
              decoration: InputDecoration(
                labelText: 'Task Name',
                suffixIcon: DropdownButton<int>(
                  hint: Text("Priority"),
                  items: [
                    DropdownMenuItem(value: 1, child: Text("High")),
                    DropdownMenuItem(value: 2, child: Text("Medium")),
                    DropdownMenuItem(value: 3, child: Text("Low")),
                  ],
                  onChanged: (value) {
                    if (_taskController.text.isNotEmpty && value != null) {
                      _addTask(_taskController.text, value);
                    }
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                Task task = _tasks[index];
                return ListTile(
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  subtitle: Text(
                      'Priority: ${task.priority == 1 ? "High" : task.priority == 2 ? "Medium" : "Low"} | Pomodoros: ${task.pomodoroCount}'),
                  trailing: Checkbox(
                    value: task.isCompleted,
                    onChanged: (value) {
                      _toggleTaskCompletion(task);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PomodoroScreen extends StatefulWidget {
  @override
  _PomodoroScreenState createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  int _workDuration = 25; // in minutes
  int _breakDuration = 5; // in minutes
  int _longBreakDuration = 15; // in minutes after 4 sessions
  int _pomodorosBeforeLongBreak = 4;
  int _currentTimer = 0; // in seconds
  bool _isRunning = false;
  bool _isWorkSession = true;
  int _pomodoroCount = 0;
  Timer? _timer;

  List<Task> _tasks = [];
  Task? _selectedTask;

  Future<void> _showAlarmNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pomodoro_channel', // Channel ID
      'Pomodoro Notifications', // Channel Name
      //'Notification channel for Pomodoro timer', // Channel Description
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
          'notification'), // Make sure to add a sound file
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Pomodoro Timer',
      _isWorkSession ? 'Work session completed!' : 'Break time is over!',
      platformChannelSpecifics,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Load tasks from SharedPreferences
  void _loadTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedTasks = prefs.getStringList('tasks');
    if (savedTasks != null) {
      setState(() {
        _tasks = savedTasks.map((task) {
          List<String> taskDetails = task.split('|');
          return Task(
            title: taskDetails[0],
            priority: int.parse(taskDetails[1]),
            isCompleted: taskDetails[2] == 'true',
            pomodoroCount: int.parse(taskDetails[3]),
          );
        }).toList();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
      if (_currentTimer == 0) {
        _currentTimer =
            _isWorkSession ? _workDuration * 60 : _breakDuration * 60;
      }
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentTimer > 0) {
          _currentTimer--;
        } else {
          _timer?.cancel();
          if (kIsWeb) {
            _showWebNotification(); // Show web notification for browser
          } else {
            _showAlarmNotification(); // Show mobile notification for Android/iOS
          }
          if (_isWorkSession) {
            _pomodoroCount++;
            if (_pomodoroCount % _pomodorosBeforeLongBreak == 0) {
              _currentTimer = _longBreakDuration * 60;
            } else {
              _currentTimer = _breakDuration * 60;
            }
            // Increment pomodorosCompleted for the selected task
            if (_selectedTask != null) {
              _selectedTask!.pomodoroCount++;
            }
          } else {
            _currentTimer = _workDuration * 60;
          }
          _isWorkSession = !_isWorkSession;
          _isRunning = false;
        }
      });
    });
  }

  void _stopTimer() {
    setState(() {
      _isRunning = false;
      _timer?.cancel();
    });
  }

  String _formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

// Save tasks back to SharedPreferences after Pomodoro is completed
  void _saveTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> taskList = _tasks
        .map((task) =>
            '${task.title}|${task.priority}|${task.isCompleted}|${task.pomodoroCount}')
        .toList();
    prefs.setStringList('tasks', taskList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pomodoro Timer'),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TaskScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _isWorkSession ? 'Work Session' : 'Break Time',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              _formatTime(_currentTimer),
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            if (_isWorkSession && _tasks.isNotEmpty)
              DropdownButton<Task>(
                hint: Text('Select Task'),
                value: _selectedTask,
                onChanged: (Task? newTask) {
                  setState(() {
                    _selectedTask = newTask!;
                  });
                },
                items: _tasks.map((task) {
                  return DropdownMenuItem<Task>(
                    value: task,
                    child: Text(task.title),
                  );
                }).toList(),
              ),
            SizedBox(height: 40),
            _isRunning
                ? ElevatedButton(
                    onPressed: _stopTimer,
                    child: Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      textStyle: TextStyle(fontSize: 20),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _startTimer,
                    child: Text('Start'),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      textStyle: TextStyle(fontSize: 20),
                    ),
                  ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showSettingsDialog,
              child: Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Timer Settings'),
          content: IntrinsicHeight(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSettingsField('Work Duration (minutes)', _workDuration,
                      (value) {
                    setState(() {
                      _workDuration = int.tryParse(value) ?? _workDuration;
                    });
                  }),
                  _buildSettingsField(
                      'Break Duration (minutes)', _breakDuration, (value) {
                    setState(() {
                      _breakDuration = int.tryParse(value) ?? _breakDuration;
                    });
                  }),
                  _buildSettingsField(
                      'Long Break Duration (minutes)', _longBreakDuration,
                      (value) {
                    setState(() {
                      _longBreakDuration =
                          int.tryParse(value) ?? _longBreakDuration;
                    });
                  }),
                  _buildSettingsField(
                      'Pomodoros Before Long Break', _pomodorosBeforeLongBreak,
                      (value) {
                    setState(() {
                      _pomodorosBeforeLongBreak =
                          int.tryParse(value) ?? _pomodorosBeforeLongBreak;
                    });
                  }),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _requestNotificationPermission() {
    if (html.Notification.supported) {
      html.Notification.requestPermission().then((permission) {
        if (permission == 'granted') {
          print("Notification permission granted.");
        } else {
          print("Notification permission denied.");
        }
      });
    } else {
      print("Notifications are not supported on this browser.");
    }
  }

  void _showWebNotification() {
    if (html.Notification.supported) {
      html.Notification notification = html.Notification(
        _isWorkSession ? 'Work session completed!' : 'Break time is over!',
        body: _isWorkSession
            ? 'Time to take a short break.'
            : 'Get ready for the next work session!',
        icon:
            'path_to_your_icon.png', // You can add a path to a small icon if desired
      );
    }
  }

  Widget _buildSettingsField(
      String label, int value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  // Delete Task
}
