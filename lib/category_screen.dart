import 'package:flutter/material.dart';
import 'database_helper.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryType;

  const CategoryScreen({Key? key, required this.categoryType}) : super(key: key);

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> categories = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => isLoading = true);
    try {
      final fetchedCategories = await dbHelper.getCategories(widget.categoryType.toLowerCase());
      setState(() => categories = fetchedCategories);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addCategory(String name, {List<String>? subcategories}) async {
    final categoryId = await dbHelper.addCategory(name, widget.categoryType.toLowerCase());

    if (subcategories != null && subcategories.isNotEmpty) {
      for (final subcategory in subcategories) {
        await dbHelper.addSubcategory(subcategory, categoryId);
      }
    }

    await _loadCategories();
  }

  Future<void> _updateCategory(int id, String newName) async {
    await dbHelper.updateCategory(id, newName);
    await _loadCategories();
  }

  Future<void> _deleteCategory(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this category and all its subcategories?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      await dbHelper.deleteCategory(id);
      await _loadCategories();
    }
  }

  Future<void> _addSubcategory(int categoryId, String name) async {
    await dbHelper.addSubcategory(name, categoryId);
    await _loadCategories();
  }

  Future<void> _updateSubcategory(int id, String newName) async {
    await dbHelper.updateSubcategory(id, newName);
    await _loadCategories();
  }

  Future<void> _deleteSubcategory(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this subcategory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      await dbHelper.deleteSubcategory(id);
      await _loadCategories();
    }
  }

  void _showAddCategoryDialog() {
    final categoryController = TextEditingController();
    final subcategoryControllers = <TextEditingController>[];
    var hasSubcategories = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add New Category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Include Subcategories'),
                    value: hasSubcategories,
                    onChanged: (value) => setState(() => hasSubcategories = value),
                  ),
                  if (hasSubcategories) ...[
                    const SizedBox(height: 8),
                    ...subcategoryControllers.map((controller) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Subcategory',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    )),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => subcategoryControllers.add(TextEditingController())),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final categoryName = categoryController.text.trim();
                  if (categoryName.isEmpty) return;

                  final subcategories = hasSubcategories
                      ? subcategoryControllers
                      .map((c) => c.text.trim())
                      .where((name) => name.isNotEmpty)
                      .toList()
                      : null;

                  await _addCategory(categoryName, subcategories: subcategories);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditCategoryDialog(Map<String, dynamic> category) {
    final categoryController = TextEditingController(text: category['name']);
    final subcategoryControllers = <TextEditingController>[];

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: dbHelper.getSubcategories(category['id']),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            subcategoryControllers.addAll(
              snapshot.data!.map((sc) => TextEditingController(text: sc['name'])),
            );
          }

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Row(
                  children: [
                    const Text('Edit Category'),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteCategory(category['id']);
                      },
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...subcategoryControllers.map((controller) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: const InputDecoration(
                                  labelText: 'Subcategory',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final index = subcategoryControllers.indexOf(controller);
                                final subcategory = snapshot.data![index];
                                Navigator.pop(context);
                                await _deleteSubcategory(subcategory['id']);
                                _showEditCategoryDialog(category);
                              },
                            ),
                          ],
                        ),
                      )),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddSubcategoryDialog(category['id']),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _updateCategory(category['id'], categoryController.text.trim());
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAddSubcategoryDialog(int categoryId) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subcategory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Subcategory Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await _addSubcategory(categoryId, name);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditSubcategoryDialog(int categoryId, int subcategoryId, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Subcategory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Subcategory Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await _updateSubcategory(subcategoryId, name);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSubcategory(subcategoryId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryType} Categories'),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      body: _buildCategoryList(),
      floatingActionButton: FloatingActionButton(
        heroTag: null, // Hero animation disabled
        onPressed: _showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (isLoading && categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No ${widget.categoryType} Categories',
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showAddCategoryDialog,
              child: const Text('Create Your First Category'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return GestureDetector(
          onLongPress: () => _showEditCategoryDialog(category),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: ExpansionTile(
              leading: const Icon(Icons.category, color: Colors.blueAccent),
              title: Text(
                category['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: dbHelper.getSubcategories(category['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final subcategories = snapshot.data ?? [];
                    return Column(
                      children: [
                        ...subcategories.map((subcategory) => ListTile(
                          leading: const Icon(Icons.subdirectory_arrow_right, size: 20),
                          title: Text(subcategory['name']),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditSubcategoryDialog(
                              category['id'],
                              subcategory['id'],
                              subcategory['name'],
                            ),
                          ),
                          onLongPress: () => _deleteSubcategory(subcategory['id']),
                        )),
                        ListTile(
                          leading: const Icon(Icons.add, color: Colors.blue),
                          title: const Text('Add Subcategory',
                              style: TextStyle(color: Colors.blue)),
                          onTap: () => _showAddSubcategoryDialog(category['id']),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}