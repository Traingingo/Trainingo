import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quiz_setup_options.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/material_service.dart';
import '../../widgets/common/duo_button.dart';

class MaterialUploadScreen extends StatefulWidget {
  const MaterialUploadScreen({super.key});

  @override
  State<MaterialUploadScreen> createState() => _MaterialUploadScreenState();
}

class _MaterialUploadScreenState extends State<MaterialUploadScreen> {
  final ApiService _apiService = ApiService();
  final MaterialService _materialService = MaterialService();

  List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  QuizSetupResult? _setup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is QuizSetupResult && _setup == null) {
      _setup = args;
      context.read<LearningProvider>().setQuizSetup(
            generationMode: args.generationMode,
            learningLevel: args.learningLevel,
          );
    }
  }

  QuizSetupResult get _effectiveSetup {
    return _setup ??
        const QuizSetupResult(
          topic: '',
          generationMode: QuestionGenerationMode.materialOnly,
          learningLevel: LearningLevel.beginner,
        );
  }

  Future<void> _pickFiles() async {
    try {
      final files = await _materialService.pickMaterialFiles();
      if (files.isNotEmpty) setState(() => _selectedFiles = files);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('파일 선택 실패: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _uploadAndGenerateRoadmap() async {
    if (_selectedFiles.isEmpty) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final filesWithBytes = _selectedFiles
        .where((file) => file.bytes != null)
        .map((file) => UploadFileData(bytes: file.bytes!, filename: file.name))
        .toList();

    if (filesWithBytes.length != _selectedFiles.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택한 파일 중 바이트 데이터를 읽지 못한 파일이 있습니다. 다시 선택해 주세요.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isUploading = true);
    final setup = _effectiveSetup;

    try {
      final fields = <String, String>{
        'user_id': user.id.toString(),
        'generation_mode': setup.generationMode.apiValue,
        'learning_level': setup.learningLevel.apiValue,
        'difficulty': setup.learningLevel.label,
      };
      if (setup.topic.trim().isNotEmpty) fields['subject'] = setup.topic.trim();

      final response = await _apiService.uploadFiles('/api/upload-material', filesWithBytes, fields);
      if (!mounted) return;

      final learningProvider = context.read<LearningProvider>();
      learningProvider.loadSessionFromUploadResponse(response);
      await learningProvider.fetchUserSessions(user.id);
      if (!mounted) return;

      setState(() => _isUploading = false);
      final uploadedFiles = response['uploaded_files'] as List<dynamic>? ?? [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 자료 ${uploadedFiles.length}개 분석 완료! 맞춤형 학습 코스가 생성되었습니다.'), backgroundColor: const Color(0xFF58CC02)),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.lessons);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
      );
    }
  }

  String _fileSizeLabel(PlatformFile file) => '${(file.size / 1024).toStringAsFixed(1)} KB';

  @override
  Widget build(BuildContext context) {
    final setup = _effectiveSetup;
    final canUpload = _selectedFiles.isNotEmpty && !_isUploading;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('자료 업로드', style: TextStyle(color: Color(0xFF3C3C3C), fontWeight: FontWeight.w900)),
        iconTheme: const IconThemeData(color: Color(0xFF3C3C3C)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SetupSummary(setup: setup),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 64, color: Color(0xFF1899D6)),
                  const SizedBox(height: 16),
                  const Text('학습할 문서 업로드', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                  const SizedBox(height: 8),
                  const Text('PDF, PPTX, TXT 파일을 여러 개 업로드하면 선택한 방식과 수준에 맞춰 커리큘럼과 문제를 생성합니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4)),
                  const SizedBox(height: 18),
                  _selectedFiles.isEmpty
                      ? const ListTile(
                          leading: Icon(Icons.insert_drive_file_outlined, color: Colors.grey),
                          title: Text('선택된 파일 없음', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          subtitle: Text('PDF, PPT, PPTX, TXT 파일 지원'),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('선택된 파일 ${_selectedFiles.length}개', style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            ..._selectedFiles.map((file) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.insert_drive_file, color: Color(0xFF1899D6)),
                                  title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(_fileSizeLabel(file)),
                                )),
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (_isUploading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1899D6))),
                    SizedBox(height: 16),
                    Text('AI가 자료를 분석하고\n학습 로드맵을 준비하고 있습니다...', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3C3C3C))),
                  ],
                ),
              )
            else ...[
              DuoButton(text: '파일 여러 개 선택하기', color: const Color(0xFF1899D6), shadowColor: const Color(0xFF147EA9), icon: Icons.attach_file_rounded, onPressed: _pickFiles),
              const SizedBox(height: 14),
              DuoButton(text: '자료 분석 및 퀴즈 코스 생성', icon: Icons.auto_awesome_rounded, onPressed: canUpload ? _uploadAndGenerateRoadmap : null),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupSummary extends StatelessWidget {
  final QuizSetupResult setup;

  const _SetupSummary({required this.setup});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E5E5), width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('선택한 생성 설정', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(setup.generationMode.label)),
              Chip(label: Text(setup.learningLevel.label)),
              if (setup.topic.trim().isNotEmpty) Chip(label: Text(setup.topic.trim())),
            ],
          ),
        ],
      ),
    );
  }
}
