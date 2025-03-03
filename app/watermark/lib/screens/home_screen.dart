import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _mediaFile; // Ảnh hoặc video gốc
  File? _watermark; // Watermark
  bool _isProcessing = false; // Trạng thái xử lý
  String? _resultFilePath; // Đường dẫn ảnh/video kết quả


  // Hàm chọn ảnh hoặc video
  Future<void> _pickMedia() async {
    final pickedFile = await ImagePicker().pickMedia();
    if (pickedFile != null) {
      setState(() {
        _mediaFile = File(pickedFile.path);
      });
    }
  }

  // Hàm chọn watermark
  Future<void> _pickWatermark() async {
    final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _watermark = File(pickedFile.path);
      });
    }
  }

  // Hàm gửi ảnh/video và watermark lên Flask server
  Future<void> _uploadMedia(bool isVisibleWatermark) async {
    if (_mediaFile == null || _watermark == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng chọn ảnh/video và watermark')),
      );
      return;
    }

    bool isVideo = _mediaFile!.path.toLowerCase().endsWith('.mp4');

    setState(() {
      _isProcessing = true;
    });

    try {
      var dio = Dio();
      var formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
            _mediaFile!.path, filename: 'input.${isVideo ? 'mp4' : 'png'}'),
        'watermark': await MultipartFile.fromFile(
            _watermark!.path, filename: 'watermark.png'),
        'type': isVideo ? 'video' : 'image',
      });

      Response response = await dio.post(
        'http://192.168.1.249:5000/embed_${isVisibleWatermark
            ? 'visible'
            : 'invisible'}_watermark',
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      print("📌 Phản hồi server: ${response.statusCode}");
      print("📌 Headers: ${response.headers}");
      print("📌 Dữ liệu nhận về: ${response.data.length} bytes");

      if (response.statusCode == 200 && response.data.isNotEmpty) {
        String fileExtension = isVideo ? 'mp4' : 'png';
        String filePath = '${_mediaFile!.path}_watermarked.$fileExtension';
        File resultFile = File(filePath);
        await resultFile.writeAsBytes(response.data);

        if (await resultFile.exists()) {
          print("✅ File kết quả được lưu: $filePath");  // Debug
          setState(() {
            _resultFilePath = filePath;
          });
        } else {
          throw Exception("⚠ Lỗi ghi file kết quả!");
        }
      } else {
        throw Exception("⚠ Lỗi xử lý ảnh/video: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Lỗi khi gửi request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
       );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Hiển thị ảnh hoặc video
  Widget _buildPreview(File? file) {
    if (file == null) return Text('Chưa chọn ảnh hoặc video');

    if (file.path.toLowerCase().endsWith('.mp4')) {
      return VideoWidget(videoFile: file);
    } else {
      return Image.file(file, fit: BoxFit.cover);
    }
  }


  void _downloadResult() {
    if (_resultFilePath != null) {
      File file = File(_resultFilePath!);
      if (file.existsSync()) {
        OpenFilex.open(file.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠ File không tồn tại!')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Không có file để tải xuống!')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Watermark App')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildPreview(_mediaFile),
              SizedBox(height: 20),
              _watermark == null ? Text('Chưa chọn watermark') : Image.file(
                  _watermark!, height: 50),
              SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _pickMedia, child: Text('Chọn ảnh hoặc video')),
              SizedBox(height: 10),
              ElevatedButton(
                  onPressed: _pickWatermark, child: Text('Chọn watermark')),
              SizedBox(height: 20),
              ElevatedButton(onPressed: () => _uploadMedia(true),
                  child: Text('Nhúng thủy vân hiển thị')),
              SizedBox(height: 10),
              ElevatedButton(onPressed: () => _uploadMedia(false),
                  child: Text('Nhúng thủy vân ẩn')),
              SizedBox(height: 20),

              _isProcessing ? CircularProgressIndicator() :
              _resultFilePath != null
                  ? Column(
                children: [
                  _buildPreview(File(_resultFilePath!)),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _downloadResult,
                    child: Text('Tải xuống'),
                  ),
                ],
              )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }
}
// Widget để hiển thị video
class VideoWidget extends StatefulWidget {
  final File videoFile;
  const VideoWidget({required this.videoFile});

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    )
        : CircularProgressIndicator();
  }
}
