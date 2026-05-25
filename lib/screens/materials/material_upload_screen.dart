import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/learning_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../widgets/common/duo_button.dart';
import '../../models/lesson_model.dart';

class MaterialUploadScreen extends StatefulWidget {
  const MaterialUploadScreen({super.key});

  @override
  State<MaterialUploadScreen> createState() => _MaterialUploadScreenState();
}

class _MaterialUploadScreenState extends State<MaterialUploadScreen> {
  final ApiService _apiService = ApiService();
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  void _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'ppt', 'pptx', 'txt'],
        withData: true, // Web/Mobile 둘 다 바이트 추출 활성화
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('파일 선택 실패: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _uploadAndGenerateRoadmap() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // Multipart 파일 업로드 호출
      final response = await _apiService.uploadFile(
        '/api/upload-material',
        _selectedFile!.bytes!,
        _selectedFile!.name,
        {
          "user_id": user.id.toString(),
        },
      );

      // 응답 데이터에서 세션 정보 구성
      final List<dynamic> curriculumJson = response['curriculum'] ?? [];
      final List<LessonModel> lessons = curriculumJson.map((json) {
        return LessonModel(
          id: json['id'] ?? 0,
          title: json['title']?.toString() ?? '',
          description: json['description']?.toString() ?? '',
          level: json['level'] ?? 1,
          isLocked: json['isLocked'] ?? true,
          isCompleted: json['isCompleted'] ?? false,
        );
      }).toList();

      final session = {
        "id": response['session_id'],
        "subject": response['subject'],
        "lessons": lessons,
      };

      if (!mounted) return;

      // 1. 학습 상태 적재
      final learningProvider = context.read<LearningProvider>();
      learningProvider.loadSession(session);
      
      // 사용자 세션 전체 리스트 동기화
      await learningProvider.fetchUserSessions(user.id);

      setState(() {
        _isUploading = false;
      });

      // 2. 단원(레벨) 코스로 즉시 이동
      Navigator.pushReplacementNamed(context, AppRoutes.lessons);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 업로드한 문서 분석 완료! 맞춤형 학습 코스가 생성되었습니다.'),
          backgroundColor: Color(0xFF58CC02),
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '자료 업로드',
          style: TextStyle(color: Color(0xFF3C3C3C), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF3C3C3C)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 설명 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 64, color: Color(0xFF1899D6)),
                  const SizedBox(height: 16),
                  const Text(
                    '학습할 문서 업로드',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3C3C3C)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PDF, PPTX, TXT 파일 등의 자료를 업로드하면\nAI가 자료 속 본문을 바탕으로\n듀오링고 학습 커리큘럼 및 퀴즈를 출제합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 선택된 파일 정보 카드
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedFile != null ? const Color(0xFF1899D6) : const Color(0xFFE5E5E5),
                  width: 2,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  _selectedFile != null ? Icons.insert_drive_file : Icons.insert_drive_file_outlined,
                  color: _selectedFile != null ? const Color(0xFF1899D6) : Colors.grey,
                  size: 32,
                ),
                title: Text(
                  _selectedFile?.name ?? '선택된 파일 없음',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _selectedFile != null ? const Color(0xFF3C3C3C) : Colors.grey,
                  ),
                ),
                subtitle: Text(
                  _selectedFile != null 
                      ? '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB'
                      : 'PDF, PPTX, TXT 파일 지원',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            if (_isUploading)
              Center(
                child: Column(
                  children: const [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1899D6)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'AI가 대량의 문서를 분석하고\n학습 로드맵을 작성하고 있습니다...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3C3C3C)),
                    ),
                  ],
                ),
              )
            else ...[
              DuoButton(
                text: '파일 선택하기',
                color: const Color(0xFF1899D6),
                shadowColor: const Color(0xFF147EA9),
                onPressed: _pickFile,
              ),
              const SizedBox(height: 16),
              DuoButton(
                text: '자료 분석 및 퀴즈 코스 생성',
                color: const Color(0xFF58CC02),
                shadowColor: const Color(0xFF46A302),
                onPressed: _selectedFile == null ? null : _uploadAndGenerateRoadmap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}