import 'package:flutter/material.dart';
import 'database_helper.dart'; // Assuming you have your DatabaseHelper in this file


class CategoryScreen extends StatefulWidget {
  final String categoryType; // "Income" or "Expense"

  const CategoryScreen({Key? key, required this.categoryType}) : super(key: key);

  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> categories = [];

  bool _hasSubcategory = false; // To track if subcategory is needed
  TextEditingController _categoryController = TextEditingController();
  List<TextEditingController> _subcategoryControllers = []; // List for subcategory controllers

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categoryType = widget.categoryType.toLowerCase(); // "income" or "expense"
    final fetchedCategories = await dbHelper.getCategories(categoryType);
    setState(() {
      categories = fetchedCategories;
    });
  }

  Future<void> _addCategory() async {
    final categoryType = widget.categoryType.toLowerCase(); // "income" or "expense"
    String categoryName = _categoryController.text.trim();
    if (categoryName.isNotEmpty) {
      final categoryId = await dbHelper.addCategory(categoryName, categoryType);

      // Add each subcategory
      for (var controller in _subcategoryControllers) {
        String subcategoryName = controller.text.trim();
        if (subcategoryName.isNotEmpty) {
          await dbHelper.addSubcategory(subcategoryName, categoryId);
        }
      }

      // Clear fields
      _categoryController.clear();
      for (var controller in _subcategoryControllers) {
        controller.clear();
      }

      setState(() {
        _subcategoryControllers.clear(); // Reset the subcategory controllers list
        _hasSubcategory = false; // Reset the subcategory flag
      });

      _loadCategories();
      Navigator.of(context).pop(); // Close the dialog and return to the category screen
    }
  }

  Future<void> _updateCategory(int id, String newName) async {
    await dbHelper.updateCategory(id, newName);
    _loadCategories();
  }

  Future<void> _deleteCategory(int id) async {
    bool confirmDelete = await _showDeleteDialog(); // Show confirmation dialog
    if (confirmDelete) {
      await dbHelper.deleteCategory(id); // Proceed with deletion
      _loadCategories(); // Reload categories

      // Close the edit category dialog after deletion
      Navigator.of(context).pop(); // Close the category edit dialog
    }
  }


  Future<bool> _showDeleteDialog() async {
    return await showDialog<bool>(context: context, builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this category?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      );
    }) ?? false;
  }

  void _showCategoryDialog({int? id, String? currentName}) async {
    _categoryController.text = currentName ?? '';
    _subcategoryControllers.clear(); // Clear any existing subcategory controllers
    _hasSubcategory = false; // Reset the flag when opening the dialog

    if (id != null) {
      // Fetch subcategories for the category being edited
      final subcategories = await dbHelper.getSubcategories(id);
      if (subcategories.isNotEmpty) {
        setState(() {
          _hasSubcategory = true; // Enable subcategory switch
          // Add the subcategory controllers
          _subcategoryControllers = subcategories.map((subcategory) {
            return TextEditingController(text: subcategory['name']);
          }).toList();
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(id == null ? 'Add Category' : 'Edit Category'),
            if (id != null)
              Spacer(),
            if (id != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.black38),
                onPressed: () => _deleteCategory(id),
              ),
          ],
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(hintText: 'Category Name'),
                  style: const TextStyle(fontWeight: FontWeight.bold), // Bold category name
                ),
                Row(
                  children: [
                    Switch(
                      value: _hasSubcategory,
                      onChanged: (bool value) {
                        setState(() {
                          _hasSubcategory = value;
                        });
                      },
                    ),
                    const Text('Include Subcategory?'),
                  ],
                ),
                // Show subcategory textfields if the switch is on
                if (_hasSubcategory)
                  Column(
                    children: [
                      // Render all the subcategory controllers
                      for (int i = 0; i < _subcategoryControllers.length; i++)
                        TextField(
                          controller: _subcategoryControllers[i],
                          decoration: InputDecoration(hintText: 'Subcategory ${i + 1}'),
                        ),
                      // Add a "+" button to add more subcategories
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                _subcategoryControllers.add(TextEditingController());
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final categoryName = _categoryController.text.trim();
              if (categoryName.isNotEmpty) {
                if (id == null) {
                  _addCategory(); // Add new category
                } else {
                  _updateCategory(id, categoryName); // Update existing category
                }
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.categoryType} Categories')),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onLongPress: () {
              // Handle long press to edit or delete category
              _showCategoryDialog(id: category['id'], currentName: category['name']);
            },
            child: ExpansionTile(
              title: Text(
                category['name'],
                style: const TextStyle(fontWeight: FontWeight.bold), // Bold category name
              ),
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: dbHelper.getSubcategories(category['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return ListTile(
                        contentPadding: const EdgeInsets.only(left: 40.0),
                        title: Text(
                            'No Subcategories',
                        style: TextStyle(
                          color: Colors.black38,
                        )),
                      );
                    }

                    final subcategories = snapshot.data!;
                    return Column(
                      children: subcategories.map((subcategory) {
                        return GestureDetector(
                          onLongPress: () {
                            // Handle long press for subcategory edit/delete
                            _showSubcategoryDialog(
                              category['id'],
                              subcategoryId: subcategory['id'],
                              currentName: subcategory['name'],
                            );
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(left: 40.0), // Space for subcategory
                            title: Text(
                              subcategory['name'],
                              style: TextStyle(
                                color: Colors.blueGrey, // Different color for subcategory
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                ListTile(
                  title: const Text('Add Subcategory'),
                  onTap: () => _showCategoryDialog(id: category['id'], currentName: category['name']),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSubcategoryDialog(int categoryId, {int? subcategoryId, String? currentName}) {
    final TextEditingController controller = TextEditingController(
      text: currentName ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(subcategoryId == null ? 'Add Subcategory' : 'Edit Subcategory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Subcategory Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                if (subcategoryId == null) {
                  dbHelper.addSubcategory(name, categoryId);
                } else {
                  dbHelper.updateSubcategory(subcategoryId, name);
                }
                Navigator.of(context).pop();
                _loadCategories(); // Reload categories to reflect changes
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
