from django.db import models


class Crops(models.Model):
    crop_id = models.AutoField(primary_key=True)
    crop_name = models.CharField(max_length=100)
    crop_type = models.CharField(max_length=50)
    production_cycle = models.CharField(max_length=50, blank=True, null=True)
    crop_graph = models.CharField(max_length=50, default='Não')
    planting_season = models.CharField(max_length=50, blank=True, null=True)
    harvest_season = models.CharField(max_length=50, blank=True, null=True)
    preferred_climate = models.CharField(max_length=100, blank=True, null=True)
    preferred_soil = models.CharField(max_length=50, blank=True, null=True)
    water_needs = models.CharField(max_length=100, blank=True, null=True)
    common_enemies = models.TextField(blank=True, null=True)
    crop_observations = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'crops'

    def __str__(self):
        return self.crop_name


class CropsVarieties(models.Model):
    variety_id = models.AutoField(primary_key=True)
    crop = models.ForeignKey(Crops, models.DO_NOTHING, related_name='varieties')
    variety_name = models.CharField(max_length=100)
    variety_description = models.TextField(blank=True, null=True)
    strong_points = models.TextField(blank=True, null=True)
    weak_points = models.TextField(blank=True, null=True)
    variety_observations = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'crops_varieties'

    def __str__(self):
        return self.variety_name
