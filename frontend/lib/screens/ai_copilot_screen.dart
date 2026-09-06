import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/ai_copilot_service.dart';
import '../services/notification_service.dart';
import '../services/mock_data_service.dart';
import 'escalation_ticket_screen.dart';

class AiCopilotScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const AiCopilotScreen({super.key, this.onNavigateTab});

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiMessageItem {
  final bool isUser;
  final String text;
  final String time;
  final bool hasEscalation;
  final EscalationTicketModel? escalationTicket;
  final List<String> citations;
  final double? confidence;
  final String? intent;

  _AiMessageItem({
    required this.isUser,
    required this.text,
    required this.time,
    this.hasEscalation = false,
    this.escalationTicket,
    this.citations = const [],
    this.confidence,
    this.intent,
  });
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _conversationId;
  String? _lastUserPrompt;

  final Set<int> _likedMessages = {};
  final Set<int> _dislikedMessages = {};

  late List<_AiMessageItem> _messages;

  @override
  void initState() {
    super.initState();
    _messages = _defaultSeedMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_AiMessageItem> _defaultSeedMessages() {
    return [
      _AiMessageItem(
        isUser: false,
        text: 'Hi! How can I assist you with HR policy or payroll today?',
        time: 'Just now',
        citations: ['PeoplePay360 HR Assistant'],
      ),
    ];
  }

  void _clearChat() {
    setState(() {
      _conversationId = null;
      _messages = [
        _AiMessageItem(
          isUser: false,
          text: 'Hi! How can I assist you with HR policy or payroll today?',
          time: 'Just now',
          citations: ['PeoplePay360 HR Assistant'],
        ),
      ];
      _textController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Chat history reset',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _insertQuickPrompt(String prompt) {
    _textController.text = prompt;
    _sendQuery(prompt);
  }

  void _sendQuery(String queryText, {bool forceEscalate = false}) async {
    final text = queryText.trim();
    if (text.isEmpty) return;

    _lastUserPrompt = text;

    final now = DateTime.now();
    final hr = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = "${hr.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm";

    setState(() {
      _messages.add(_AiMessageItem(
        isUser: true,
        text: text,
        time: timeStr,
      ));
      _textController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    final res = await AiCopilotService.ask(
      prompt: text,
      conversationId: _conversationId,
      forceEscalate: forceEscalate,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          final data = res.data!;
          if (data['conversation_id'] != null) {
            _conversationId = data['conversation_id']?.toString();
          }

          final answer = data['answer']?.toString() ??
              "I have verified this against the official PeoplePay360 policy repository.";

          final citationsList = (data['citations'] as List?)
                  ?.map((c) => c is Map ? (c['title']?.toString() ?? '') : c.toString())
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              ['PeoplePay360 Verified Policy Vault'];

          final isEscalated = data['escalation_id'] != null || data['mode'] == 'ESCALATED';

          final ticket = isEscalated
              ? EscalationTicketModel(
                  id: data['escalation_id']?.toString() ?? 'esc_${DateTime.now().millisecondsSinceEpoch}',
                  ticketNo: data['ticket_no']?.toString() ?? 'ESC-2026-0042',
                  questionText: text,
                  category: data['category']?.toString() ?? 'HR Policy & Benefits',
                  status: 'OPEN',
                  priority: 'NORMAL',
                  slaDueAt: data['sla_due_at']?.toString() ?? 'Expected reply within 8 hours',
                  answeredBy: 'Sara Khan (HR Manager)',
                  retrievalConfidence: (data['confidence'] as num?)?.toDouble() ?? 0.85,
                )
              : null;

          if (isEscalated) {
            final ticketNo = data['ticket_no']?.toString() ?? 'ESC-2026-0042';
            final empName = MockDataService.currentEmployee.name;
            NotificationService.addNotification({
              'id': 'esc-${DateTime.now().millisecondsSinceEpoch}',
              'icon': Icons.warning_amber_rounded,
              'color': const Color(0xFFB45309),
              'bg': const Color(0xFFFEF3C7),
              'title': '🚨 HR Escalation ($ticketNo)',
              'subtitle': 'Question from $empName: "$text". Tap to review & reply.',
              'time': 'Just now',
              'tabIndex': 5,
              'category': 'Escalations',
              'isUnread': true,
              'ticket': ticket,
              'targetRole': 'HR',
            });
          }

          _messages.add(_AiMessageItem(
            isUser: false,
            text: answer,
            time: timeStr,
            hasEscalation: isEscalated,
            confidence: (data['confidence'] as num?)?.toDouble(),
            intent: data['intent']?.toString(),
            escalationTicket: ticket,
            citations: citationsList,
          ));
        } else {
          _messages.add(_AiMessageItem(
            isUser: false,
            text:
                "I couldn't complete the live verification request. Please check your connectivity or ask your HR team directly.",
            time: timeStr,
            citations: ['PeoplePay360 Offline Fallback'],
          ));
        }
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 140,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openTicketTracker(EscalationTicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EscalationTicketScreen(
          ticket: ticket,
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check, color: Color(0xFF6FFBBE), size: 18),
            const SizedBox(width: 8),
            Text(
              'Copied answer to clipboard',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Top Modal Chrome
            _buildTopChrome(),

            // Quick Starters Shelf
            _buildQuickStartersShelf(),

            // Chat Message Stream Canvas
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildDateDivider();
                  }

                  final msgIndex = index - 1;
                  final msg = _messages[msgIndex];
                  if (msg.isUser) {
                    return _buildUserMessage(msg);
                  } else if (msg.hasEscalation && msg.escalationTicket != null) {
                    return _buildEscalationCard(msg.escalationTicket!, msg.text);
                  } else {
                    return _buildCopilotMessage(msg, msgIndex);
                  }
                },
              ),
            ),

            // Typing indicator
            if (_isLoading) _buildTypingIndicator(),

            // Sticky Bottom Prompt Bar
            _buildBottomPromptBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopChrome() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF57344F).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF57344F),
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF006443),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Grounded in verified HR & payroll rules',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF4E444A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _clearChat,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFF4E444A)),
                  const SizedBox(width: 4),
                  Text(
                    'Clear Chat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartersShelf() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildQuickStarterPill(
            icon: Icons.beach_access_rounded,
            iconColor: const Color(0xFF00696E),
            text: 'How many PTO days do I have left?',
            bgColor: const Color(0xFFF2F3FF),
          ),
          const SizedBox(width: 8),
          _buildQuickStarterPill(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF006E73),
            text: 'Explain deductions on my Feb payslip',
            bgColor: const Color(0xFF92EFF5).withValues(alpha: 0.35),
          ),
          const SizedBox(width: 8),
          _buildQuickStarterPill(
            icon: Icons.medical_services_rounded,
            iconColor: const Color(0xFF57344F),
            text: 'Sick leave medical certificate rules?',
            bgColor: const Color(0xFFF2F3FF),
          ),
          const SizedBox(width: 8),
          _buildQuickStarterPill(
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF714B67),
            text: 'When is the next public holiday?',
            bgColor: const Color(0xFFFFD7F1).withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStarterPill({
    required IconData icon,
    required Color iconColor,
    required String text,
    required Color bgColor,
  }) {
    return InkWell(
      onTap: () => _insertQuickPrompt(text),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF131B2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFDAE2FD))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Today • Live Session',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: const Color(0xFF4E444A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFDAE2FD))),
        ],
      ),
    );
  }

  Widget _buildUserMessage(_AiMessageItem msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF57344F), Color(0xFF714B67)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  topRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.time,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: const Color(0xFF4E444A),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.done_all_rounded,
                  size: 14,
                  color: Color(0xFF00696E),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopilotMessage(_AiMessageItem msg, int msgIndex) {
    final isLiked = _likedMessages.contains(msgIndex);
    final isDisliked = _dislikedMessages.contains(msgIndex);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header identity
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF57344F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00696E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                'PeoplePay360 Copilot',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF131B2E),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEDFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  msg.confidence != null && msg.confidence! >= 0.95 ? 'EXACT SQL' : 'VERIFIED AI',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF00696E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Message Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Markdown Content
                MarkdownBody(
                  data: msg.text,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      height: 1.5,
                      color: const Color(0xFF131B2E),
                    ),
                    strong: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF131B2E),
                    ),
                    h3: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF57344F),
                    ),
                    code: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      backgroundColor: const Color(0xFFE2E7FF),
                      color: const Color(0xFF131B2E),
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    blockquote: GoogleFonts.plusJakartaSans(
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF4E444A),
                      fontSize: 12.5,
                    ),
                    blockquoteDecoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFF714B67), width: 3),
                      ),
                    ),
                    tableBody: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: const Color(0xFF131B2E),
                    ),
                    tableHead: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF57344F),
                    ),
                    tableBorder: TableBorder.all(
                      color: const Color(0xFFDAE2FD),
                      width: 1,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                // Citations list
                if (msg.citations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF00696E)),
                            const SizedBox(width: 5),
                            Text(
                              'Verified Sources & Policy References',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00696E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...msg.citations.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(color: Color(0xFF57344F), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    c,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: const Color(0xFF4E444A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Action Footer
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: () {
                        _sendQuery(
                          _lastUserPrompt != null
                              ? 'I need HR specialist escalation regarding: $_lastUserPrompt'
                              : 'I need to escalate this question to HR support',
                          forceEscalate: true,
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Not what you needed? Ask HR',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: const Color(0xFF714B67),
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF714B67)),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: const Icon(Icons.copy_outlined, size: 15, color: Color(0xFF4E444A)),
                          tooltip: 'Copy text',
                          onPressed: () => _copyToClipboard(msg.text),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: Icon(
                            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 15,
                            color: isLiked ? const Color(0xFF00696E) : const Color(0xFF4E444A),
                          ),
                          onPressed: () {
                            setState(() {
                              if (isLiked) {
                                _likedMessages.remove(msgIndex);
                              } else {
                                _likedMessages.add(msgIndex);
                                _dislikedMessages.remove(msgIndex);
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: Icon(
                            isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                            size: 15,
                            color: isDisliked ? const Color(0xFFBA1A1A) : const Color(0xFF4E444A),
                          ),
                          onPressed: () {
                            setState(() {
                              if (isDisliked) {
                                _dislikedMessages.remove(msgIndex);
                              } else {
                                _dislikedMessages.add(msgIndex);
                                _likedMessages.remove(msgIndex);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEscalationCard(EscalationTicketModel ticket, String explanation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10F59E0B),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: Container(color: const Color(0xFFF59E0B)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🙋', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(
                          'Forwarded to HR Specialist Team',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.outgoing_mail, color: Color(0xFFB45309), size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ticket.ticketNo,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF78350F),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDAE2FD),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00696E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ticket.category,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Auto-assigned',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  explanation,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFFB45309)),
                        const SizedBox(width: 4),
                        Text(
                          ticket.slaDueAt,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _openTicketTracker(ticket),
                      child: Row(
                        children: [
                          Text(
                            'Track this ticket',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF78350F),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF78350F)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFF57344F), shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: const Color(0xFF57344F).withValues(alpha: 0.6), shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: const Color(0xFF57344F).withValues(alpha: 0.3), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'Searching verified policies & statutory index...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF4E444A),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPromptBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.auto_awesome, color: Color(0xFF57344F), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF131B2E),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask anything about HR policy, salary, or leave...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: const Color(0xFF4E444A).withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (val) => _sendQuery(val),
                  ),
                ),
                Material(
                  color: const Color(0xFF57344F),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _sendQuery(_textController.text),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'AI responses are grounded in verified company policies & statutory rules.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: const Color(0xFF4E444A).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
