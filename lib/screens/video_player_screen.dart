import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:course/generated/app_localizations.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String lessonTitle;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.lessonTitle,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // Обычное видео
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoFuture;

  // YouTube-видео
  YoutubePlayerController? _youtubeController;
  bool _isYoutube = false;

  @override
  void initState() {
    super.initState();

    final rawUrl = widget.videoUrl.trim();
    debugPrint('VideoPlayerScreen URL: $rawUrl');

    // Пытаемся распознать YouTube-ссылку
    final youtubeId = YoutubePlayer.convertUrlToId(rawUrl);
    debugPrint('Parsed YouTube ID: $youtubeId');

    if (youtubeId != null && youtubeId.isNotEmpty) {
      // Это YouTube
      _isYoutube = true;

      _youtubeController = YoutubePlayerController(
        initialVideoId: youtubeId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
        ),
      );
    } else {
      // Пытаемся проиграть как обычное network-видео
      if (rawUrl.isEmpty) {
        debugPrint('Empty video url passed to VideoPlayerScreen');
        return;
      }

      _videoController = VideoPlayerController.networkUrl(Uri.parse(rawUrl));

      _initializeVideoFuture = _videoController!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _videoController!.play();
      }).catchError((error) {
        debugPrint("Error initializing video player: $error");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.videoErrorLoading(error))),
        );
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonTitle),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: _isYoutube ? _buildYoutubePlayer() : _buildNativePlayer(),
      ),
      floatingActionButton: !_isYoutube && _videoController != null
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            )
          : null,
    );
  }

  /// Плеер для YouTube
  Widget _buildYoutubePlayer() {
    if (_youtubeController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
      ),
      builder: (context, player) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: player,
            ),
          ],
        );
      },
    );
  }

  /// Плеер для обычных сетевых видео (MP4/HLS и т.п.)
  Widget _buildNativePlayer() {
    if (_videoController == null) {
      return Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          AppLocalizations.of(context)!.videoUrlNotSupported,
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }

    return FutureBuilder<void>(
      future: _initializeVideoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !_videoController!.value.hasError) {
          return AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          );
        } else if (snapshot.hasError ||
            (_videoController!.value.hasError &&
                snapshot.connectionState == ConnectionState.done)) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.videoLoadFailed,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                if (snapshot.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      snapshot.error.toString(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}
