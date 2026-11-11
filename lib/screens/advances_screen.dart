import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../database/database.dart';
import '../repositories/advance_repository.dart';
import '../widgets/swipe_to_delete.dart';
import 'add_advance_batch_screen.dart';
import 'advance_batch_detail_screen.dart';

class AdvancesScreen extends StatefulWidget {
  const AdvancesScreen({super.key});

  @override
  State<AdvancesScreen> createState() => _AdvancesScreenState();
}

class _AdvancesScreenState extends State<AdvancesScreen> {
  late final AdvanceRepository _repo;
  final _currencyFormat = NumberFormat.decimalPattern('vi_VN');

  @override
  void initState() {
    super.initState();
    _repo = AdvanceRepository(database);
    // Tự động gộp các đợt ứng trước bị trùng tên đã lỡ tạo từ trước (nếu
    // có) — an toàn, không ảnh hưởng gì nếu không có gì trùng.
    _repo.mergeDuplicates();
  }

  String _formatMoney(double amount) => '${_currencyFormat.format(amount)} ₫';

  Future<void> _deleteBatch(AdvanceBatch batch) async {
    await _repo.deleteBatch(batch.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ứng trước')),
      body: StreamBuilder<List<AdvanceBatch>>(
        stream: _repo.watchAllBatches(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final batches = snapshot.data!;
          if (batches.isEmpty) {
            return const Center(
              child: Text('Chưa có đợt ứng trước nào.\nBấm + để thêm mới.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              return FutureBuilder<double>(
                future: _repo.getRemainingToReceive(batch.id),
                builder: (context, remainingSnapshot) {
                  final remaining = remainingSnapshot.data ?? 0;
                  return SwipeToDelete(
                    itemKey: batch.id,
                    confirmMessage: 'Xóa đợt ứng trước "${batch.purpose}"?',
                    onDelete: () => _deleteBatch(batch),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade700.withOpacity(0.15),
                          child: Icon(Icons.receipt_long, color: Colors.orange.shade700),
                        ),
                        title: Text(batch.purpose),
                        subtitle: Text(
                          '${batch.createdAt.day}/${batch.createdAt.month}/${batch.createdAt.year}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatMoney(remaining),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: batch.isSettled ? Colors.grey : Colors.orange.shade700,
                              ),
                            ),
                            if (batch.isSettled)
                              const Text('Đã tất toán',
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdvanceBatchDetailScreen(batch: batch),
                            ),
                          );
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAdvanceBatchScreen()),
          );
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
