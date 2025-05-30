import 'package:flutter/material.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';

class WatermarkMinimalUI extends StatelessWidget {
  final File? mediaFile;
  final File? watermarkFile;
  final String? resultFilePath;
  final bool isProcessing;
  final VoidCallback onPickMedia;
  final VoidCallback onPickWatermark;
  final VoidCallback onEmbedVisible;
  final VoidCallback onEmbedInvisible;
  final VoidCallback onExtract;
  final VoidCallback onDownload;

  const WatermarkMinimalUI({
    super.key,
    required this.mediaFile,
    required this.watermarkFile,
    required this.resultFilePath,
    required this.isProcessing,
    required this.onPickMedia,
    required this.onPickWatermark,
    required this.onEmbedVisible,
    required this.onEmbedInvisible,
    required this.onExtract,
    required this.onDownload,
  });

  Widget _previewSection(String label, Widget content, VoidCallback onTap, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: content),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            label: const Text("Chọn"),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaPreview = mediaFile != null
        ? (mediaFile!.path.endsWith('.mp4')
        ? VideoWidget(videoFile: mediaFile!)
        : Image.file(mediaFile!, fit: BoxFit.contain))
        : const Text("Chưa có file", style: TextStyle(color: Colors.grey));

    final watermarkPreview = watermarkFile != null
        ? Image.file(watermarkFile!, fit: BoxFit.contain)
        : const Text("Chưa có watermark", style: TextStyle(color: Colors.grey));

    final resultPreview = resultFilePath != null
        ? (resultFilePath!.endsWith('.mp4')
        ? VideoWidget(videoFile: File(resultFilePath!))
        : Image.file(File(resultFilePath!), fit: BoxFit.contain))
        : const Text("Chưa có kết quả", style: TextStyle(color: Colors.grey));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thủy vân số"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _previewSection("📥 File gốc", mediaPreview, onPickMedia, Icons.upload_file),
            const SizedBox(height: 20),
            _previewSection("🧼 Watermark", watermarkPreview, onPickWatermark, Icons.water_drop),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: onEmbedVisible, child: const Text("Nhúng hiển thị")),
                ElevatedButton(onPressed: onEmbedInvisible, child: const Text("Nhúng ẩn")),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(onPressed: onExtract, child: const Text("Trích watermark")),
            ),
            const SizedBox(height: 30),
            Text("📤 Kết quả", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: resultPreview),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.save_alt),
                label: const Text("Tải xuống"),
              ),
            ),
            if (isProcessing) const SizedBox(height: 20),
            if (isProcessing) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}


class VideoWidget extends StatefulWidget {
  final File videoFile;
  const VideoWidget({super.key, required this.videoFile});

  @override
  State<VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _controller;
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void didUpdateWidget(VideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoFile.path != widget.videoFile.path) {
      _controller.pause();
      _controller.dispose();
      _controller = VideoPlayerController.file(widget.videoFile)
        ..initialize().then((_) {
          setState(() {});
          _controller.setLooping(true);
          _controller.play();
        });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showOverlay = true;
      } else {
        _controller.play();
        _showOverlay = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying || _showOverlay)
            Container(
              color: Colors.black45,
              child: const Icon(Icons.play_arrow, size: 64, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
