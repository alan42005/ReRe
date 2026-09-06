import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reminder_app/models/focus_session.dart';
import 'package:reminder_app/models/habit.dart';
import 'package:reminder_app/models/task.dart';
import 'package:reminder_app/utils/app_colors.dart';
import 'package:reminder_app/utils/notification_service.dart';

enum TimerMode { pomodoro, shortBreak, longBreak, flow }

class FocusScreen extends StatefulWidget {
  final String? initialTaskTitle;

  const FocusScreen({super.key, this.initialTaskTitle});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  TimerMode _mode = TimerMode.pomodoro;
  int _targetSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  int _elapsedFlowSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;

  String _selectedGoal = 'Deep Work';
  Task? _linkedTask;
  Habit? _linkedHabit;

  @override
  void initState() {
    super.initState();
    if (widget.initialTaskTitle != null) {
      _selectedGoal = widget.initialTaskTitle!;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _switchMode(TimerMode mode) {
    _timer?.cancel();
    setState(() {
      _mode = mode;
      _isRunning = false;
      if (mode == TimerMode.pomodoro) {
        _targetSeconds = 25 * 60;
        _remainingSeconds = _targetSeconds;
      } else if (mode == TimerMode.shortBreak) {
        _targetSeconds = 5 * 60;
        _remainingSeconds = _targetSeconds;
      } else if (mode == TimerMode.longBreak) {
        _targetSeconds = 15 * 60;
        _remainingSeconds = _targetSeconds;
      } else if (mode == TimerMode.flow) {
        _elapsedFlowSeconds = 0;
      }
    });
  }

  void _setPresetMinutes(int minutes) {
    if (_isRunning) return;
    setState(() {
      _targetSeconds = minutes * 60;
      _remainingSeconds = _targetSeconds;
    });
  }

  void _toggleStartPause() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_mode == TimerMode.flow) {
          setState(() {
            _elapsedFlowSeconds++;
          });
        } else {
          if (_remainingSeconds > 1) {
            setState(() {
              _remainingSeconds--;
            });
          } else {
            _timer?.cancel();
            setState(() {
              _remainingSeconds = 0;
              _isRunning = false;
            });
            _onSessionComplete();
          }
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      if (_mode == TimerMode.flow) {
        _elapsedFlowSeconds = 0;
      } else {
        _remainingSeconds = _targetSeconds;
      }
    });
  }

  Future<void> _onSessionComplete() async {
    HapticFeedback.heavyImpact();
    final int focusedMinutes =
        _mode == TimerMode.flow ? (_elapsedFlowSeconds / 60).ceil() : (_targetSeconds / 60).toInt();

    if (focusedMinutes > 0 && _mode != TimerMode.shortBreak && _mode != TimerMode.longBreak) {
      final box = Hive.box<FocusSession>('focus_logs');
      final newSession = FocusSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _selectedGoal,
        durationMinutes: focusedMinutes,
        mode: _mode == TimerMode.flow ? 'stopwatch' : 'pomodoro',
      );
      await box.add(newSession);

      // If linked to task, update task's focus minutes
      if (_linkedTask != null) {
        _linkedTask!.focusMinutesSpent += focusedMinutes;
        await _linkedTask!.save();
      }

      // If linked to habit, mark habit done today if not already
      if (_linkedHabit != null) {
        if (!_linkedHabit!.isCompletedOn(DateTime.now())) {
          _linkedHabit!.toggleCompletion(DateTime.now());
        }
      }
    }

    // Show instant notification
    await NotificationService().flutterLocalNotificationsPlugin.show(
      888,
      'Session Finished! 🎯',
      'Great job! You completed $focusedMinutes minutes of focus on "$_selectedGoal".',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'focus_channel',
          'Focus Sessions',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🎉 Session Complete!'),
          content: Text(
              'Awesome work! You logged $focusedMinutes minutes on "$_selectedGoal". Take a well-deserved break!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _switchMode(TimerMode.shortBreak);
              },
              child: const Text('Start 5m Break'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textDark,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  void _finishFlowSessionEarly() {
    if (_elapsedFlowSeconds < 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Focus at least 1 minute to save session.')),
      );
      _resetTimer();
      return;
    }
    _timer?.cancel();
    setState(() => _isRunning = false);
    _onSessionComplete();
    setState(() => _elapsedFlowSeconds = 0);
  }

  void _showLinkGoalModal() {
    final tasksBox = Hive.box<Task>('tasks');
    final habitsBox = Hive.box<Habit>('habits');
    final activeTasks = tasksBox.values.where((t) => !t.isCompleted).toList();
    final activeHabits = habitsBox.values.toList();
    final customController = TextEditingController(text: _selectedGoal);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What are you focusing on?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: customController,
                  decoration: InputDecoration(
                    hintText: 'Custom focus goal...',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                if (activeTasks.isNotEmpty) ...[
                  const Text('Link to Today\'s Task',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activeTasks.map((task) {
                      return ActionChip(
                        avatar: const Icon(Icons.task_alt, size: 16),
                        label: Text(task.title),
                        onPressed: () {
                          setState(() {
                            _selectedGoal = task.title;
                            _linkedTask = task;
                            _linkedHabit = null;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (activeHabits.isNotEmpty) ...[
                  const Text('Link to a Habit',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activeHabits.map((habit) {
                      return ActionChip(
                        avatar: const Icon(Icons.repeat, size: 16),
                        label: Text(habit.title),
                        onPressed: () {
                          setState(() {
                            _selectedGoal = habit.title;
                            _linkedHabit = habit;
                            _linkedTask = null;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (customController.text.trim().isNotEmpty) {
                        setState(() {
                          _selectedGoal = customController.text.trim();
                          _linkedTask = null;
                          _linkedHabit = null;
                        });
                      }
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Confirm Focus Goal',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isFlow = _mode == TimerMode.flow;
    final displayTime =
        isFlow ? _formatTime(_elapsedFlowSeconds) : _formatTime(_remainingSeconds);
    final progress = isFlow
        ? 1.0
        : (_targetSeconds > 0
            ? (_targetSeconds - _remainingSeconds) / _targetSeconds
            : 0.0);

    final focusBox = Hive.box<FocusSession>('focus_logs');

    return Scaffold(
      backgroundColor: AppColors.timerDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Deep Work Timer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Timer',
            onPressed: _resetTimer,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              // Mode Selector Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.timerCard,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildModeButton(TimerMode.pomodoro, 'Focus'),
                    _buildModeButton(TimerMode.shortBreak, '5m Break'),
                    _buildModeButton(TimerMode.longBreak, '15m Break'),
                    _buildModeButton(TimerMode.flow, 'Flow (∞)'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Goal selector chip
              GestureDetector(
                onTap: _showLinkGoalModal,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.timerCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_rounded,
                          color: AppColors.pomodoroWork, size: 18),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          _selectedGoal,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Zen Circular Timer Dial
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: isFlow ? null : progress,
                        strokeWidth: 10,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _mode == TimerMode.shortBreak ||
                                  _mode == TimerMode.longBreak
                              ? AppColors.pomodoroBreak
                              : AppColors.pomodoroWork,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayTime,
                          style: const TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _mode == TimerMode.shortBreak ||
                                  _mode == TimerMode.longBreak
                              ? 'REST & RECHARGE'
                              : (_isRunning ? 'STAY FOCUSED' : 'READY'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Pomodoro Preset Interval Buttons (only in focus mode)
              if (_mode == TimerMode.pomodoro) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [15, 25, 45, 60].map((mins) {
                    final isSel = _targetSeconds == mins * 60;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ActionChip(
                        label: Text('${mins}m'),
                        backgroundColor: isSel
                            ? AppColors.primary
                            : AppColors.timerCard,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.black : Colors.white70,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.w500,
                        ),
                        onPressed: () => _setPresetMinutes(mins),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
              ],

              // Controls: Play / Pause / Flow Finish
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _toggleStartPause,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 38,
                      ),
                    ),
                  ),
                  if (isFlow && _elapsedFlowSeconds > 0) ...[
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: _finishFlowSessionEarly,
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('Finish'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pomodoroBreak,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 36),

              // Today's Focus Metrics
              ValueListenableBuilder<Box<FocusSession>>(
                valueListenable: focusBox.listenable(),
                builder: (context, box, _) {
                  final now = DateTime.now();
                  final todaySessions = box.values.where((s) {
                    return s.completedAt.year == now.year &&
                        s.completedAt.month == now.month &&
                        s.completedAt.day == now.day;
                  }).toList();

                  final totalMinutesToday = todaySessions.fold<int>(
                      0, (sum, item) => sum + item.durationMinutes);

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.timerCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Today\'s Focus',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '${totalMinutesToday}m',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                            height: 32, width: 1, color: Colors.white12),
                        Column(
                          children: [
                            const Text('Completed Sessions',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '${todaySessions.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(TimerMode mode, String label) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white12 : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
