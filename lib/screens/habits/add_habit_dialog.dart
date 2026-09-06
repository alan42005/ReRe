import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:reminder_app/models/habit.dart';
import 'package:reminder_app/utils/app_colors.dart';
import 'package:reminder_app/utils/habit_icon_helper.dart';

class AddHabitDialog extends StatefulWidget {
  final Habit? habitToEdit;

  const AddHabitDialog({super.key, this.habitToEdit});

  @override
  State<AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<AddHabitDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late String _selectedCategory;
  late Color _selectedColor;
  late int _selectedIconCode;

  final List<String> _categories = [
    'Health',
    'Mind',
    'Focus',
    'Fitness',
    'Learning',
    'Routine'
  ];

  final List<IconData> _icons = HabitIconHelper.availableIcons;

  @override
  void initState() {
    super.initState();
    final h = widget.habitToEdit;
    _titleController = TextEditingController(text: h?.title ?? '');
    _selectedCategory = h?.category ?? _categories.first;
    _selectedColor =
        h != null ? Color(h.colorValue) : AppColors.habitPalette.first;
    _selectedIconCode = h?.iconCode ?? _icons.first.codePoint;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveHabit() {
    if (_formKey.currentState!.validate()) {
      final box = Hive.box<Habit>('habits');
      if (widget.habitToEdit != null) {
        final habit = widget.habitToEdit!;
        habit.title = _titleController.text.trim();
        habit.category = _selectedCategory;
        habit.colorValue = _selectedColor.toARGB32();
        habit.iconCode = _selectedIconCode;
        habit.save();
      } else {
        final newHabit = Habit(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          category: _selectedCategory,
          colorValue: _selectedColor.toARGB32(),
          iconCode: _selectedIconCode,
        );
        box.add(newHabit);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.habitToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Habit' : 'New Habit',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textLight),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  autofocus: !isEditing,
                  decoration: InputDecoration(
                    labelText: 'Habit Name',
                    hintText: 'e.g. Read 20 pages, Drink water',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter a habit title'
                      : null,
                ),
                const SizedBox(height: 18),
                const Text('Category',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final selected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      selectedColor: AppColors.primary,
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text('Color',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AppColors.habitPalette.map((color) {
                      final isSel = _selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.black : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isSel
                              ? const Icon(Icons.check,
                                  size: 18, color: Colors.black)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Icon',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _icons.map((iconData) {
                      final isSel = _selectedIconCode == iconData.codePoint;
                      return GestureDetector(
                        onTap: () => setState(
                            () => _selectedIconCode = iconData.codePoint),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? _selectedColor.withValues(alpha: 0.2)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? _selectedColor : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            iconData,
                            size: 24,
                            color: isSel ? _selectedColor : AppColors.textDark,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveHabit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Update Habit' : 'Create Habit',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
