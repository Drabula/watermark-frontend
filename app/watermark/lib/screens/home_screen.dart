import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watermark/screens/watermarkUI.dart';

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

  final double _alpha = 0.1;
  final double _scale = 0.25;
  int? _wmH;
  int? _wmW;

  Future<void> _extractDWTWatermark() async {
    if (_mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❗ Chưa chọn file để trích watermark')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _resultFilePath = null;
    });

    try {
      final isVideo = _mediaFile!.path.toLowerCase().endsWith('.mp4');

      if (!isVideo) {
        final imageBytes = await _watermark!.readAsBytes();
        final decodedImage = await decodeImageFromList(imageBytes);
        _wmH = decodedImage.height;
        _wmW = decodedImage.width;
      } else {
        _wmH = 150;
        _wmW = 150;
      }

      final dio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_mediaFile!.path),
        'wm_h': _wmH.toString(),
        'wm_w': _wmW.toString(),
        'alpha': _alpha.toString(),
      });

      final response = await dio.post(
        isVideo
            ? 'http://192.168.51.249:5000/extract_dwt_video'
            : 'http://192.168.51.249:5000/extract_dwt',
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      final downloadsDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();

      final filePath =
          '${downloadsDir.path}/extracted_dwt_${DateTime
          .now()
          .millisecondsSinceEpoch}.png';

      final resultFile = File(filePath);
      await resultFile.writeAsBytes(response.data);

      setState(() {
        _resultFilePath = filePath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Trích watermark ẩn thành công!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $e')),
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
        _resultFilePath = null;
      });
    }
  }

  Future<void> _pickWatermark() async {
    final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery);
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

      String endpoint;
      if (isVisibleWatermark) {
        endpoint = 'embed_visible_watermark';
      } else {
        endpoint = isVideo ? 'embed_dwt_video' : 'embed_dwt';
      }

      var formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
            _mediaFile!.path, filename: 'input.${isVideo ? 'mp4' : 'png'}'),
        'watermark': await MultipartFile.fromFile(
            _watermark!.path, filename: 'watermark.png'),
        'type': isVideo ? 'video' : 'image',
        if (!isVisibleWatermark) 'alpha': _alpha.toString(),
        if (!isVisibleWatermark && !isVideo) 'scale': _scale.toString(),
        // chỉ ảnh mới cần scale
      });

      Response response = await dio.post(
        'http://192.168.51.249:5000/$endpoint',
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      final downloadsDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();

      String fileExtension = isVideo ? 'mp4' : 'png';
      String fileName = 'watermarked_${DateTime
          .now()
          .millisecondsSinceEpoch}.$fileExtension';
      String filePath = '${downloadsDir.path}/$fileName';

      File resultFile = File(filePath);
      await resultFile.writeAsBytes(response.data);

      setState(() {
        _resultFilePath = filePath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Đã lưu kết quả tại: ${downloadsDir.path}')),
      );
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
    if (file == null) return const Text('Chưa chọn ảnh hoặc video');

    bool isVideo = file.path.toLowerCase().endsWith('.mp4');
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isVideo
            ? VideoWidget(key: ValueKey(file.path), videoFile: file)
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
    return WatermarkMinimalUI(
      mediaFile: _mediaFile,
      watermarkFile: _watermark,
      resultFilePath: _resultFilePath,
      isProcessing: _isProcessing,
      onPickMedia: _pickMedia,
      onPickWatermark: _pickWatermark,
      onEmbedVisible: () => _uploadMedia(true),
      onEmbedInvisible: () => _uploadMedia(false),
      onExtract: _extractDWTWatermark,
      onDownload: _downloadResult,
    );
  }
}