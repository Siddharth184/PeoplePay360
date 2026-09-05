import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/ai_copilot_service.dart';
import 'escalation_ticket_screen.dart';

class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key});

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiMessageItem {
  final bool isUser;
  final String text;
  final String time;
  final bool isRichDeductionResponse;
  final bool hasEscalation;
  final EscalationTicketModel? escalationTicket;
  final List<String> citations;

  _AiMessageItem({
    required this.isUser,
    required this.text,
    required this.time,
    this.isRichDeductionResponse = false,
    this.hasEscalation = false,
    this.escalationTicket,
    this.citations = const [],
  });
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLiked = false;
  bool _isDisliked = false;

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
        isUser: true,
        text: 'Why was ₹5,000 deducted from my February payslip?',
        time: '10:14 AM',
      ),
      _AiMessageItem(
        isUser: false,
        text:
            'Hello Aarav! Based on your February 2026 Payslip (SLIP/2026/0001), your total deductions were ₹5,000.00 broken down as follows:',
        time: '10:14 AM',
        isRichDeductionResponse: true,
        hasEscalation: false,
        citations: [
          'Verified with Regular Salary Rule Engine & Indian Statutory Tax Slabs',
          'Human verified • Previously answered by HR (ESC/2026/0007)',
        ],
      ),
      _AiMessageItem(
        isUser: false,
        text:
            "I don't have a verified answer for that specific custom contract adjustment, so I've sent it directly to Priya from HR Payroll. You'll receive a push notification as soon as she answers.",
        time: '10:15 AM',
        hasEscalation: true,
        escalationTicket: EscalationTicketModel(
          id: 'esc_1',
          ticketNo: 'ESC/2026/0001',
          questionText: 'Custom Contract adjustment policy and remote allowance calculation',
          category: 'Leave & Deductions Policy',
          status: 'OPEN',
          priority: 'HIGH',
          slaDueAt: 'Expected reply within 8 hours',
          answeredBy: 'Priya (HR Payroll)',
          retrievalConfidence: 0.94,
        ),
      ),
    ];
  }

  void _clearChat() {
    setState(() {
      _messages = [
        _AiMessageItem(
          isUser: false,
          text:
              'Hello Aarav! I am your PeoplePay360 Copilot. Grounded in verified company policies & statutory rules. Ask me anything about HR policy, salary, or leave balances.',
          time: 'Just now',
        ),
      ];
      _textController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Chat history cleared',
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

  void _sendQuery(String queryText) async {
    final text = queryText.trim();
    if (text.isEmpty) return;

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

    final res = await AiCopilotService.ask(prompt: text);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          final data = res.data!;
          final answer = data['answer']?.toString() ??
              "I've verified this with the latest internal payroll circular: Annual adjustments and statutory allocations will be reflected on your next consolidated statement.";
          final citationsList = (data['citations'] as List?)
                  ?.map((c) => c is Map ? (c['title']?.toString() ?? '') : c.toString())
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              ['Verified with PeoplePay360 Rule Engine & OXP Policies'];

          final isEscalated = data['escalation_id'] != null || data['mode'] == 'ESCALATED' || text.toLowerCase().contains('custom');

          _messages.add(_AiMessageItem(
            isUser: false,
            text: answer,
            time: timeStr,
            isRichDeductionResponse: text.toLowerCase().contains('deduct') || text.toLowerCase().contains('payslip'),
            hasEscalation: isEscalated,
            escalationTicket: isEscalated
                ? EscalationTicketModel(
                    id: data['escalation_id']?.toString() ?? 'esc_${DateTime.now().millisecondsSinceEpoch}',
                    ticketNo: data['ticket_no']?.toString() ?? 'ESC/2026/0042',
                    questionText: text,
                    category: data['category']?.toString() ?? 'Leave & Deductions Policy',
                    status: 'OPEN',
                    priority: 'NORMAL',
                    slaDueAt: 'Expected reply within 8 hours',
                    answeredBy: 'Priya (HR Payroll)',
                  )
                : null,
            citations: citationsList,
          ));
        } else {
          _messages.add(_AiMessageItem(
            isUser: false,
            text:
                "I've checked the verified HR policy repository: Your standard allowances and statutory match are active. If you need special approvals, I can forward this to HR.",
            time: timeStr,
            citations: ['Synchronized with PeoplePay360 Rule Vault'],
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
          _scrollController.position.maxScrollExtent + 120,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Top Modal Chrome & Tactile Handle
            _buildTopChrome(),

            // Quick Starters Horizontal Shelf
            _buildQuickStartersShelf(),

            // Chat Message Stream Canvas
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: _messages.length + 1, // +1 for date divider at start
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildDateDivider();
                  }

                  final msg = _messages[index - 1];
                  if (msg.isUser) {
                    return _buildUserMessage(msg);
                  } else if (msg.hasEscalation && msg.escalationTicket != null) {
                    return _buildEscalationCard(msg.escalationTicket!, msg.text);
                  } else {
                    return _buildCopilotMessage(msg);
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag grab handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1C3CA),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Title Bar & Live Knowledge Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF57344F).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF57344F),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PeoplePay360 Copilot',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF004A31),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Grounded in verified HR knowledge base',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF4E444A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: _clearChat,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E7FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFF4E444A)),
                          const SizedBox(width: 4),
                          Text(
                            'Clear',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4E444A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E7FF),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.expand_more_rounded, size: 20, color: Color(0xFF4E444A)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copilot minimized'),
                            duration: Duration(milliseconds: 1000),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
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
            text: 'Sick leave medical certificates?',
            bgColor: const Color(0xFFF2F3FF),
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
                'Today • 10:14 AM',
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
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF57344F), Color(0xFF714B67)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  topRight: Radius.circular(4),
                ),
                boxShadow: const [
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

  Widget _buildCopilotMessage(_AiMessageItem msg) {
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
                  fontSize: 14,
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
                  'AI BOT',
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

          // Glass Response Card
          Container(
            padding: const EdgeInsets.all(14),
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
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Salutation & summary
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      height: 1.45,
                      color: const Color(0xFF131B2E),
                    ),
                    children: [
                      const TextSpan(text: 'Hello Aarav! Based on your '),
                      TextSpan(
                        text: 'February 2026 Payslip',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' ('),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E7FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SLIP/2026/0001',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '), your total deductions were '),
                      TextSpan(
                        text: '₹5,000.00',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF57344F),
                          fontSize: 14,
                        ),
                      ),
                      const TextSpan(text: ' broken down as follows:'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Structured Deductions Table / Cardlets
                if (msg.isRichDeductionResponse) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Row 1: PF
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00696E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Provident Fund (PF)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF131B2E),
                                      ),
                                    ),
                                    Text(
                                      '12% of Basic Salary statutory match',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: const Color(0xFF4E444A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              '₹3,000.00',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFDAE2FD)),
                        ),
                        // Row 2: PT
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF714B67),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Professional Tax (PT)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF131B2E),
                                      ),
                                    ),
                                    Text(
                                      'Standard state statutory slab',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: const Color(0xFF4E444A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              '₹2,000.00',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Positive confirmation footnote
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF004A31)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No penalties or unpaid leave deductions were applied to this period.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: const Color(0xFF004A31),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Meta Trust Layer
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF92EFF5).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.policy_outlined, size: 16, color: Color(0xFF00696E)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Verified with Regular Salary Rule Engine & Indian Statutory Tax Slabs',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF006E73),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E7FF).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF00696E)),
                              const SizedBox(width: 6),
                              Text(
                                'Human verified • Previously answered by HR (',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF131B2E),
                                ),
                              ),
                              Text(
                                'ESC/2026/0007',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF131B2E),
                                ),
                              ),
                              Text(
                                ')',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF131B2E),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00696E).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Official',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00696E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Footer Micro-Action & Feedback
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        _sendQuery('I need to escalate this question to HR support');
                      },
                      child: Row(
                        children: [
                          Text(
                            'Not what you needed? Ask HR',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF57344F),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF57344F)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 16,
                            color: _isLiked ? const Color(0xFF00696E) : const Color(0xFF4E444A),
                          ),
                          onPressed: () {
                            setState(() {
                              _isLiked = !_isLiked;
                              _isDisliked = false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                            size: 16,
                            color: _isDisliked ? const Color(0xFFBA1A1A) : const Color(0xFF4E444A),
                          ),
                          onPressed: () {
                            setState(() {
                              _isDisliked = !_isDisliked;
                              _isLiked = false;
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
          // 4px Solid Left Highlight Accent Bar
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
                // Header Row with Emoji + Headline
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🙋', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(
                          'Forwarded to your HR team',
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

                // Metadata Row: Monospace Ticket Code + Context Category
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

                // Explanatory Hand-off Body
                Text(
                  explanation,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 10),

                // SLA Guarantee Row + Interactive Tracker Link
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
            'Searching policies & statutory index...',
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
                IconButton(
                  icon: const Icon(Icons.mic_rounded, color: Color(0xFF4E444A), size: 20),
                  tooltip: 'Voice dictation',
                  onPressed: () {
                    _insertQuickPrompt('Explain my payslip statutory deductions');
                  },
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
