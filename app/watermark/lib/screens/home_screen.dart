import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _mediaFile;
  File? _watermark;
  bool _isProcessing = false;
  String? _resultFilePath;

  Future<void> _extractInvisibleWatermark() async {
    if (_mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❗ Vui lòng chọn ảnh hoặc video trước')),
      );
      return;
    }

    bool isVideo = _mediaFile!.path.toLowerCase().endsWith('.mp4');

    setState(() {
      _isProcessing = true;
      _resultFilePath = null;
    });

    try {
      var dio = Dio();
      var formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_mediaFile!.path),
        'type': isVideo ? 'video' : 'image',
      });

      Response response = await dio.post(
        'http://192.168.1.249:5000/extract_invisible_watermark',
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200 && response.data.isNotEmpty) {
        var permission = await Permission.storage.request();
        if (!permission.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠ Không có quyền lưu trữ')),
          );
          return;
        }

        final downloadsDir = Platform.isAndroid
            ? Directory('/storage/emulated/0/Download')
            : await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

        String filePath = '${downloadsDir.path}/extracted_watermark_${DateTime.now().millisecondsSinceEpoch}.png';
        File resultFile = File(filePath);
        await resultFile.writeAsBytes(response.data);

        if (await resultFile.exists()) {
          setState(() {
            _resultFilePath = filePath;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Đã trích xuất watermark ẩn thành công!')),
          );
        } else {
          throw Exception('Không ghi được file!');
        }
      } else {
        throw Exception('Lỗi xử lý từ server hoặc không có dữ liệu!');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }


  Future<void> _pickMedia() async {
    final pickedFile = await ImagePicker().pickMedia();
    if (pickedFile != null) {
      setState(() {
        _mediaFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickWatermark() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _watermark = File(pickedFile.path);
      });
    }
  }

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
        'file': await MultipartFile.fromFile(_mediaFile!.path, filename: 'input.${isVideo ? 'mp4' : 'png'}'),
        'watermark': await MultipartFile.fromFile(_watermark!.path, filename: 'watermark.png'),
        'type': isVideo ? 'video' : 'image',
      });

      Response response = await dio.post(
        'http://192.168.1.249:5000/embed_${isVisibleWatermark ? 'visible' : 'invisible'}_watermark',
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200 && response.data.isNotEmpty) {
        // Yêu cầu quyền lưu trữ
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ứng dụng cần quyền truy cập bộ nhớ để lưu file.')),
          );
          return;
        }

        // Lấy thư mục Downloads (Android/iOS)
        Directory downloadsDir;
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
        } else {
          downloadsDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        }

        String fileExtension = isVideo ? 'mp4' : 'png';
        String fileName = 'watermarked_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        String filePath = '${downloadsDir.path}/$fileName';

        File resultFile = File(filePath);
        await resultFile.writeAsBytes(response.data);

        if (await resultFile.exists()) {
          setState(() {
            _resultFilePath = filePath;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Đã lưu kết quả tại: ${downloadsDir.path}')),
          );
        } else {
          throw Exception("Lỗi ghi file kết quả!");
        }
      }
      else {
        throw Exception("Lỗi xử lý ảnh/video: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Widget _buildPreview(File? file) {
    if (file == null) return Text('Chưa chọn ảnh hoặc video');

    return Container(
      height: 200,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: file.path.toLowerCase().endsWith('.mp4')
            ? VideoWidget(videoFile: file)
            : Image.file(file, fit: BoxFit.cover, width: double.infinity),
      ),
    );
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
      appBar: AppBar(title: const Text('Ứng dụng Nhúng Watermark')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text("Xem trước ảnh/video", style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 10),
                      _buildPreview(_mediaFile),
                      if (_mediaFile != null) Text("Đã chọn: ${_mediaFile!.path.split('/').last}"),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text("Watermark", style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 10),
                      _watermark != null
                          ? Image.file(_watermark!, height: 50)
                          : Text('Chưa chọn watermark'),
                      if (_watermark != null) Text("Đã chọn: ${_watermark!.path.split('/').last}"),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.photo_library),
                    onPressed: _pickMedia,
                    label: Text('Chọn ảnh/video'),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.image),
                    onPressed: _pickWatermark,
                    label: Text('Chọn watermark'),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.visibility),
                    onPressed: () => _uploadMedia(true),
                    label: Text('Thủy vân hiển thị'),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.visibility_off),
                    onPressed: () => _uploadMedia(false),
                    label: Text('Thủy vân ẩn'),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.water_damage),
                    onPressed: _extractInvisibleWatermark,
                    label: Text('Trích xuất thủy vân ẩn'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              if (_isProcessing) Center(child: CircularProgressIndicator()),
              if (!_isProcessing && _resultFilePath != null) ...[
                Divider(height: 40),
                Text("Kết quả", style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 10),
                _buildPreview(File(_resultFilePath!)),
                SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: Icon(Icons.download),
                  onPressed: _downloadResult,
                  label: Text('Tải xuống'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
        _controller.setLooping(true);
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
        : Center(child: CircularProgressIndicator());
  }
}
