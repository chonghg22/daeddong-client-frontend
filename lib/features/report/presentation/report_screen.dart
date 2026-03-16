import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:daeddong/features/report/providers/report_provider.dart';

const _reportTypes = [
  '화장실이 없어졌어요',
  '위치가 잘못됐어요',
  '정보가 잘못됐어요',
  '새로운 화장실이에요',
  '기타',
];

class ReportScreen extends ConsumerStatefulWidget {
  final int seq;
  final String toiletName;

  const ReportScreen({super.key, required this.seq, required this.toiletName});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  String? _selectedType;
  final _contentController = TextEditingController();
  final _contentFocus = FocusNode();

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedType == null) return;
    _contentFocus.unfocus();

    await ref.read(reportProvider.notifier).submitReport(
          toiletSeq: widget.seq,
          toiletName: widget.toiletName,
          reportType: _selectedType!,
          content: _contentController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider);

    // 성공 시 토스트 후 뒤로가기
    ref.listen(reportProvider.select((s) => s.isSuccess), (_, isSuccess) {
      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('제보가 접수됐어요. 감사합니다!'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    });

    // 실패 시 토스트
    ref.listen(reportProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('잠시 후 다시 시도해주세요'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('화장실 정보 제보')),
      body: GestureDetector(
        onTap: () => _contentFocus.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 화장실 이름 ──
              _Section(
                title: '화장실',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.toiletName.isNotEmpty ? widget.toiletName : '화장실',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── 제보 유형 ──
              _Section(
                title: '제보 유형 *',
                child: Column(
                  children: _reportTypes.map((type) {
                    final selected = _selectedType == type;
                    final color = Theme.of(context).colorScheme.primary;
                    return InkWell(
                      onTap: () => setState(() => _selectedType = type),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: selected ? color : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 12),
                            Text(type, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // ── 내용 입력 ──
              _Section(
                title: '내용 (선택)',
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocus,
                  maxLength: 500,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '추가로 전달하고 싶은 내용을 입력해주세요',
                    hintStyle: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── 제출 버튼 ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedType != null && !state.isLoading)
                      ? _submit
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('제출', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
