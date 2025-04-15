import 'package:flutter/material.dart';
import 'category_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Account Settings'),
              subtitle: const Text('Manage your account details'),
              onTap: () {},
            ),
            const Divider(),

            ExpansionTile(
              leading: const Icon(Icons.category),
              title: const Text('Category Settings'),
              subtitle: const Text('Manage income and expense categories'),
              children: [
                ListTile(
                  leading: const Icon(Icons.arrow_right),
                  title: const Text('Income Categories'),
                  onTap: () => _navigateToCategoryScreen(context, 'Income'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.arrow_right),
                  title: const Text('Expense Categories'),
                  onTap: () => _navigateToCategoryScreen(context, 'Expense'),
                ),
              ],
            ),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              subtitle: const Text('Manage your notification preferences'),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Theme'),
              subtitle: const Text('Select light or dark theme'),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.monetization_on),
              title: const Text('Currency'),
              subtitle: const Text('Select your preferred currency'),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('Backup & Restore'),
              subtitle: const Text('Backup your data to the cloud'),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Log Out'),
              onTap: () {},
            ),
          ],
        ),
      ),
      // If you have a FAB in settings screen, make sure to add heroTag: null
      floatingActionButton: null, // No FAB in this screen
    );
  }
}