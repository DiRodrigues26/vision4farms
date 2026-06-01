from django.db import models
from farms.models import Farms
from lands.models import Lands


class Agenda(models.Model):
    TYPE_CHOICES = [
        ('task', 'Tarefa'),
        ('visit', 'Visita'),
        ('meeting', 'Reunião'),
        ('reminder', 'Lembrete'),
        ('other', 'Outro'),
    ]
    STATUS_CHOICES = [
        (0, 'Pendente'),
        (1, 'Concluído'),
        (2, 'Cancelado'),
    ]
    RECURRENCE_CHOICES = [
        ('none', 'Sem recorrência'),
        ('daily', 'Diária'),
        ('weekly', 'Semanal'),
        ('monthly', 'Mensal'),
        ('yearly', 'Anual'),
    ]

    agenda_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING)
    land = models.ForeignKey(Lands, models.DO_NOTHING, blank=True, null=True)
    yield_id = models.IntegerField(blank=True, null=True)
    activity_id = models.IntegerField(blank=True, null=True)
    user_id = models.IntegerField()
    agenda_title = models.CharField(max_length=150)
    agenda_description = models.TextField(blank=True, null=True)
    agenda_type = models.CharField(max_length=50, choices=TYPE_CHOICES, default='task')
    agenda_date = models.DateField()
    agenda_time_start = models.TimeField(blank=True, null=True)
    agenda_time_end = models.TimeField(blank=True, null=True)
    agenda_allday = models.BooleanField(default=True)
    recurrence = models.CharField(max_length=20, choices=RECURRENCE_CHOICES, default='none')
    recurrence_end = models.DateField(blank=True, null=True)
    agenda_status = models.IntegerField(default=0, choices=STATUS_CHOICES)
    agenda_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'agenda'
