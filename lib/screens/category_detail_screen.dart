import 'package:flutter/material.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_models.dart';
import '../services/betting_data_store.dart';

class CategoryDetailScreen extends StatefulWidget {
  final CategoryModel category;
  final bool isAdmin;
  final Function(CategoryModel) onUpdate;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.isAdmin,
    required this.onUpdate,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late CategoryModel _category;
  final TextEditingController _headerController = TextEditingController();
  final TextEditingController _videoLinkController = TextEditingController();
  final TextEditingController _videoTitleController = TextEditingController();
  String _currentUsername = '';
  
  // Track which items current user has voted/liked
  Set<String> _votedImages = {};
  Set<String> _votedVideos = {};
  Set<String> _votedNominees = {};

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _currentUsername = BettingDataStore.instance.username;
    _loadUserVotesAndLikes();
    _sortContentByVotes();
  }

  void _sortContentByVotes() {
    setState(() {
      _category.images.sort((a, b) => b.votes.compareTo(a.votes));
      _category.videos.sort((a, b) => b.votes.compareTo(a.votes));
      _category.nominees.sort((a, b) => b.votes.compareTo(a.votes));
    });
  }

  Future<void> _loadUserVotesAndLikes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _votedImages = (prefs.getStringList('voted_images_$_currentUsername') ?? []).toSet();
      _votedVideos = (prefs.getStringList('voted_videos_$_currentUsername') ?? []).toSet();
      _votedNominees = (prefs.getStringList('voted_nominees_$_currentUsername') ?? []).toSet();
    });
  }

  Future<void> _saveVotesAndLikes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('voted_images_$_currentUsername', _votedImages.toList());
    await prefs.setStringList('voted_videos_$_currentUsername', _votedVideos.toList());
    await prefs.setStringList('voted_nominees_$_currentUsername', _votedNominees.toList());
  }

  Future<void> _toggleVoteImage(CategoryImage image) async {
    if (!_category.votingEnabled) return;
    
    setState(() {
      if (_votedImages.contains(image.id)) {
        _votedImages.remove(image.id);
        image.votes = (image.votes - 1).clamp(0, 999999);
      } else {
        _votedImages.add(image.id);
        image.votes++;
      }
    });
    await _saveVotesAndLikes();
    _sortContentByVotes();
    widget.onUpdate(_category);
  }

  Future<void> _toggleVoteVideo(CategoryVideo video) async {
    if (!_category.votingEnabled) return;
    
    setState(() {
      if (_votedVideos.contains(video.id)) {
        _votedVideos.remove(video.id);
        video.votes = (video.votes - 1).clamp(0, 999999);
      } else {
        _votedVideos.add(video.id);
        video.votes++;
      }
    });
    await _saveVotesAndLikes();
    _sortContentByVotes();
    widget.onUpdate(_category);
  }

  Future<void> _toggleVoteNominee(ArtistNominee nominee) async {
    if (!_category.votingEnabled) return;
    
    setState(() {
      if (_votedNominees.contains(nominee.id)) {
        _votedNominees.remove(nominee.id);
        nominee.votes = (nominee.votes - 1).clamp(0, 999999);
      } else {
        _votedNominees.add(nominee.id);
        nominee.votes++;
      }
    });
    await _saveVotesAndLikes();
    _sortContentByVotes();
    widget.onUpdate(_category);
  }

  Future<void> _toggleLikeImage(CategoryImage image) async {
    setState(() {
      if (image.likes.contains(_currentUsername)) {
        image.likes.remove(_currentUsername);
      } else {
        image.likes.add(_currentUsername);
      }
    });
    widget.onUpdate(_category);
  }

  Future<void> _toggleLikeVideo(CategoryVideo video) async {
    setState(() {
      if (video.likes.contains(_currentUsername)) {
        video.likes.remove(_currentUsername);
      } else {
        video.likes.add(_currentUsername);
      }
    });
    widget.onUpdate(_category);
  }

  Future<void> _toggleLikeNominee(ArtistNominee nominee) async {
    setState(() {
      if (nominee.likes.contains(_currentUsername)) {
        nominee.likes.remove(_currentUsername);
      } else {
        nominee.likes.add(_currentUsername);
      }
    });
    widget.onUpdate(_category);
  }

  Future<void> _openYouTubeLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open YouTube link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showFullscreenImage(CategoryImage image) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(image.imageUrl),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 100),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _headerController.dispose();
    _videoLinkController.dispose();
    _videoTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(_category.icon, color: _category.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _category.title,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // NO actions - remove "+" button from user view
        // All content management happens in Admin Media Control panel
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _category.color.withAlpha((0.3 * 255).round()),
                    _category.color.withAlpha((0.15 * 255).round()),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _category.color, width: 2),
              ),
              child: Column(
                children: [
                  Icon(_category.icon, color: _category.color, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _category.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Images section
            if (_category.images.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.photo_library, color: _category.color, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Images',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 16 / 9, // YouTube thumbnail aspect ratio
                ),
                itemCount: _category.images.length,
                itemBuilder: (context, index) => _buildImageCard(_category.images[index]),
              ),
              const SizedBox(height: 24),
            ],
            
            // Videos section
            if (_category.videos.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.video_library, color: _category.color, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Videos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._category.videos.map((video) => _buildVideoCard(video)),
              const SizedBox(height: 24),
            ],
            
            // Nominees section
            if (_category.nominees.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.stars, color: _category.color, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Nominees',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._category.nominees.map((nominee) => _buildNomineeCard(nominee)),
              const SizedBox(height: 24),
            ],
            
            // Empty state
            if (_category.images.isEmpty && _category.videos.isEmpty && _category.nominees.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.05 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withAlpha((0.1 * 255).round()),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No content yet',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.7 * 255).round()),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check back later for updates!',
                        style: TextStyle(
                          color: Colors.white.withAlpha((0.5 * 255).round()),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(CategoryImage image) {
    final hasVoted = _votedImages.contains(image.id);
    final hasLiked = image.likes.contains(_currentUsername);
    
    return GestureDetector(
      onTap: () => _showFullscreenImage(image),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _category.color.withAlpha((0.3 * 255).round()),
              _category.color.withAlpha((0.15 * 255).round()),
            ],
          ),
          border: Border.all(
            color: _category.color.withAlpha((0.5 * 255).round()),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image with 16:9 aspect ratio
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(
                  File(image.imageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.withAlpha((0.3 * 255).round()),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: _category.color, size: 48),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Image not available',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // Caption overlay
              if (image.caption != null && image.caption!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha((0.8 * 255).round()),
                        ],
                      ),
                    ),
                    child: Text(
                      image.caption!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              
              // Vote and Like buttons (top right)
              Positioned(
                top: 4,
                right: 4,
                child: Column(
                  children: [
                    // Vote button (only if voting enabled)
                    if (_category.votingEnabled)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha((0.6 * 255).round()),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _toggleVoteImage(image),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_upward,
                                    size: 16,
                                    color: hasVoted ? Colors.green : Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${image.votes}',
                                    style: TextStyle(
                                      color: hasVoted ? Colors.green : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Like button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.6 * 255).round()),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _toggleLikeImage(image),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasLiked ? Icons.favorite : Icons.favorite_border,
                                  size: 16,
                                  color: hasLiked ? Colors.red : Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${image.likes.length}',
                                  style: TextStyle(
                                    color: hasLiked ? Colors.red : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(CategoryVideo video) {
    final hasVoted = _votedVideos.contains(video.id);
    final hasLiked = video.likes.contains(_currentUsername);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _category.color.withAlpha((0.25 * 255).round()),
            _category.color.withAlpha((0.12 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _category.color.withAlpha((0.4 * 255).round()),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with 16:9 aspect ratio
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  video.thumbnailUrl != null
                      ? Image.file(
                          File(video.thumbnailUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: _category.color.withAlpha((0.3 * 255).round()),
                              child: Icon(
                                Icons.play_circle_filled,
                                color: Colors.white,
                                size: 64,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: _category.color.withAlpha((0.3 * 255).round()),
                          child: const Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                  // Play button overlay
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha((0.5 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  // Vote and Like buttons (top right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      children: [
                        // Vote button (only if voting enabled)
                        if (_category.votingEnabled)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha((0.7 * 255).round()),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _toggleVoteVideo(video),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 18,
                                        color: hasVoted ? Colors.green : Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${video.votes}',
                                        style: TextStyle(
                                          color: hasVoted ? Colors.green : Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        // Like button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha((0.7 * 255).round()),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _toggleLikeVideo(video),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasLiked ? Icons.favorite : Icons.favorite_border,
                                      size: 18,
                                      color: hasLiked ? Colors.red : Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${video.likes.length}',
                                      style: TextStyle(
                                        color: hasLiked ? Colors.red : Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Video details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Clickable YouTube link button
                  ElevatedButton.icon(
                    onPressed: () => _openYouTubeLink(video.youtubeUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 20, color: Colors.white),
                    label: const Text(
                      'Watch on YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNomineeCard(ArtistNominee nominee) {
    final hasVoted = _votedNominees.contains(nominee.id);
    final hasLiked = nominee.likes.contains(_currentUsername);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _category.color.withAlpha((0.2 * 255).round()),
            _category.color.withAlpha((0.1 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _category.color.withAlpha((0.3 * 255).round()),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Artist image with 16:9 aspect ratio
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: _category.color.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: nominee.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(nominee.imageUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person, color: _category.color, size: 32);
                          },
                        ),
                      )
                    : Icon(Icons.person, color: _category.color, size: 32),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nominee.artistName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (nominee.workTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      nominee.workTitle!,
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Vote button (only if voting enabled)
                      if (_category.votingEnabled)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: hasVoted
                                  ? [Colors.green.shade600, Colors.green.shade800]
                                  : [_category.color.withAlpha((0.6 * 255).round()), _category.color.withAlpha((0.8 * 255).round())],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: hasVoted 
                                    ? Colors.green.withAlpha((0.3 * 255).round())
                                    : _category.color.withAlpha((0.3 * 255).round()),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _toggleVoteNominee(nominee),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.arrow_upward,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${nominee.votes}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // Like button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: hasLiked
                                ? [Colors.red.shade600, Colors.red.shade800]
                                : [Colors.white.withAlpha((0.2 * 255).round()), Colors.white.withAlpha((0.1 * 255).round())],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasLiked ? Colors.red : Colors.white.withAlpha((0.3 * 255).round()),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _toggleLikeNominee(nominee),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasLiked ? Icons.favorite : Icons.favorite_border,
                                    size: 16,
                                    color: hasLiked ? Colors.white : Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${nominee.likes.length}',
                                    style: TextStyle(
                                      color: hasLiked ? Colors.white : Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.star, color: _category.color, size: 24),
          ],
        ),
      ),
    );
  }
}
