import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart'; // 사진 업로드를 위한 패키지
import 'dart:async';
import 'dart:io';

void main() {
  runApp(const MyApp());
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

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  Position? _currentPosition;
  List<Map<String, dynamic>> _journalEntries = [];
  List<String> _mainCategories = [
    'All', '새내기', '맛집', '스터디', '건축', '예술', '공학', '상경', '인문', '놀거리', '안전'
  ];
  Map<String, List<String>> _subCategories = {
    'All': ['자유', 'wifi', '학생회관'],
    '새내기': ['학교 투어', '필수 코스', '박물관', '입학정보관', '행정관'],
    '놀거리': ['노래방', '보드게임카페', '파티', '헌팅', '영화관', '운동장', 'PC방'],
    '맛집': ['한가한', '가성비', '간식', '패스트푸드', '디저트', '한식', '중식', '일식', '양식', '학식', '테마'],
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
    _startLocationCheck();

    // 애니메이션 초기화
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
  // 현재 위치를 가져오는 함수
  void _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('위치 서비스가 비활성화되어 있습니다.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('위치 권한이 영구적으로 거부되었습니다.');
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });
  }

  // 1초마다 위치를 체크하는 타이머 시작
  void _startLocationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _getCurrentLocation();
      _checkForMatchingEntries();
    });
  }

  // 현재 위치와 저장된 위치를 비교하여 가까운 장소를 표시하는 함수
  void _checkForMatchingEntries() {
    if (_currentPosition == null) return;

    double thresholdDistance = 0.001; // 약 1m 이내의 거리

    setState(() {
      _journalEntries = _journalEntries.where((entry) {
        if (_selectedMainCategory != 'All' && entry['category'] != _selectedSubCategory) {
          return false;
        }
        double distance = (entry['latitude'] - _currentPosition!.latitude).abs() +
            (entry['longitude'] - _currentPosition!.longitude).abs();
        return distance < thresholdDistance;
      }).toList();
    });
  }
  void _navigateToAddEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEntryPage(
          currentPosition: _currentPosition,
          mainCategories: _mainCategories,
          subCategories: _subCategories,
          onSave: (entry) {
            setState(() {
              _journalEntries.add(entry);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Text('Pin', style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold)),
    Text('Konkuk', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
    ],
    ),
    centerTitle: true,
    ),
    body: Column(
    children: [
    // 메인 카테고리 선택 탭
    SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
    children: _mainCategories.map((mainCategory) {
    return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    child: ChoiceChip(
    label: Text(mainCategory),
    selected: _selectedMainCategory == mainCategory,
    onSelected: (bool selected) {
    setState(() {
    _selectedMainCategory = mainCategory;
    _selectedSubCategory = _subCategories[mainCategory]!.first;
    });
    },
    ),
    );
    }).toList(),
    ),
    ),
    const SizedBox(height: 10),
      // 서브 카테고리 선택 탭
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _subCategories[_selectedMainCategory]!.map((subCategory) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ChoiceChip(
                label: Text(subCategory),
                selected: _selectedSubCategory == subCategory,
                onSelected: (bool selected) {
                  setState(() {
                    _selectedSubCategory = subCategory;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: _currentPosition == null
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
          itemCount: _journalEntries.length,
          itemBuilder: (context, index) {
            var entry = _journalEntries[index];
            return ListTile(
              title: Text(entry['title']),
              subtitle: Text(
                '${entry['placeName']} - ${entry['category']}\nLat: ${entry['latitude']}, Lng: ${entry['longitude']}',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewEntryPage(entry: entry),
                  ),
                );
              },
              trailing: Checkbox(
                value: false,
                onChanged: (bool? value) {
                  setState(() {
                    _journalEntries.removeAt(index);
                  });
                },
              ),
            );
          },
        ),
      ),
    ],
    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddEntry,
        tooltip: 'Add Entry',
        backgroundColor: Colors.pink,
        child: const Icon(Icons.pin_drop),
      ),
    );
  }
}
class AddEntryPage extends StatefulWidget {
  final Position? currentPosition;
  final List<String> mainCategories;
  final Map<String, List<String>> subCategories;
  final Function(Map<String, dynamic>) onSave;

  const AddEntryPage({
    super.key,
    required this.currentPosition,
    required this.mainCategories,
    required this.subCategories,
    required this.onSave,
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

  void _saveEntry() {
    if (widget.currentPosition == null) return;

    var newEntry = {
      'title': _titleController.text,
      'note': _noteController.text,
      'placeName': _placeNameController.text,
      'latitude': widget.currentPosition!.latitude,
      'longitude': widget.currentPosition!.longitude,
      'image': _image,
      'category': _selectedSubCategory,
    };

    widget.onSave(newEntry);
    Navigator.pop(context);
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
            onPressed: _saveEntry,
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
            entry['image'] == null
                ? const Text('이미지가 없습니다.')
                : Image.file(File(entry['image'].path)),
          ],
        ),
      ),
    );
  }
}

