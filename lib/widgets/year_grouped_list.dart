import 'package:flutter/material.dart';

/// Hiển thị danh sách [items] được nhóm theo năm (dựa vào [dateOf]).
/// - Mỗi nhóm năm mặc định thu gọn.
/// - Chỉ một năm được mở rộng tại một thời điểm — mở năm khác sẽ tự
///   thu gọn năm đang mở (giống accordion).
/// - Các năm được sắp xếp mới nhất lên trước.
class YearGroupedList<T> extends StatefulWidget {
  final List<T> items;
  final DateTime Function(T item) dateOf;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Nội dung hiển thị khi [items] rỗng.
  final Widget emptyPlaceholder;

  /// Tuỳ chọn: hiển thị tổng (vd: tổng tiền) của các mục trong 1 năm,
  /// đặt cạnh tiêu đề năm đó.
  final String Function(List<T> itemsInYear)? summaryBuilder;

  const YearGroupedList({
    super.key,
    required this.items,
    required this.dateOf,
    required this.itemBuilder,
    this.emptyPlaceholder = const Text('Chưa có mục nào.'),
    this.summaryBuilder,
  });

  @override
  State<YearGroupedList<T>> createState() => _YearGroupedListState<T>();
}

class _YearGroupedListState<T> extends State<YearGroupedList<T>> {
  int? _expandedYear;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.emptyPlaceholder;
    }

    final Map<int, List<T>> byYear = {};
    for (final item in widget.items) {
      final year = widget.dateOf(item).year;
      byYear.putIfAbsent(year, () => []).add(item);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: years.map((year) {
        final itemsInYear = byYear[year]!;
        final expanded = _expandedYear == year;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () {
                  setState(() => _expandedYear = expanded ? null : year);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Năm $year',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${itemsInYear.length})',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Spacer(),
                      if (widget.summaryBuilder != null) ...[
                        Text(
                          widget.summaryBuilder!(itemsInYear),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                      ],
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeInOut,
                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Column(
                    children: itemsInYear
                        .map((item) => widget.itemBuilder(context, item))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
