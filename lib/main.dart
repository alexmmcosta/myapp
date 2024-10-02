import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// Task model
class Task {
  String name;
  int priority; // 1 = High, 2 = Medium, 3 = Low
  bool isCompleted;
  int pomodoroCount; // Tracks how many Pomodoros have been spent on this task

  Task(
      {required this.name,
      required this.priority,
      this.isCompleted = false,
      this.pomodoroCount = 0});
}

void main() {
  runApp(PomodoroApp());
}

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomodoro App',
      theme: ThemeData(
        brightness: Brightness.dark, // Enable dark theme
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black, // Black background for screens
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black, // Black app bar background
          iconTheme: IconThemeData(color: Colors.white), // White icons
          titleTextStyle:
              TextStyle(color: Colors.white, fontSize: 20), // White title text
        ),
        textTheme: GoogleFonts.robotoCondensedTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ), // Apply white color),
        buttonTheme: const ButtonThemeData(
          buttonColor: Colors.blueAccent, // Sporty accent color for buttons
        ),
        iconTheme: const IconThemeData(color: Colors.white), // White icons globally
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: const TextStyle(color: Colors.white), // White text for dropdown
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor:
              Colors.blueAccent, // Accent color for floating action buttons
        ),
      ),
      home: PomodoroTimer(),
    );
  }
}

class PomodoroTimer extends StatefulWidget {
  const PomodoroTimer({super.key});

  @override
  _PomodoroTimerState createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  int _pomodoroDuration = 25; // Default Pomodoro duration (minutes)
  int _breakDuration = 5; // Default short break (minutes)
  int _longBreakDuration = 15; // Default long break (minutes)
  int _timeRemaining = 0;
  bool _isBreak = false;
  Timer? _timer;
  bool _isRunning = false; // Track whether the timer is running or not
  int _pomodoroCount = 0; // Count of Pomodoros completed in a row
  List<Task> _tasks = []; // List of tasks
  Task? _currentTask; // Currently selected task

  @override
  void initState() {
    super.initState();
    _loadDurations(); // Load saved durations when the app starts
    _loadTasks(); // Load tasks from SharedPreferences
  }

  // Load custom durations from SharedPreferences
  void _loadDurations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _pomodoroDuration = prefs.getInt('pomodoroDuration') ?? 25;
      _breakDuration = prefs.getInt('breakDuration') ?? 5;
      _longBreakDuration = prefs.getInt('longBreakDuration') ?? 15;
      _timeRemaining =
          _pomodoroDuration * 60; // Set initial timer to Pomodoro duration
    });
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
            name: taskDetails[0],
            priority: int.parse(taskDetails[1]),
            isCompleted: taskDetails[2] == 'true',
            pomodoroCount: int.parse(taskDetails[3]),
          );
        }).toList();
      });
    }
  }

  // Save tasks back to SharedPreferences after Pomodoro is completed
  void _saveTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> taskList = _tasks
        .map((task) =>
            '${task.name}|${task.priority}|${task.isCompleted}|${task.pomodoroCount}')
        .toList();
    prefs.setStringList('tasks', taskList);
  }

  // Start the timer
  void _startTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }

    setState(() {
      _isRunning = true; // Mark timer as running
    });

    if (_currentTask != null) {
      // Increase the pomodoro count for the current task
      setState(() {
        _currentTask!.pomodoroCount++;
      });
      _saveTasks(); // Save the task with the updated Pomodoro count
    }

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          _timer!.cancel();
          _isRunning = false; // Mark timer as stopped

          if (_isBreak) {
            // After a break, reset to Pomodoro
            _isBreak = false;
            _timeRemaining = _pomodoroDuration * 60;
          } else {
            // After a Pomodoro
            _pomodoroCount++;
            if (_pomodoroCount % 4 == 0) {
              // Take a longer break after every 4 Pomodoros
              _timeRemaining = _longBreakDuration * 60;
            } else {
              // Take a short break
              _timeRemaining = _breakDuration * 60;
            }
            _isBreak = true;
          }
        }
      });
    });
  }

  // Stop the timer
  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
    setState(() {
      _isRunning = false; // Mark timer as stopped
    });
  }

  // Open the settings screen
  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen()),
    );
    // Reload the durations after returning from the settings screen
    if (result != null) {
      _loadDurations();
    }
  }

  // Format time for display
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pomodoro Timer'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _openSettings,
          ),
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SummaryScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TaskScreen()),
              ).then((_) => _loadTasks());
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButton<Task>(
              hint: Text('Select Task'),
              value: _currentTask,
              onChanged: (Task? newTask) {
                setState(() {
                  _currentTask = newTask!;
                });
              },
              items: _tasks.map((task) {
                return DropdownMenuItem<Task>(
                  value: task,
                  child: Text(task.name),
                );
              }).toList(),
            ),
            Text(
              _isBreak
                  ? (_pomodoroCount % 4 == 0 ? 'Long Break' : 'Break')
                  : 'Pomodoro',
              style: TextStyle(fontSize: 32),
            ),
            Text(
              _formatTime(_timeRemaining),
              style: TextStyle(fontSize: 48),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRunning ? _stopTimer : _startTimer,
              child: Text(_isRunning ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryScreen extends StatelessWidget {
  Future<Map<String, dynamic>> _getDailySummary(String day) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get Pomodoros and break data for the day
    List<String> pomodoros = prefs.getStringList(day) ?? [];
    int totalBreakTime = prefs.getInt('break_$day') ?? 0;

    // Calculate total Pomodoros and focus time
    int totalPomodoros = pomodoros.length;
    int totalFocusTime = 0;

    for (String session in pomodoros) {
      List<String> times = session.split('|');
      DateTime startTime = DateTime.parse(times[0]);
      DateTime endTime = DateTime.parse(times[1]);
      totalFocusTime += endTime.difference(startTime).inMinutes;
    }

    return {
      'totalPomodoros': totalPomodoros,
      'totalFocusTime': totalFocusTime,
      'totalBreakTime': totalBreakTime,
    };
  }

  Future<Map<String, dynamic>> _getWeeklySummary() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Initialize weekly totals
    int totalPomodoros = 0;
    int totalFocusTime = 0;
    int totalBreakTime = 0;

    DateTime now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      String day =
          now.subtract(Duration(days: i)).toIso8601String().substring(0, 10);

      List<String> pomodoros = prefs.getStringList(day) ?? [];
      totalBreakTime += prefs.getInt('break_$day') ?? 0;

      for (String session in pomodoros) {
        List<String> times = session.split('|');
        DateTime startTime = DateTime.parse(times[0]);
        DateTime endTime = DateTime.parse(times[1]);
        totalFocusTime += endTime.difference(startTime).inMinutes;
        totalPomodoros++;
      }
    }

    return {
      'totalPomodoros': totalPomodoros,
      'totalFocusTime': totalFocusTime,
      'totalBreakTime': totalBreakTime,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Summary'),
      ),
      body: FutureBuilder(
        future: _getWeeklySummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData) {
            Map<String, dynamic> data = snapshot.data as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Summary',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text('Total Pomodoros: ${data['totalPomodoros']}'),
                  Text('Total Focus Time: ${data['totalFocusTime']} minutes'),
                  Text('Total Break Time: ${data['totalBreakTime']} minutes'),
                  SizedBox(height: 20),
                  FutureBuilder(
                    future: _getDailySummary(
                        DateTime.now().toIso8601String().substring(0, 10)),
                    builder: (context, dailySnapshot) {
                      if (dailySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (dailySnapshot.hasData) {
                        Map<String, dynamic> dailyData =
                            dailySnapshot.data as Map<String, dynamic>;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Today\'s Summary',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            SizedBox(height: 10),
                            Text(
                                'Total Pomodoros: ${dailyData['totalPomodoros']}'),
                            Text(
                                'Total Focus Time: ${dailyData['totalFocusTime']} minutes'),
                            Text(
                                'Total Break Time: ${dailyData['totalBreakTime']} minutes'),
                          ],
                        );
                      }
                      return Container();
                    },
                  ),
                ],
              ),
            );
          }
          return Center(child: Text('No data available'));
        },
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _pomodoroDuration = 25;
  int _breakDuration = 5;
  int _longBreakDuration = 15;

  @override
  void initState() {
    super.initState();
    _loadDurations();
  }

  // Load custom durations from SharedPreferences
  void _loadDurations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _pomodoroDuration = prefs.getInt('pomodoroDuration') ?? 25;
      _breakDuration = prefs.getInt('breakDuration') ?? 5;
      _longBreakDuration = prefs.getInt('longBreakDuration') ?? 15;
    });
  }

  // Save custom durations to SharedPreferences
  void _saveDurations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('pomodoroDuration', _pomodoroDuration);
    prefs.setInt('breakDuration', _breakDuration);
    prefs.setInt('longBreakDuration', _longBreakDuration);
  }

  void _logPomodoroCompletion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get current date
    String today = DateTime.now().toIso8601String().substring(0, 10);

    // Get Pomodoros completed today
    List<String> completedPomodoros = prefs.getStringList(today) ?? [];

    // Add current Pomodoro session
    DateTime endTime = DateTime.now();
    DateTime startTime = endTime.subtract(Duration(minutes: _pomodoroDuration));
    String sessionLog =
        '${startTime.toIso8601String()}|${endTime.toIso8601String()}';

    completedPomodoros.add(sessionLog);

    // Save the updated list for today
    prefs.setStringList(today, completedPomodoros);
  }

  void _logBreakDuration(int breakDuration) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get current date
    String today = DateTime.now().toIso8601String().substring(0, 10);

    // Get total break time for today
    int totalBreakTime = prefs.getInt('break_$today') ?? 0;

    // Add current break duration
    totalBreakTime += breakDuration;

    // Save the updated total
    prefs.setInt('break_$today', totalBreakTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Pomodoro Duration (minutes):'),
            Slider(
              value: _pomodoroDuration.toDouble(),
              min: 15,
              max: 60,
              divisions: 9,
              label: _pomodoroDuration.toString(),
              onChanged: (double value) {
                setState(() {
                  _pomodoroDuration = value.toInt();
                });
              },
            ),
            Text('Break Duration (minutes):'),
            Slider(
              value: _breakDuration.toDouble(),
              min: 5,
              max: 15,
              divisions: 2,
              label: _breakDuration.toString(),
              onChanged: (double value) {
                setState(() {
                  _breakDuration = value.toInt();
                });
              },
            ),
            Text('Long Break Duration (minutes):'),
            Slider(
              value: _longBreakDuration.toDouble(),
              min: 10,
              max: 30,
              divisions: 2,
              label: _longBreakDuration.toString(),
              onChanged: (double value) {
                setState(() {
                  _longBreakDuration = value.toInt();
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _saveDurations();
                Navigator.pop(context, true);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskScreen extends StatefulWidget {
  @override
  _TaskScreenState createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  List<Task> _tasks = [];
  final TextEditingController _taskController = TextEditingController();

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
            name: taskDetails[0],
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
            '${task.name}|${task.priority}|${task.isCompleted}|${task.pomodoroCount}')
        .toList();
    prefs.setStringList('tasks', taskList);
  }

  // Add a new task to the list
  void _addTask(String name, int priority) {
    setState(() {
      _tasks.add(Task(name: name, priority: priority));
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
                    task.name,
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
