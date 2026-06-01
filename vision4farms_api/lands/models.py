from django.db import models
from farms.models import Farms


class Lands(models.Model):
    land_id = models.AutoField(primary_key=True)
    current_farm = models.ForeignKey(
        Farms, models.DO_NOTHING, db_column='current_farm', blank=True, null=True
    )
    land_name = models.CharField(max_length=90)
    land_slug = models.CharField(max_length=90)
    land_location = models.CharField(max_length=90, blank=True, null=True)
    land_sketch = models.TextField(blank=True, null=True)
    land_gps = models.CharField(max_length=45, blank=True, null=True)
    land_size = models.DecimalField(max_digits=5, decimal_places=3, blank=True, null=True)
    land_inclination = models.CharField(max_length=45, blank=True, null=True)
    land_sun_exposure = models.CharField(max_length=45, blank=True, null=True)
    land_elevation = models.CharField(max_length=90, blank=True, null=True)
    land_levels = models.CharField(max_length=45, blank=True, null=True)
    land_water = models.IntegerField(default=0, blank=True, null=True)
    land_notes = models.TextField(blank=True, null=True)
    land_status = models.IntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'lands'

    def __str__(self):
        return self.land_name


class LandsSoilAnalysis(models.Model):
    soil_analysis_id = models.AutoField(primary_key=True)
    land = models.ForeignKey(Lands, models.DO_NOTHING, related_name='soil_analyses')
    soil_analysis_date = models.DateField()
    soil_analysis_sample = models.CharField(max_length=90)
    soil_analysis_file = models.TextField(blank=True, null=True)
    soil_analysis_ph_h20 = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_acidifier = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_ph_cacl2 = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_conductivity = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_organic_matter = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_total_nitrogen = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_carbon_nitrogen = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_phosphor = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_potassium = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_calcium = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_magnesium = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_sulfur = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_iron = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_manganese = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_manganese_activity = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_boron = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_copper = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_zinc = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_molybdenum = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_sodium = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_nickel = models.CharField(max_length=45, blank=True, null=True)
    soil_analysis_cobalt = models.CharField(max_length=45, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'lands_soil_analysis'
# Adicionar estes modelos ao ficheiro lands/models.py

class WaterSourceType(models.Model):
    water_type_id = models.AutoField(primary_key=True)
    water_type_name = models.CharField(max_length=50, unique=True)

    class Meta:
        managed = False
        db_table = 'water_source_type'

    def __str__(self):
        return self.water_type_name


class WaterIrrigationMethod(models.Model):
    water_irrigation_id = models.AutoField(primary_key=True)
    water_irrigation_name = models.CharField(max_length=100, unique=True)

    class Meta:
        managed = False
        db_table = 'water_irrigation_method'

    def __str__(self):
        return self.water_irrigation_name


class WaterSource(models.Model):
    farm_id = models.IntegerField()
    water_source_id = models.AutoField(primary_key=True)
    water_source_name = models.CharField(max_length=100)
    water_source_slug = models.CharField(max_length=100)
    water_type_id = models.IntegerField()
    water_source_location_description = models.TextField(blank=True, null=True)
    water_source_latitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    water_source_longitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    water_source_depth_meters = models.DecimalField(max_digits=6, decimal_places=3, blank=True, null=True)
    water_source_capacity = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    water_source_notes = models.TextField(blank=True, null=True)
    water_source_ownership = models.BooleanField(default=True)
    water_source_has_costs = models.BooleanField(default=False)
    water_source_build_date = models.DateField(blank=True, null=True)
    water_source_build_cost = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    water_source_build_invoice = models.TextField(default='', blank=True)
    water_source_status = models.IntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'water_source'

    def __str__(self):
        return self.water_source_name


class WaterUsageLog(models.Model):
    water_usage_id = models.AutoField(primary_key=True)
    water_source_id = models.IntegerField()
    land_id = models.IntegerField(blank=True, null=True)
    water_usage_usage_date = models.DateField()
    water_usage_volume_liters = models.DecimalField(max_digits=10, decimal_places=3)
    water_usage_cost = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    water_usage_method = models.IntegerField(blank=True, null=True)
    water_usage_purpose = models.CharField(max_length=200, blank=True, null=True)
    water_usage_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'water_usage_log'


class WaterIrrigationPlanned(models.Model):
    planned_id = models.AutoField(primary_key=True)
    farm_id = models.IntegerField()
    land_id = models.IntegerField()
    water_source_id = models.IntegerField(blank=True, null=True)
    yield_id = models.IntegerField(blank=True, null=True)
    planned_date = models.DateField()
    planned_time = models.TimeField(blank=True, null=True)
    planned_duration_min = models.IntegerField(blank=True, null=True)
    planned_volume_liters = models.DecimalField(max_digits=10, decimal_places=3, blank=True, null=True)
    irrigation_method = models.IntegerField(blank=True, null=True)
    irrigation_status = models.IntegerField(default=0)
    executed_at = models.DateTimeField(blank=True, null=True)
    water_usage_id = models.IntegerField(blank=True, null=True)
    planned_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'water_irrigation_planned'