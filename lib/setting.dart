import 'package:flutter/material.dart';
import 'category_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
            // Account settings section
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Account Settings'),
              subtitle: const Text('Manage your account details'),
              onTap: () {
                // Navigate to account settings page if needed
              },
            ),
            const Divider(),

            // Category settings section
            ExpansionTile(
              leading: const Icon(Icons.category),
              title: const Text('Category Settings'),
              subtitle: const Text('Manage income and expense categories'),
              children: [
                ListTile(
                  leading: const Icon(Icons.arrow_right),
                  title: const Text('Income Categories'),
                  onTap: () {
                    // Navigate to Income Categories using CategoryScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const CategoryScreen(categoryType: 'Income'),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.arrow_right),
                  title: const Text('Expense Categories'),
                  onTap: () {
                    // Navigate to Expense Categories using CategoryScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const CategoryScreen(categoryType: 'Expense'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const Divider(),

            // Other settings
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              subtitle: const Text('Manage your notification preferences'),
              onTap: () {
                // Navigate to notifications settings or show a dialog
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('Theme'),
              subtitle: const Text('Select light or dark theme'),
              onTap: () {
                // Add theme switch functionality here
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.monetization_on),
              title: const Text('Currency'),
              subtitle: const Text('Select your preferred currency'),
              onTap: () {
                // Add functionality to change currency
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('Backup & Restore'),
              subtitle: const Text('Backup your data to the cloud'),
              onTap: () {
                // Implement backup and restore feature
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Log Out'),
              onTap: () {
                // Add logout functionality here
              },
            ),
          ],
        ),
      ),
    );
  }
}
