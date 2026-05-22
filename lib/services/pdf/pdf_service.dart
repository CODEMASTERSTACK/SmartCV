import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/resume_generator/domain/entities/resume_model.dart';

class PdfService {
  Future<Uint8List> generatePdf(
    ResumeData data,
    ResumeTemplate template,
  ) async {
    switch (template) {
      case ResumeTemplate.atsProfessional:
        return _buildAtsPdf(data);
      case ResumeTemplate.modernMinimal:
        return _buildModernPdf(data);
      case ResumeTemplate.compactClean:
        return _buildCompactPdf(data);
    }
  }

  // ── ATS Professional Template ─────────────────────────────

  Future<Uint8List> _buildAtsPdf(ResumeData data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
            horizontal: 40, vertical: 36),
        build: (context) => [
          // Header
          _atsHeader(data),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // Summary
          if (data.summary.isNotEmpty) ...[
            _atsSection('PROFESSIONAL SUMMARY'),
            pw.SizedBox(height: 6),
            pw.Text(data.summary,
                style: pw.TextStyle(
                    fontSize: 10, lineSpacing: 1.4)),
            pw.SizedBox(height: 14),
          ],

          // Projects
          if (data.projects.isNotEmpty) ...[
            _atsSection('PROJECTS'),
            pw.SizedBox(height: 6),
            ...data.projects.map((p) => _atsProject(p)),
          ],

          // Education
          if (data.education.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('EDUCATION'),
            pw.SizedBox(height: 6),
            ...data.education.map((e) => _atsEducation(e)),
          ],

          // Skills
          if (data.skillGroups.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('SKILLS'),
            pw.SizedBox(height: 6),
            ...data.skillGroups.map(
              (g) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: '${g.category}: ',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.TextSpan(
                        text: g.skills.join(', '),
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Certifications
          if (data.certifications.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('CERTIFICATIONS'),
            pw.SizedBox(height: 6),
            ...data.certifications.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${c.title} — ${c.issuer}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(c.date,
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                )),
          ],

          // Achievements
          if (data.achievements.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _atsSection('ACHIEVEMENTS'),
            pw.SizedBox(height: 6),
            ...data.achievements.map(
              (a) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Expanded(
                      child: pw.Text(a,
                          style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _atsHeader(ResumeData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          data.name,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          [data.email, data.phone, data.location]
              .where((s) => s.isNotEmpty)
              .join(' | '),
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (data.githubUrl.isNotEmpty || data.linkedinUrl.isNotEmpty)
          pw.Text(
            [data.githubUrl, data.linkedinUrl]
                .where((s) => s.isNotEmpty)
                .join(' | '),
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.blue700,
            ),
          ),
      ],
    );
  }

  pw.Widget _atsSection(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Divider(color: PdfColors.grey500, thickness: 0.5),
      ],
    );
  }

  pw.Widget _atsProject(ResumeProject project) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                project.title,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (project.technologies.isNotEmpty)
                pw.Text(
                  project.technologies.take(4).join(', '),
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 3),
          ...project.bullets.map(
            (b) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Text(b,
                        style: const pw.TextStyle(
                            fontSize: 10, lineSpacing: 1.3)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _atsEducation(ResumeEducation edu) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                edu.institution,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${edu.degree} ${edu.field}${edu.cgpa.isNotEmpty ? " — ${edu.cgpa}" : ""}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Text(edu.duration,
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ── Modern Minimal Template ───────────────────────────────

  Future<Uint8List> _buildModernPdf(ResumeData data) async {
    final pdf = pw.Document();
    final accentColor = PdfColor.fromHex('#6366F1');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Sidebar
              pw.Container(
                width: 160,
                constraints: const pw.BoxConstraints(minHeight: 842),
                color: PdfColor.fromHex('#111111'),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      data.name,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text('CONTACT',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColor.fromHex('#888888'),
                          letterSpacing: 1.5,
                        )),
                    pw.SizedBox(height: 6),
                    if (data.email.isNotEmpty)
                      _sidebarItem(data.email),
                    if (data.phone.isNotEmpty)
                      _sidebarItem(data.phone),
                    if (data.location.isNotEmpty)
                      _sidebarItem(data.location),
                    pw.SizedBox(height: 16),
                    if (data.skillGroups.isNotEmpty) ...[
                      pw.Text('SKILLS',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColor.fromHex('#888888'),
                            letterSpacing: 1.5,
                          )),
                      pw.SizedBox(height: 8),
                      ...data.skillGroups
                          .expand((g) => g.skills)
                          .take(15)
                          .map(
                            (s) => pw.Padding(
                              padding:
                                  const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: accentColor.shade(0.8),
                                  borderRadius: pw.BorderRadius.circular(3),
                                ),
                                child: pw.Text(
                                  s,
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              // Main content
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (data.summary.isNotEmpty) ...[
                        _modernSection('SUMMARY', accentColor),
                        pw.SizedBox(height: 8),
                        pw.Text(data.summary,
                            style: const pw.TextStyle(
                                fontSize: 10, lineSpacing: 1.4)),
                        pw.SizedBox(height: 16),
                      ],
                      if (data.projects.isNotEmpty) ...[
                        _modernSection('PROJECTS', accentColor),
                        pw.SizedBox(height: 8),
                        ...data.projects.map((p) => _atsProject(p)),
                      ],
                      if (data.education.isNotEmpty) ...[
                        _modernSection('EDUCATION', accentColor),
                        pw.SizedBox(height: 8),
                        ...data.education.map((e) => _atsEducation(e)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _sidebarItem(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
            fontSize: 8, color: PdfColors.grey300),
        maxLines: 2,
      ),
    );
  }

  pw.Widget _modernSection(String title, PdfColor accent) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: accent,
            letterSpacing: 1.5,
          ),
        ),
        pw.Container(
          height: 2,
          color: accent,
          margin: const pw.EdgeInsets.only(top: 3, bottom: 0),
        ),
      ],
    );
  }

  // ── Compact Clean Template ────────────────────────────────

  Future<Uint8List> _buildCompactPdf(ResumeData data) async {
    // Same structure as ATS but smaller fonts + tighter spacing
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
            horizontal: 36, vertical: 28),
        build: (context) => [
          _atsHeader(data),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 6),
          if (data.summary.isNotEmpty) ...[
            pw.Text(data.summary,
                style: const pw.TextStyle(
                    fontSize: 9, lineSpacing: 1.3)),
            pw.SizedBox(height: 10),
          ],
          if (data.projects.isNotEmpty) ...[
            _compactSection('PROJECTS'),
            ...data.projects.map(
              (p) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${p.title} | ${p.technologies.take(3).join(", ")}',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    ...p.bullets.map(
                      (b) => pw.Text(
                        '• $b',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (data.education.isNotEmpty) ...[
            _compactSection('EDUCATION'),
            ...data.education.map((e) => pw.Text(
                  '${e.institution} — ${e.degree} ${e.field} | ${e.duration}',
                  style: const pw.TextStyle(fontSize: 9),
                )),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _compactSection(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
