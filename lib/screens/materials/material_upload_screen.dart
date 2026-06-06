import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/learning_level.dart';
import '../../models/question_generation_mode.dart';
import '../../models/question_setup_config.dart';
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
  bool _appendToExistingSession = false;
  bool _regenerateCurriculum = false;
  int? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<LearningProvider>().fetchUserSessions(user.id);
      }
    });
  }

  Future<void> _pickFiles() async {
    try {
      final files = await _materialService.pickMaterialFiles();
      if (files.isNotEmpty) {
        setState(() {
          _selectedFiles = files;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 선택 실패: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _uploadAndMoveToSetup() async {
    if (_selectedFiles.isEmpty) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (_appendToExistingSession && _selectedSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자료를 추가할 기존 로드맵을 선택해 주세요.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

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

    setState(() {
      _isUploading = true;
    });

    try {
      final fields = <String, String>{
        'user_id': user.id.toString(),
        'generation_mode': QuestionGenerationMode.materialOnly.apiValue,
        'difficulty': LearningLevel.beginner.apiValue,
      };
      if (_appendToExistingSession && _selectedSessionId != null) {
        fields['session_id'] = _selectedSessionId.toString();
        fields['regenerate_curriculum'] = _regenerateCurriculum.toString();
      }

      final response = await _apiService.uploadFiles('/api/upload-material', filesWithBytes, fields);

      if (!mounted) return;
      final learningProvider = context.read<LearningProvider>();
      learningProvider.loadSessionFromUploadResponse(response);
      await learningProvider.fetchUserSessions(user.id);
      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      final uploadedFiles = response['uploaded_files'] as List<dynamic>? ?? [];
      final uploadedCount = uploadedFiles.length;
      final appended = response['appended_to_session'] == true;
      final regenerated = response['regenerated_curriculum'] == true;
      final message = appended
          ? regenerated
              ? '🎉 기존 로드맵에 자료 $uploadedCount개를 추가하고 커리큘럼을 재생성했습니다.'
              : '🎉 기존 로드맵에 자료 $uploadedCount개를 추가했습니다.'
          : '🎉 자료 $uploadedCount개 분석 완료! 이제 생성 방식과 학습 수준을 선택해 주세요.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: const Color(0xFF58CC02)),
      );

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.questionSetup,
        arguments: QuestionSetupArguments(
          topic: learningProvider.currentSubject,
          existingSessionId: learningProvider.currentSessionId,
          fromUploadedMaterial: true,
          initialMode: QuestionGenerationMode.materialOnly,
          initialLevel: learningProvider.selectedLearningLevel,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
      );
    }
  }

  int? _readSessionId(Map<String, dynamic> session) {
    final rawId = session['id'];
    if (rawId is int) return rawId;
    if (rawId is num) return rawId.toInt();
    return int.tryParse(rawId?.toString() ?? '');
  }

  String _fileSizeLabel(PlatformFile file) {
    return '${(file.size / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final learningProvider = context.watch<LearningProvider>();
    final sessions = learningProvider.userSessions;
    final hasSessions = sessions.isNotEmpty;
    final canUpload = _selectedFiles.isNotEmpty && (!_appendToExistingSession || _selectedSessionId != null);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('자료 업로드', style: TextStyle(color: Color(0xFF3C3C3C), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF3C3C3C)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
              ),
              child: const Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 64, color: Color(0xFF1899D6)),
                  SizedBox(height: 16),
                  Text('학습할 문서 업로드', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3C3C3C))),
                  SizedBox(height: 8),
                  Text(
                    'PDF, PPTX, TXT 파일을 여러 개 업로드하면\nAI가 파일별 본문을 합쳐 커리큘럼 및 퀴즈를 출제합니다.\n업로드 후 문제 생성 설정 화면으로 이동합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('업로드 방식', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                  const SizedBox(height: 8),
                  RadioListTile<bool>(
                    value: false,
                    groupValue: _appendToExistingSession,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('새 로드맵 만들기'),
                    subtitle: const Text('업로드한 자료를 바탕으로 새 학습 코스를 생성합니다.'),
                    onChanged: (value) {
                      setState(() {
                        _appendToExistingSession = value ?? false;
                        _selectedSessionId = null;
                        _regenerateCurriculum = false;
                      });
                    },
                  ),
                  RadioListTile<bool>(
                    value: true,
                    groupValue: _appendToExistingSession,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('기존 로드맵에 추가하기'),
                    subtitle: const Text('기존 source_text 뒤에 새 자료 내용을 이어 붙입니다.'),
                    onChanged: hasSessions
                        ? (value) {
                            setState(() {
                              _appendToExistingSession = value ?? true;
                            });
                          }
                        : null,
                  ),
                  if (!hasSessions)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, top: 4),
                      child: Text('추가할 기존 로드맵이 없습니다. 먼저 새 로드맵을 만들어 주세요.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  if (_appendToExistingSession && hasSessions) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedSessionId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: '자료를 추가할 로드맵 선택',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: sessions
                          .where((session) => _readSessionId(session) != null)
                          .map(
                            (session) => DropdownMenuItem<int>(
                              value: _readSessionId(session),
                              child: Text(session['subject']?.toString() ?? '이름 없는 로드맵', overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSessionId = value;
                        });
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _regenerateCurriculum,
                      title: const Text('자료 추가 후 커리큘럼 재생성'),
                      subtitle: const Text('끄면 기존 로드맵 단계는 유지하고 문제 생성 참고자료만 보강합니다.'),
                      onChanged: (value) {
                        setState(() {
                          _regenerateCurriculum = value ?? false;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _selectedFiles.isNotEmpty ? const Color(0xFF1899D6) : const Color(0xFFE5E5E5), width: 2),
              ),
              child: _selectedFiles.isEmpty
                  ? const ListTile(
                      leading: Icon(Icons.insert_drive_file_outlined, color: Colors.grey, size: 32),
                      title: Text('선택된 파일 없음', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      subtitle: Text('PDF, PPT, PPTX, TXT 파일 지원', style: TextStyle(fontSize: 12)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('선택된 파일 ${_selectedFiles.length}개', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3C3C3C))),
                        const SizedBox(height: 8),
                        ..._selectedFiles.map(
                          (file) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.insert_drive_file, color: Color(0xFF1899D6), size: 28),
                            title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(_fileSizeLabel(file)),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
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
              DuoButton(text: '파일 여러 개 선택하기', color: const Color(0xFF1899D6), shadowColor: const Color(0xFF147EA9), onPressed: _pickFiles),
              const SizedBox(height: 16),
              DuoButton(
                text: _appendToExistingSession ? '기존 로드맵에 자료 추가' : '자료 분석 후 설정하기',
                color: const Color(0xFF58CC02),
                shadowColor: const Color(0xFF46A302),
                onPressed: canUpload ? _uploadAndMoveToSetup : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
