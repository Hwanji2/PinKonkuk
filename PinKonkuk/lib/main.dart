import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  // 데스크톱 환경에서 sqflite 초기화
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const MyApp());
}

Future<Database> _initDB() async {
  String dbPath = await getDatabasesPath();
  String path = join(dbPath, 'pins.db');
  print('DB 파일 경로: $path'); // 디버그 출력

  return await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      print('DB 테이블 생성 완료');
      await db.execute('''
        CREATE TABLE pins (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          note TEXT,
          placeName TEXT,
          latitude REAL,
          longitude REAL,
          category TEXT,
          imagePath TEXT
        )
      ''');
    },
  );
}

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  DBHelper._internal();

  factory DBHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<void> insertPin(Map<String, dynamic> pin) async {
    final db = await database;
    int result = await db.insert('pins', pin);
    print('DB에 핀 추가: $pin, 결과: $result');
  }

  Future<List<Map<String, dynamic>>> getPins() async {
    final db = await database;
    return await db.query('pins');
  }

  Future<void> deletePin(int id) async {
    final db = await database;
    await db.delete('pins', where: 'id = ?', whereArgs: [id]);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PinKonkuk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  Position? _currentPosition;
  List<Map<String, dynamic>> _journalEntries = [];
  final DBHelper _dbHelper = DBHelper();
  // 검색어 변수 추가
  String _searchQuery = '';
  // 메인 카테고리 목록
  List<String> _mainCategories = [
    'All', '새내기', '맛집', '스터디', '건축', '예술', '공학', '상경', '인문', '놀거리', '안전'
  ];

  // 각 카테고리에 대한 서브 카테고리 정의
  Map<String, List<String>> _subCategories = {
    'All': ['자유', 'wifi', '학생회관'],
    '새내기': ['학교 투어', '필수 코스', '박물관', '입학정보관', '행정관'],
    '놀거리': ['노래방', '보드게임카페', '파티', '헌팅', '영화관', '운동장', 'PC방'],
    '맛집': ['한식', '양식', '간식', '디저트'],
    '스터디': ['스터디룸', '카페', 'K-CUBE', '강의실', '도서관'],
    '건축': ['전시회', '외관', '조경', '실내', '건축관', '캠퍼스'],
    '예술': ['전시', '공연', '공방', '예술문화관'],
    '공학': ['IT', '기계', '화공', '토목', '환경', '산공', '프로젝트 룸', '공학관'],
    '상경': ['부동산', '법', '투자', '경영관', '상허연구관', '법학관'],
    '인문': ['시', '수필', '사유', '역사', '인문관', '언어교육원', '산학협동관'],
    '안전': ['위험 지역', '클레임 관리']
  };

  String _selectedMainCategory = 'All';
  String _selectedSubCategory = '자유';
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadPinsFromDB();
  }

  @override
  bool get wantKeepAlive => true;

  void _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('위치 서비스가 비활성화되어 있습니다.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('위치 권한이 영구적으로 거부되었습니다.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    print('현재 위치: Lat=${position.latitude}, Lng=${position.longitude}');
    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> _loadPinsFromDB() async {
    List<Map<String, dynamic>> pins = await _dbHelper.getPins();
    print('DB에서 불러온 핀 데이터: $pins');
    setState(() {
      _journalEntries = pins;
    });
  }

  void _addNewPin(Map<String, dynamic> pin) async {
    await _dbHelper.insertPin(pin);
    await _loadPinsFromDB();
  }

  void _deletePin(int index) async {
    int id = _journalEntries[index]['id'];
    await _dbHelper.deletePin(id);
    await _loadPinsFromDB();
  }

  void _navigateToAddEntry(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEntryPage(
          currentPosition: _currentPosition,
          mainCategories: _mainCategories,
          subCategories: _subCategories, // 기존에 정의된 _subCategories 사용
          onSave: _addNewPin,
          parentContext: context,  // parentContext 전달
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PinKonkuk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatistics(),
          Expanded(
            child: _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: _journalEntries.length,
              itemBuilder: (context, index) {
                var entry = _journalEntries[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: entry['imagePath'] != null && entry['imagePath'].isNotEmpty
                        ? Image.file(File(entry['imagePath']), width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.location_pin, size: 50),
                    title: Text(entry['placeName']),
                    subtitle: Text(entry['note'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePin(index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEntry(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatistics() {
    int totalPins = _journalEntries.length;
    int categoryPins = _journalEntries.where((entry) => entry['category'] == _selectedMainCategory).length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard('총 핀 개수', totalPins.toString()),
          _buildStatCard('현재 카테고리', categoryPins.toString()),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext buildContext) {
    showDialog(
      context: buildContext, // 전달받은 BuildContext 사용
      builder: (context) {
        return AlertDialog(
          title: const Text('핀 검색'),
          content: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _journalEntries = _journalEntries
                    .where((entry) => entry['placeName'].contains(_searchQuery))
                    .toList();
              });
            },
            decoration: const InputDecoration(hintText: '장소 이름으로 검색'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(buildContext),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

}


class AddEntryPage extends StatefulWidget {
  final Position? currentPosition;
  final List<String> mainCategories;
  final Map<String, List<String>> subCategories;
  final Function(Map<String, dynamic>) onSave;
  final BuildContext parentContext; // 상위 BuildContext

  const AddEntryPage({
    super.key,
    required this.currentPosition,
    required this.mainCategories,
    required this.subCategories,
    required this.onSave,
    required this.parentContext, // BuildContext 초기화
  });

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _placeNameController = TextEditingController();
  XFile? _image;
  String _selectedMainCategory = 'All';
  String _selectedSubCategory = '자유';

  void _saveEntry() async {
    if (widget.currentPosition == null) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(content: Text('위치 정보를 가져올 수 없습니다.')),
      );
      return;
    }

    if (_titleController.text.isEmpty || _placeNameController.text.isEmpty) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        const SnackBar(content: Text('제목과 장소 이름을 입력하세요.')),
      );
      return;
    }

    var newEntry = {
      'title': _titleController.text,
      'note': _noteController.text,
      'placeName': _placeNameController.text,
      'latitude': widget.currentPosition!.latitude,
      'longitude': widget.currentPosition!.longitude,
      'category': _selectedSubCategory,
      'imagePath': _image?.path ?? '',
    };

    widget.onSave(newEntry);

    if (mounted) {
      Navigator.pop(widget.parentContext); // 상위 BuildContext로 화면 닫기
    }
  }


  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _image = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('핀 추가'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveEntry(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pin_drop),
                const SizedBox(width: 8),
                Text(
                  widget.currentPosition == null
                      ? '위치를 알 수 없습니다'
                      : 'Lat: ${widget.currentPosition!.latitude}, Lng: ${widget.currentPosition!.longitude}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _placeNameController,
              decoration: const InputDecoration(labelText: '장소 이름 입력'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목 입력'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '내용 입력'),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedMainCategory,
              items: widget.mainCategories.map((String mainCategory) {
                return DropdownMenuItem<String>(
                  value: mainCategory,
                  child: Text(mainCategory),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedMainCategory = newValue!;
                  _selectedSubCategory = widget.subCategories[newValue]!.first;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedSubCategory,
              items: widget.subCategories[_selectedMainCategory]!.map((String subCategory) {
                return DropdownMenuItem<String>(
                  value: subCategory,
                  child: Text(subCategory),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedSubCategory = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),
            _image == null
                ? const Text('선택된 이미지가 없습니다.')
                : Image.file(File(_image!.path)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('이미지 선택'),
            ),
          ],
        ),
      ),
    );
  }
}

class ViewEntryPage extends StatelessWidget {
  final Map<String, dynamic> entry;

  const ViewEntryPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry['title']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pin_drop, color: Colors.green),
                const SizedBox(width: 8),
                Text('${entry['placeName']} - ${entry['category']}\nLat: ${entry['latitude']}, Lng: ${entry['longitude']}'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              entry['note'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            entry['imagePath'] == null || entry['imagePath'].isEmpty
                ? const Text('이미지가 없습니다.')
                : Image.file(File(entry['imagePath'])),
          ],
        ),
      ),
    );
  }
}
