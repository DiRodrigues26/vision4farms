from django.db import models
from farms.models import Farms
from lands.models import Lands


class Observations(models.Model):
    observation_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING)
    land = models.ForeignKey(Lands, models.DO_NOTHING)
    yield_id = models.IntegerField(blank=True, null=True)
    observation_text = models.TextField()
    observation_photo = models.TextField(blank=True, null=True)
    observation_gps = models.CharField(max_length=45, blank=True, null=True)
    estado_fenologico = models.CharField(max_length=100, blank=True, null=True)
    numero_armadilha = models.CharField(max_length=50, blank=True, null=True)
    qt_detetada = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    praga_fungo = models.CharField(max_length=20, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'observations'


class Activities(models.Model):
    ACTIVITY_TYPE_CHOICES = [
        ('treatment', 'Tratamento'),
        ('fertilization', 'Fertilização'),
        ('pruning', 'Poda'),
        ('irrigation', 'Rega'),
        ('harvest', 'Colheita'),
        ('inspection', 'Inspeção'),
        ('other', 'Outro'),
    ]
    STATUS_CHOICES = [(0, 'Pendente'), (1, 'Concluída'), (2, 'Atrasada'), (3, 'Cancelada')]
    PRIORITY_CHOICES = [(1, 'Normal'), (2, 'Alta'), (3, 'Urgente')]

    activity_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING)
    land = models.ForeignKey(Lands, models.DO_NOTHING)
    yield_id = models.IntegerField(blank=True, null=True)
    user_id = models.IntegerField()
    observation = models.ForeignKey(
        Observations, models.DO_NOTHING, blank=True, null=True
    )
    activity_name = models.CharField(max_length=150)
    activity_slug = models.CharField(max_length=150)
    activity_type = models.CharField(max_length=50, choices=ACTIVITY_TYPE_CHOICES)
    activity_description = models.TextField(blank=True, null=True)
    activity_date_planned = models.DateTimeField()
    activity_date_done = models.DateTimeField(blank=True, null=True)
    activity_status = models.IntegerField(default=0, choices=STATUS_CHOICES)
    activity_priority = models.IntegerField(default=1, choices=PRIORITY_CHOICES)
    activity_anomaly = models.IntegerField(default=0)
    activity_anomaly_desc = models.TextField(blank=True, null=True)
    activity_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'activities'
# Adicionar este modelo ao ficheiro activities/models.py

class Yields(models.Model):
    yield_id = models.AutoField(primary_key=True)
    farm_id = models.IntegerField()
    land_id = models.IntegerField()
    crop_id = models.IntegerField()
    variety_id = models.IntegerField(blank=True, null=True)
    yield_name = models.CharField(max_length=100)
    yield_slug = models.CharField(max_length=100)
    yield_method = models.CharField(max_length=100)
    yield_plant_numbers = models.IntegerField(blank=True, null=True)
    yield_size = models.DecimalField(max_digits=9, decimal_places=3)
    yield_notes = models.TextField(blank=True, null=True)
    yield_estimated = models.CharField(max_length=50, blank=True, null=True)
    yield_unit = models.CharField(max_length=75, blank=True, null=True)
    yield_status = models.IntegerField(default=1)
    yield_production = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    yield_graph = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'yields'
