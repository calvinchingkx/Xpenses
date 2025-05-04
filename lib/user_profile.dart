import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xpenses/services/notification_service.dart';
import '../services/data_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  String? _selectedGender;
  bool _budgetNotifications = true;
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dobController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final db = await _dataService.dbHelper.database;
    final user = await db.query('user', limit: 1);

    if (user.isNotEmpty) {
      setState(() {
        _nameController.text = user[0]['name'] as String? ?? '';
        _dobController.text = user[0]['dob'] as String? ?? '';
        _selectedGender = user[0]['gender'] as String?;
        // Only load budget notifications setting
        _budgetNotifications = (user[0]['budget_notifications'] as int?) != 0;
      });
    } else {
      // Set default if no user exists
      setState(() {
        _budgetNotifications = true; // Default enabled
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final db = await _dataService.dbHelper.database;

      final userData = {
        'name': _nameController.text,
        'dob': _dobController.text,
        'gender': _selectedGender,
        'budget_notifications': _budgetNotifications ? 1 : 0,
      };

      // Check if user exists
      final count = await db.rawQuery('SELECT COUNT(*) FROM user');
      final exists = (count[0]['COUNT(*)'] as int) > 0;

      if (exists) {
        await db.update('user', userData, where: 'id = 1');
      } else {
        await db.insert('user', userData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dobController.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd').parse(_dobController.text)
          : DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: const Icon(Icons.person, size: 60),
                ),
              ),
              const SizedBox(height: 24),

              // Personal Information Section
              Text(
                'Personal Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_drop_down),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Male',
                    child: Text('Male'),
                  ),
                  DropdownMenuItem(
                    value: 'Female',
                    child: Text('Female'),
                  ),
                  DropdownMenuItem(
                    value: 'Not to Say',
                    child: Text('Not to Say'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select your gender';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Notification Preferences Section
              Text(
                'Notification Preferences',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Budget Notifications'),
                subtitle: const Text('Get alerts when approaching budget limits'),
                value: _budgetNotifications,
                onChanged: (value) {
                  setState(() {
                    _budgetNotifications = value;
                  });
                },
                secondary: const Icon(Icons.notifications_active),
              ),
              ListTile(
                leading: const Icon(Icons.notification_add),
                title: const Text('Test Notification'),
                subtitle: const Text('Verify notifications are working'),
                onTap: () async {
                  final notificationService = Provider.of<NotificationService>(context, listen: false);
                  await notificationService.showBudgetWarning('Test Category', 100);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test notification sent')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}