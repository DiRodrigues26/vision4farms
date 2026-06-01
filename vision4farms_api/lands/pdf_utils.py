"""Geração de PDFs para análises e colheitas usando ReportLab."""
import io
from datetime import datetime
from xml.sax.saxutils import escape as _xml_escape

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
)


GREEN = colors.HexColor('#2E7D32')
LIGHT_GREEN = colors.HexColor('#E8F5E9')
GREY = colors.HexColor('#9E9E9E')
TEXT_PRIMARY = colors.HexColor('#1B1B1B')


# Subscripts/superscripts Unicode → ASCII (Helvetica Type 1 não os tem)
_UNICODE_REPLACEMENTS = {
    '₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
    '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9',
    '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4',
    '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9',
}


def _safe(s):
    """Devolve string segura: substitui caracteres Unicode sem glifo,
    converte None em '—'."""
    if s is None or s == '':
        return '—'
    text = str(s)
    for src, dst in _UNICODE_REPLACEMENTS.items():
        text = text.replace(src, dst)
    return text


def _para_safe(s):
    """Versão escapada para XML — para uso em Paragraph()."""
    return _xml_escape(_safe(s))


def _styles():
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name='TitleGreen', fontName='Helvetica-Bold', fontSize=18,
        textColor=GREEN, spaceAfter=6,
    ))
    styles.add(ParagraphStyle(
        name='Subtle', fontName='Helvetica', fontSize=10,
        textColor=GREY, spaceAfter=2,
    ))
    styles.add(ParagraphStyle(
        name='Section', fontName='Helvetica-Bold', fontSize=12,
        textColor=TEXT_PRIMARY, spaceBefore=12, spaceAfter=6,
    ))
    return styles


def _kv_table(rows, col_widths=None):
    """rows: list of (label, value) tuples. Returns a Table."""
    data = [[_safe(label), _fmt(value)] for label, value in rows]
    t = Table(data, colWidths=col_widths or [6 * cm, 10 * cm])
    t.setStyle(TableStyle([
        ('FONT', (0, 0), (-1, -1), 'Helvetica', 10),
        ('FONT', (0, 0), (0, -1), 'Helvetica-Bold', 10),
        ('TEXTCOLOR', (0, 0), (0, -1), colors.HexColor('#555555')),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ROWBACKGROUNDS', (0, 0), (-1, -1), [colors.white, LIGHT_GREEN]),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
    ]))
    return t


def _fmt(v):
    return _safe(v)


def _header(styles, title, subtitle):
    return [
        Paragraph('Vision4Farms', styles['Subtle']),
        Paragraph(_para_safe(title), styles['TitleGreen']),
        Paragraph(_para_safe(subtitle), styles['Subtle']),
        Spacer(1, 12),
    ]


def _footer(styles):
    now = datetime.now().strftime('%d/%m/%Y %H:%M')
    return [
        Spacer(1, 18),
        Paragraph(
            f'<font color="#9E9E9E" size="8">Gerado a {now} por Vision4Farms</font>',
            styles['Normal'],
        ),
    ]


def soil_analysis_pdf(analysis, land_name=''):
    """Gera PDF de uma LandsSoilAnalysis. Devolve bytes."""
    styles = _styles()
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm,
        topMargin=2 * cm, bottomMargin=2 * cm,
    )
    story = []
    story += _header(
        styles,
        'Análise de Solo',
        f'Terreno: {land_name or "—"} • Amostra: {analysis.soil_analysis_sample}',
    )

    story.append(Paragraph('Identificação', styles['Section']))
    story.append(_kv_table([
        ('Data', analysis.soil_analysis_date),
        ('Amostra', analysis.soil_analysis_sample),
    ]))

    story.append(Paragraph('Parâmetros físico-químicos', styles['Section']))
    story.append(_kv_table([
        ('pH (H₂O)', analysis.soil_analysis_ph_h20),
        ('pH (CaCl₂)', analysis.soil_analysis_ph_cacl2),
        ('Acidificação', analysis.soil_analysis_acidifier),
        ('Condutividade', analysis.soil_analysis_conductivity),
        ('Matéria orgânica', analysis.soil_analysis_organic_matter),
        ('Azoto total', analysis.soil_analysis_total_nitrogen),
        ('Relação C/N', analysis.soil_analysis_carbon_nitrogen),
    ]))

    story.append(Paragraph('Macronutrientes', styles['Section']))
    story.append(_kv_table([
        ('Fósforo (P)', analysis.soil_analysis_phosphor),
        ('Potássio (K)', analysis.soil_analysis_potassium),
        ('Cálcio (Ca)', analysis.soil_analysis_calcium),
        ('Magnésio (Mg)', analysis.soil_analysis_magnesium),
        ('Enxofre (S)', analysis.soil_analysis_sulfur),
    ]))

    story.append(Paragraph('Micronutrientes e elementos secundários', styles['Section']))
    story.append(_kv_table([
        ('Ferro (Fe)', analysis.soil_analysis_iron),
        ('Manganês (Mn)', analysis.soil_analysis_manganese),
        ('Atividade Mn', analysis.soil_analysis_manganese_activity),
        ('Boro (B)', analysis.soil_analysis_boron),
        ('Cobre (Cu)', analysis.soil_analysis_copper),
        ('Zinco (Zn)', analysis.soil_analysis_zinc),
        ('Molibdénio (Mo)', analysis.soil_analysis_molybdenum),
        ('Sódio (Na)', analysis.soil_analysis_sodium),
        ('Níquel (Ni)', analysis.soil_analysis_nickel),
        ('Cobalto (Co)', analysis.soil_analysis_cobalt),
    ]))

    story += _footer(styles)
    doc.build(story)
    return buf.getvalue()


def foliar_analysis_pdf(analysis, yield_name=''):
    styles = _styles()
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm,
        topMargin=2 * cm, bottomMargin=2 * cm,
    )
    story = []
    story += _header(
        styles,
        'Análise Foliar',
        f'Cultura: {yield_name or "—"} • Amostra: {analysis.yield_analysis_sample}',
    )

    story.append(Paragraph('Identificação', styles['Section']))
    story.append(_kv_table([
        ('Data', analysis.yield_analysis_date),
        ('Amostra', analysis.yield_analysis_sample),
    ]))

    story.append(Paragraph('Macronutrientes', styles['Section']))
    story.append(_kv_table([
        ('Azoto total (N)', analysis.yield_analysis_nitrogen_total),
        ('Fósforo (P)', analysis.yield_analysis_phosphorus),
        ('Potássio (K)', analysis.yield_analysis_potassium),
        ('Cálcio (Ca)', analysis.yield_analysis_calcium),
        ('Magnésio (Mg)', analysis.yield_analysis_magnesium),
        ('Enxofre (S)', analysis.yield_analysis_sulfur),
    ]))

    story.append(Paragraph('Micronutrientes', styles['Section']))
    story.append(_kv_table([
        ('Ferro (Fe)', analysis.yield_analysis_iron),
        ('Manganês (Mn)', analysis.yield_analysis_manganese),
        ('Boro (B)', analysis.yield_analysis_boro),
        ('Cobre (Cu)', analysis.yield_analysis_cobre),
        ('Zinco (Zn)', analysis.yield_analysis_zinc),
        ('Molibdénio (Mo)', analysis.yield_analysis_molybdenum),
        ('Sódio (Na)', analysis.yield_analysis_sodium),
        ('Alumínio (Al)', analysis.yield_analysis_aluminum),
    ]))

    story += _footer(styles)
    doc.build(story)
    return buf.getvalue()


def harvest_pdf(harvest, yield_name=''):
    styles = _styles()
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm,
        topMargin=2 * cm, bottomMargin=2 * cm,
    )
    story = []
    story += _header(
        styles,
        'Registo de Colheita',
        f'Cultura: {yield_name or "—"} • {harvest.harvest_name}',
    )

    story.append(Paragraph('Identificação', styles['Section']))
    story.append(_kv_table([
        ('Data', harvest.harvest_date),
        ('Nome', harvest.harvest_name),
        ('Quantidade', f'{harvest.harvest_harvested} {harvest.unit_measurement}'),
    ]))

    story.append(Paragraph('Mão-de-obra', styles['Section']))
    story.append(_kv_table([
        ('Nº operadores', harvest.harvested_labor_count),
        ('Horas totais', harvest.harvested_labor_hours),
        ('Horas por operador', harvest.harvested_labor_hours_per_operator),
        ('Custo total mão-de-obra', harvest.harvested_labor_total_cost),
        ('Kg por operador', harvest.harvest_kg_per_operator),
    ]))

    story.append(Paragraph('Máquinas', styles['Section']))
    story.append(_kv_table([
        ('Nº máquinas', harvest.harvested_machine_count),
        ('Horas totais', harvest.harvested_machine_hours),
        ('Custo máquinas', harvest.harvested_machine_cost),
    ]))

    story.append(Paragraph('Totais', styles['Section']))
    story.append(_kv_table([
        ('Custo total', harvest.total_harvest_cost),
        ('Custo por kg', harvest.harvest_cost_per_kg),
        ('Kg por hora', harvest.harvest_kg_per_hour),
    ]))

    story += _footer(styles)
    doc.build(story)
    return buf.getvalue()
