import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/models.dart';
import '../services/ai_copilot_service.dart';
import '../theme/app_theme.dart';

class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key});

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'text': 'Hello Aarav! I am your PeoplePay360 AI HR Assistant. Ask me about your leave balances, payslip deductions, or company HR policies.',
      'citations': [],
      'confidence': 1.0,
      'escalation': null,
    },
  ];

  final _textController = TextEditingController();
  bool _isLoading = false;

  void _sendQuery(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'citations': [],
        'confidence': 1.0,
        'escalation': null,
      });
      _textController.clear();
      _isLoading = true;
    });

    final res = await AiCopilotService.ask(prompt: text);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          final data = res.data!;
          final answer = data['answer']?.toString() ?? 'No response received.';
          final confidence = (data['confidence'] as num?)?.toDouble() ?? 1.0;
          final citationsList = (data['citations'] as List?)
                  ?.map((c) => c is Map ? (c['title']?.toString() ?? '') : c.toString())
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              [];

          EscalationTicketModel? ticket;
          if (data['escalation_id'] != null || data['mode'] == 'ESCALATED') {
            ticket = EscalationTicketModel(
              id: data['escalation_id']?.toString() ?? 'esc_auto',
              ticketNo: data['ticket_no']?.toString() ?? 'ESC-2026-0099',
              questionText: text,
              category: data['category']?.toString() ?? 'HR_POLICY',
              status: 'OPEN',
              priority: 'NORMAL',
              slaDueAt: data['sla_due_at']?.toString() ?? 'In 8 hours',
              retrievalConfidence: confidence,
            );
          }

          _messages.add({
            'isUser': false,
            'text': answer,
            'citations': citationsList,
            'confidence': confidence,
            'escalation': ticket,
          });
        } else {
          _messages.add({
            'isUser': false,
            'text': 'Unable to connect to AI engine. ${res.errorMessage ?? ""}',
            'citations': [],
            'confidence': 0.0,
            'escalation': null,
          });
        }
      });
    }
  }

  void _openEscalationInboxModal(EscalationTicketModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HR Escalation Inbox', style: Theme.of(context).textTheme.headlineMedium),
                      Text('Ticket #${ticket.ticketNo} • ${ticket.category}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.odooTeal)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.amberWarning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppTheme.amberWarning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SLA Due: ${ticket.slaDueAt}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Assigned to: ${ticket.answeredBy ?? "Unassigned"}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Original Employee Question:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.surfaceDark : AppTheme.surfaceElevatedLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(ticket.questionText, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 16),
              Text('HR Manager Answer & Knowledge Base Flywheel:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Expanded(
                child: TextField(
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Type official verified answer to employee...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(value: true, onChanged: (_) {}),
                  const Text('Publish answer to Knowledge Base (Self-Learning RAG)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldSuccess, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Ticket ${ticket.ticketNo} Answered & Indexed into Vector DB!')),
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Submit Answer & Notify Employee'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Copilot Header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.odooAubergine,
              child: Row(
                children: const [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.smart_toy, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PeoplePay 360 AI Copilot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Hybrid RAG + Tier 0 SQL Engine • Zero RAM Models', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            // Quick Prompt Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _buildQuickChip('What is my leave balance?'),
                  _buildQuickChip('Explain my payslip deductions'),
                  _buildQuickChip('Can I carry forward PTO to Q1?'),
                ],
              ),
            ),
            const Divider(height: 1),
            // Messages List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['isUser'] as bool;
                  final citations = msg['citations'] as List;
                  final escalation = msg['escalation'] as EscalationTicketModel?;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppTheme.odooAubergine
                            : (isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUser ? Colors.transparent : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            data: msg['text'],
                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                              p: TextStyle(color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87)),
                            ),
                          ),
                          if (citations.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: AppTheme.odooTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  const Icon(Icons.source, size: 14, color: AppTheme.odooTeal),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Citation: ${citations.first}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.odooTeal),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (escalation != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.amberWarning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.amberWarning),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Ticket: ${escalation.ticketNo}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.amberWarning)),
                                      const Text('SLA: 24h', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Routed to: ${escalation.answeredBy}', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 34,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.amberWarning, foregroundColor: Colors.black),
                                      onPressed: () => _openEscalationInboxModal(escalation),
                                      child: const Text('View Ticket in HR Inbox', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.odooAubergine),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Copilot is evaluating HR policies...',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            // Text Input Field
            Container(
              padding: const EdgeInsets.all(12),
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Ask HR Copilot...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: _sendQuery,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppTheme.odooAubergine),
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendQuery(_textController.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () => _sendQuery(label),
      ),
    );
  }
}
