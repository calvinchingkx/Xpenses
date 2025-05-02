import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'category_screen.dart';
import 'theme_provider.dart';
import 'services/data_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  void _navigateToCategoryScreen(BuildContext context, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryScreen(categoryType: type),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final currentTheme = themeProvider.themeMode;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Select Theme',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text(
                  'System Default',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                value: ThemeMode.system,
                groupValue: currentTheme,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(
                  'Light Theme',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                value: ThemeMode.light,
                groupValue: currentTheme,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(
                  'Dark Theme',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                value: ThemeMode.dark,
                groupValue: currentTheme,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  void _showPrivacySecurityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Privacy & Security',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We take your financial data security seriously. Here are the measures we take to protect your information:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildPrivacyFeature(
                  context,
                  icon: Icons.lock,
                  title: 'Data Encryption',
                  description: 'All your financial data is encrypted both in transit and at rest.',
                ),
                _buildPrivacyFeature(
                  context,
                  icon: Icons.fingerprint,
                  title: 'Biometric Authentication',
                  description: 'Optional fingerprint or face ID to secure access to your data.',
                ),
                _buildPrivacyFeature(
                  context,
                  icon: Icons.cloud_off,
                  title: 'Offline Storage',
                  description: 'Your data is stored locally on your device by default.',
                ),
                _buildPrivacyFeature(
                  context,
                  icon: Icons.share,
                  title: 'No Data Sharing',
                  description: 'We do not share your financial data with third parties.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyFeature(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String description,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Account Section
          _buildSectionHeader(context, 'Account'),
          _buildSettingCard(
            context,
            children: [
              _buildSettingTile(
                context,
                icon: Icons.person_outline_rounded,
                title: 'Profile Settings',
                onTap: () {},
              ),
              const Divider(height: 1, indent: 16),
              _buildSettingTile(
                context,
                icon: Icons.security_outlined,
                title: 'Privacy & Security',
                onTap: () => _showPrivacySecurityDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Categories Section
          _buildSectionHeader(context, 'Categories'),
          _buildSettingCard(
            context,
            children: [
              _buildSettingTile(
                context,
                icon: Icons.arrow_upward_rounded,
                title: 'Income Categories',
                onTap: () => _navigateToCategoryScreen(context, 'Income'),
              ),
              const Divider(height: 1, indent: 16),
              _buildSettingTile(
                context,
                icon: Icons.arrow_downward_rounded,
                title: 'Expense Categories',
                onTap: () => _navigateToCategoryScreen(context, 'Expense'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Appearance Section
          _buildSectionHeader(context, 'Appearance'),
          _buildSettingCard(
            context,
            children: [
              _buildSettingTile(
                context,
                icon: Icons.palette_outlined,
                title: 'App Theme',
                trailing: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) {
                    return Text(
                      _getThemeModeText(themeProvider.themeMode),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    );
                  },
                ),
                onTap: () => _showThemeDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Data Section
          _buildSectionHeader(context, 'Data'),
          _buildSettingCard(
            context,
            children: [
              _buildSettingTile(
                context,
                icon: Icons.backup_outlined,
                title: 'Backup Data',
                onTap: () => _exportData(context),
              ),
              const Divider(height: 1, indent: 16),
              _buildSettingTile(
                context,
                icon: Icons.restore_outlined,
                title: 'Restore Data',
                onTap: () => _importData(context),
              ),
              const Divider(height: 1, indent: 16),
              _buildSettingTile(
                context,
                icon: Icons.delete_outline,
                title: 'Delete All Data',
                iconColor: Colors.red,
                onTap: () => _showDeleteConfirmationDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text('This will permanently erase all your financial data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await DataService().deleteAllData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data has been deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deletion failed: ${e.toString()}')),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard(BuildContext context, {required List<Widget> children}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        Widget? trailing,
        Color? iconColor,
        VoidCallback? onTap,
      }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? theme.colorScheme.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? theme.colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minLeadingWidth: 24,
      visualDensity: const VisualDensity(vertical: 0),
      onTap: onTap,
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final dataService = DataService();
      await dataService.exportDataToJson();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data exported successfully!')),
      );

      // Optional: show dialog with file location
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Successful'),
          content: const Text('Your financial data has been exported to a JSON file.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _importData(BuildContext context) async {
    try {
      final dataService = DataService();

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Import'),
          content: const Text(
              'This will overwrite your current data with the backup. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await dataService.importDataFromJson();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data imported successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${e.toString()}')),
      );
    }
  }


}