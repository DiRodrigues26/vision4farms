from django.db import models


class SensorNodeAssociation(models.Model):
    association_id = models.AutoField(primary_key=True)
    farm_id = models.IntegerField()
    land_id = models.IntegerField()
    gateway_code = models.CharField(max_length=45)
    sensor_firebase_id = models.CharField(max_length=120)
    sensor_no_id = models.CharField(max_length=45, blank=True, null=True)
    sensor_nome = models.CharField(max_length=120)
    sensor_tipo = models.CharField(max_length=45, blank=True, null=True)
    sensor_status = models.CharField(max_length=45, blank=True, null=True)
    ultimo_contacto = models.CharField(max_length=45, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'sensor_node_associations'
        indexes = [
            models.Index(fields=['farm_id'], name='idx_sna_farm'),
            models.Index(fields=['land_id'], name='idx_sna_land'),
            models.Index(fields=['gateway_code'], name='idx_sna_gateway'),
            models.Index(fields=['sensor_firebase_id'], name='idx_sna_firebase'),
            models.Index(fields=['sensor_no_id'], name='idx_sna_no_id'),
        ]

    def __str__(self):
        return f'{self.sensor_nome} -> terreno {self.land_id}'
