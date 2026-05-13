import 'package:flutter/material.dart';

import '../../services/material_service.dart';

class MaterialUploadScreen extends StatefulWidget {
  const MaterialUploadScreen({super.key});

  @override
  State<MaterialUploadScreen> createState() => _MaterialUploadScreenState();
}

class _MaterialUploadScreenState extends State<MaterialUploadScreen> {
  final MaterialService _materialService = MaterialService();
  String? selectedFileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('자료 업로드'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.upload_file),
                title: Text(selectedFileName ?? '선택된 파일 없음'),
                subtitle: const Text('PDF, PPT, TXT 파일을 업로드할 수 있습니다.'),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  final fileName = await _materialService.pickMaterialFile();

                  if (fileName != null) {
                    setState(() {
                      selectedFileName = fileName;
                    });
                  }
                },
                child: const Text('파일 선택'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: selectedFileName == null
                    ? null
                    : () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('자료 분석 완료'),
                      content: Text(
                        '$selectedFileName 기반 문제를 생성할 수 있습니다.\n\n'
                            '현재는 UI 예시이며, 이후 서버 API와 연결하면 됩니다.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('자료 기반 문제 생성'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}