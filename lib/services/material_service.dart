import 'package:file_picker/file_picker.dart';

class MaterialService {
  Future<List<PlatformFile>> pickMaterialFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'ppt', 'pptx', 'txt'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    return result.files;
  }

  // 기존 단일 파일명 반환 API를 사용하는 코드가 있어도 깨지지 않도록 유지합니다.
  Future<String?> pickMaterialFile() async {
    final files = await pickMaterialFiles();
    if (files.isEmpty) {
      return null;
    }

    return files.first.name;
  }
}
