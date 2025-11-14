import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/learn_data_store.dart';
import '../models/learn_models.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> with SingleTickerProviderStateMixin {
  final _store = LearnDataStore.instance;
  late TabController _tabController;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _store.loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Content Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BFA5),
          labelColor: const Color(0xFF00BFA5),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Approved', icon: Icon(Icons.check_circle)),
            Tab(text: 'Rejected', icon: Icon(Icons.cancel)),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          return Column(
            children: [
              _buildCategoryFilter(),
              _buildStats(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildArticleList('pending'),
                    _buildArticleList('approved'),
                    _buildArticleList('rejected'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateArticleDialog,
        backgroundColor: const Color(0xFF00BFA5),
        icon: const Icon(Icons.create),
        label: const Text('Create Article'),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          final categories = ['All', ..._store.categories.map((c) => c.name)];
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category == _selectedCategory;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00BFA5)
                        : Colors.white.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00BFA5)
                          : Colors.white.withAlpha((0.2 * 255).round()),
                    ),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStats() {
    final pending = _store.getPendingArticles().length;
    final approved = _store.articles.where((a) => a.status == 'approved').length;
    final rejected = _store.articles.where((a) => a.status == 'rejected').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha((0.1 * 255).round()),
            Colors.white.withAlpha((0.05 * 255).round()),
          ],
        ),
        border: Border.all(
          color: Colors.white.withAlpha((0.2 * 255).round()),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Pending', pending, const Color(0xFFFFB74D)),
          _buildStatItem('Approved', approved, const Color(0xFF00BFA5)),
          _buildStatItem('Rejected', rejected, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildArticleList(String status) {
    final filtered = _store.articles.where((a) {
      final matchesStatus = a.status == status;
      final matchesCategory = _selectedCategory == 'All' || a.category == _selectedCategory;
      return matchesStatus && matchesCategory;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'pending' ? Icons.inbox : status == 'approved' ? Icons.check_circle_outline : Icons.error_outline,
              size: 64,
              color: Colors.white30,
            ),
            const SizedBox(height: 16),
            Text(
              'No $status articles',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildArticleCard(filtered[index], status),
    );
  }

  Widget _buildArticleCard(ContentArticle article, String status) {
    Color statusColor;
    switch (status) {
      case 'pending':
        statusColor = const Color(0xFFFFB74D);
        break;
      case 'approved':
        statusColor = const Color(0xFF00BFA5);
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withAlpha((0.1 * 255).round()),
            Colors.white.withAlpha((0.05 * 255).round()),
          ],
        ),
        border: Border.all(
          color: statusColor.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        article.category,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (article.isAdminPost)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB74D).withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            color: Color(0xFFFFB74D),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _formatDate(article.createdAt),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  article.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  article.body.length > 150 ? '${article.body.substring(0, 150)}...' : article.body,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.white60, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      article.authorName,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.remove_red_eye, color: Colors.white60, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      article.views.toString(),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.favorite, color: Colors.white60, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      article.likes.toString(),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (status == 'pending') ...[
                      IconButton(
                        icon: const Icon(Icons.check, color: Color(0xFF00BFA5)),
                        onPressed: () => _approveArticle(article),
                        tooltip: 'Approve',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectArticle(article),
                        tooltip: 'Reject',
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Color(0xFF00BFA5)),
                      onPressed: () => _viewArticle(article),
                      tooltip: 'View Full',
                    ),
                    if (article.isAdminPost)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFFFFB74D)),
                        onPressed: () => _editArticle(article),
                        tooltip: 'Edit',
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteArticle(article),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _approveArticle(ContentArticle article) async {
    final messenger = ScaffoldMessenger.of(context);
    await _store.approveArticle(article.id);
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Article approved!'),
          backgroundColor: Color(0xFF00BFA5),
        ),
      );
    }
  }

  void _rejectArticle(ContentArticle article) async {
    final messenger = ScaffoldMessenger.of(context);
    await _store.rejectArticle(article.id);
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Article rejected'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewArticle(ContentArticle article) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5).withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      article.category,
                      style: const TextStyle(
                        color: Color(0xFF00BFA5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                article.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, color: Colors.white60, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    article.authorName,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _formatDate(article.createdAt),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    article.body,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.remove_red_eye, color: Colors.white60, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    article.views.toString(),
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.favorite, color: Colors.white60, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    article.likes.toString(),
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteArticle(ContentArticle article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Article', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${article.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await _store.deleteArticle(article.id);
              if (mounted) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Article deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreateArticleDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedCategory = _store.categories.isNotEmpty ? _store.categories.first.name : 'General';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create Admin Article', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor: const Color(0xFF0A1628),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: _store.categories
                        .map((c) => DropdownMenuItem(
                              value: c.name,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      labelStyle: TextStyle(color: Colors.white70),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty && bodyController.text.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final article = ContentArticle(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text,
                    body: bodyController.text,
                    category: selectedCategory,
                    authorName: 'Admin',
                    authorId: 'admin',
                    status: 'approved', // Admin posts auto-approved
                    isAdminPost: true,
                    createdAt: DateTime.now(),
                  );
                  await _store.addArticle(article);
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Article created successfully!'),
                        backgroundColor: Color(0xFF00BFA5),
                      ),
                    );
                  }
                }
              },
              child: const Text('Create', style: TextStyle(color: Color(0xFF00BFA5))),
            ),
          ],
        ),
      ),
    );
  }

  void _editArticle(ContentArticle article) {
    final titleController = TextEditingController(text: article.title);
    final bodyController = TextEditingController(text: article.body);
    String selectedCategory = article.category;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1628),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Article', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor: const Color(0xFF0A1628),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: _store.categories
                        .map((c) => DropdownMenuItem(
                              value: c.name,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedCategory = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      labelStyle: TextStyle(color: Colors.white70),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty && bodyController.text.isNotEmpty) {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final updatedArticle = ContentArticle(
                    id: article.id,
                    title: titleController.text,
                    body: bodyController.text,
                    category: selectedCategory,
                    authorName: article.authorName,
                    authorId: article.authorId,
                    status: article.status,
                    isAdminPost: article.isAdminPost,
                    createdAt: article.createdAt,
                    views: article.views,
                    likes: article.likes,
                  );
                  await _store.updateArticle(updatedArticle);
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Article updated successfully!'),
                        backgroundColor: Color(0xFF00BFA5),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Color(0xFF00BFA5))),
            ),
          ],
        ),
      ),
    );
  }
}
