import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

class EscalationTicketScreen extends StatefulWidget {
  final EscalationTicketModel? ticket;
  final VoidCallback? onResolved;

  const EscalationTicketScreen({
    super.key,
    this.ticket,
    this.onResolved,
  });

  @override
  State<EscalationTicketScreen> createState() => _EscalationTicketScreenState();
}

class _EscalationTicketScreenState extends State<EscalationTicketScreen> {
  late TextEditingController _answerController;
  late TextEditingController _internalNoteController;

  bool _isQuestionExpanded = true;
  bool _isWeakMatchesExpanded = false;
  bool _showAiDraft = true;
  bool _isPreviewMode = false;
  bool _publishToKnowledgeBase = true;
  bool _isToastVisible = false;

  final String _initialAiDraft =
      "Provident Fund is calculated as 12% of Basic Salary. In February, 22 worked days were recorded vs 20 worked days in January, impacting computed basic pay and resulting deductions. Please review your overtime credit details.";

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController(
      text:
          "Hello Aarav,\nYour PF deduction increased by ₹400 in February because your gross basic pay included an arrears adjustment for January overtime. PF is statutory 12% on total basic earned. I have verified your payslip against Odoo Rule SEQ #60.",
    );
    _internalNoteController = TextEditingController(
      text: "Verified with payroll batch PR-2026-02; no adjustment needed.",
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    _internalNoteController.dispose();
    super.dispose();
  }

  void _applyAiDraft() {
    setState(() {
      _answerController.text = _initialAiDraft;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'AI Draft applied to official answer editor',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _discardAiDraft() {
    setState(() {
      _showAiDraft = false;
    });
  }

  void _formatMarkdown(String prefix, String suffix) {
    final text = _answerController.text;
    final selection = _answerController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _answerController.text = newText;
      _answerController.selection = TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.end + prefix.length,
      );
    } else {
      final cursor = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(cursor, cursor, '$prefix text $suffix');
      _answerController.text = newText;
      _answerController.selection = TextSelection.collapsed(offset: cursor + prefix.length + 5);
    }
    setState(() {});
  }

  void _sendAnswer() {
    setState(() {
      _isToastVisible = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isToastVisible = false;
        });
        widget.onResolved?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Answer sent to Aarav Mehta • Indexed to KB',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF006443),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });
  }

  void _confirmReject() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject Ticket?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to reject this escalation ticket? Aarav Mehta will be notified via in-app push.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ticket ESC/2026/0001 rejected')),
              );
            },
            child: const Text('Reject Ticket'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketCode = widget.ticket?.ticketNo ?? 'ESC/2026/0001';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header (Level 3 Glass)
                _buildHeader(ticketCode),

                // Main Scrollable Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 1. Context Panel (Collapsible Card)
                      _buildContextPanel(),
                      const SizedBox(height: 14),

                      // 2. AI Draft Answer Block
                      if (_showAiDraft) ...[
                        _buildAiDraftBlock(),
                        const SizedBox(height: 14),
                      ],

                      // 3. Answer Editor (Primary Workspace)
                      _buildAnswerEditor(),
                      const SizedBox(height: 14),

                      // 4. Internal Note Field
                      _buildInternalNoteSection(),
                      const SizedBox(height: 14),

                      // 5. Knowledge Base Flywheel Toggle
                      _buildKnowledgeBaseFlywheelCard(),
                      const SizedBox(height: 14),

                      // 6. Activity Timeline
                      _buildActivityTimeline(),
                    ],
                  ),
                ),
              ],
            ),

            // Toast Notification Overlay
            if (_isToastVisible) _buildToastOverlay(),

            // Sticky Bottom Action Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStickyBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String ticketCode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Material(
                    color: const Color(0xFFF2F3FF),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF131B2E)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESCALATION TICKET',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4E444A),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        ticketCode,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF57344F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBA1A1A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'URGENT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF93000A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // SLA & Assignment Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFFBA1A1A)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Overdue by 1h 20m',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFBA1A1A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Open',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF78350F),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_pin_rounded, size: 15, color: Color(0xFF00696E)),
                        const SizedBox(width: 4),
                        Text(
                          'Nisha Rao',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF131B2E),
                          ),
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

  Widget _buildContextPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isQuestionExpanded = !_isQuestionExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF57344F)),
                    const SizedBox(width: 8),
                    Text(
                      "Employee's Question",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isQuestionExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20,
                  color: const Color(0xFF4E444A),
                ),
              ],
            ),
          ),
          if (_isQuestionExpanded) ...[
            const SizedBox(height: 10),
            // Quoted question
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '“Why is my February PF deduction different from January if my salary didn\'t change?”',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF131B2E),
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Asker profile
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDFF).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFF714B67),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'AM',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aarav Mehta',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                          Text(
                            'Payroll Specialist • Finance',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF4E444A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Manager',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: const Color(0xFF00696E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Sara Khan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF131B2E),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Why this escalated
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.priority_high_rounded, size: 15, color: Color(0xFFBA1A1A)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Why this escalated',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4E444A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E7FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Low conf',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDAD6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Score 0.31',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF93000A),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Weak matches accordion
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isWeakMatchesExpanded = !_isWeakMatchesExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.manage_search_rounded, size: 16, color: Color(0xFF00696E)),
                              const SizedBox(width: 6),
                              Text(
                                'View the 3 weak matches retrieved',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF00696E),
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _isWeakMatchesExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 16,
                            color: const Color(0xFF00696E),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isWeakMatchesExpanded) ...[
                    const Divider(height: 1, color: Color(0xFFDAE2FD)),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          _buildWeakMatchRow('Rule-PF-02 (2023)', 'Sim: 0.34'),
                          const SizedBox(height: 4),
                          _buildWeakMatchRow('Slab-2024 (Statutory Table)', 'Sim: 0.28'),
                          const SizedBox(height: 4),
                          _buildWeakMatchRow('Tax-FAQ (State General)', 'Sim: 0.21'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeakMatchRow(String label, String similarity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF131B2E),
            ),
          ),
          Text(
            similarity,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: const Color(0xFF80747A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDraftBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded, size: 16, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              Text(
                'AI draft — unverified. Edit before sending.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF78350F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '“$_initialAiDraft”',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF4E444A),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00696E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 0,
                ),
                onPressed: _applyAiDraft,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
                label: Text(
                  'Use this draft',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4E444A),
                ),
                onPressed: _discardAiDraft,
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: Text(
                  'Discard',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerEditor() {
    final charCount = _answerController.text.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Your official answer',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const Text(
                    ' *',
                    style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isPreviewMode = !_isPreviewMode;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E7FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPreviewMode ? Icons.edit_note_rounded : Icons.visibility_outlined,
                        size: 15,
                        color: const Color(0xFF131B2E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPreviewMode ? 'Editor' : 'Preview',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Editor / Preview Box
          if (_isPreviewMode)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: MarkdownBody(
                data: _answerController.text,
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, color: const Color(0xFF131B2E)),
                  strong: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFF57344F)),
                  code: GoogleFonts.jetBrainsMono(backgroundColor: const Color(0xFFE2E7FF), fontSize: 11),
                ),
              ),
            )
          else
            TextField(
              controller: _answerController,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, color: const Color(0xFF131B2E)),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFFAF8FF),
                hintText: 'Draft your validated explanation here...',
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF80747A)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEAEDFF)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          const SizedBox(height: 8),

          // Formatting Toolbar & Char Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildFormatButton(Icons.format_bold_rounded, () => _formatMarkdown('**', '**')),
                  _buildFormatButton(Icons.format_list_bulleted_rounded, () => _formatMarkdown('- ', '')),
                  _buildFormatButton(Icons.code_rounded, () => _formatMarkdown('`', '`')),
                  _buildFormatButton(Icons.link_rounded, () => _formatMarkdown('[', '](url)')),
                ],
              ),
              Text(
                '$charCount / 2000 chars',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: const Color(0xFF4E444A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 17, color: const Color(0xFF4E444A)),
      ),
    );
  }

  Widget _buildInternalNoteSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEDFF).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 17, color: Color(0xFF57344F)),
                  const SizedBox(width: 6),
                  Text(
                    'Internal note',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF131B2E),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(HR only)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF4E444A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Confidential',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF93000A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.visibility_off_outlined, size: 14, color: Color(0xFFBA1A1A)),
              const SizedBox(width: 5),
              Text(
                'The employee will never see internal notes.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFBA1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _internalNoteController,
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF131B2E)),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeBaseFlywheelCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF92EFF5).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00696E).withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFF00696E),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Publish to Knowledge Base',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF004F53),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The AI Assistant will answer this question automatically next time. Turn off for single-person private answers.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF4E444A),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _publishToKnowledgeBase,
            activeTrackColor: const Color(0xFF00696E),
            activeThumbColor: Colors.white,
            onChanged: (val) {
              setState(() {
                _publishToKnowledgeBase = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 18, color: Color(0xFF57344F)),
              const SizedBox(width: 6),
              Text(
                'Audit Activity',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF131B2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Event 1
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: Color(0xFFBA1A1A), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created — auto-escalated (low confidence 0.31)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF131B2E),
                      ),
                    ),
                    Text(
                      'Today • 09:15 AM',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF4E444A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Event 2
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: Color(0xFF00696E), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF57344F)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Assigned to Nisha Rao',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF131B2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Today • 09:40 AM',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF4E444A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToastOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF283044),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF6FFBBE), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Answer sent to Aarav Mehta • Indexed to KB 🔄',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                setState(() {
                  _isToastVisible = false;
                });
              },
              child: const Icon(Icons.close, size: 18, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF714B67),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 2,
              ),
              onPressed: _sendAnswer,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(
                'Send Answer to Employee',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Focusing internal notes field...')),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    '+ Add Internal Note',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF00696E),
                    ),
                  ),
                ),
              ),
              const Text(' | ', style: TextStyle(color: Color(0xFFD1C3CA))),
              InkWell(
                onTap: _confirmReject,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'Reject Ticket',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFBA1A1A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
