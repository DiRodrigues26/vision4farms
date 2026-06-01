from django.db import models


class YieldsHarvests(models.Model):
    harvest_id = models.AutoField(primary_key=True)
    yield_field = models.ForeignKey('Yields', models.DO_NOTHING, db_column='yield_id')
    harvest_date = models.DateField()
    harvest_name = models.CharField(max_length=150)
    harvest_harvested = models.DecimalField(max_digits=9, decimal_places=3)
    unit_measurement = models.CharField(max_length=50, default='KG')
    harvested_labor_count = models.IntegerField(blank=True, null=True)
    harvested_labor_hours = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    harvested_labor_hours_per_operator = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    harvested_labor_total_cost = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    harvest_kg_per_operator = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    harvested_machine_count = models.IntegerField(blank=True, null=True)
    harvested_machine_hours = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    harvested_machine_cost = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    total_harvest_cost = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    harvest_cost_per_kg = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    harvest_kg_per_hour = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'yields_harvests'


class YieldsAnalysis(models.Model):
    yield_analysis_id = models.AutoField(primary_key=True)
    yield_field = models.ForeignKey('Yields', models.DO_NOTHING, db_column='yield_id')
    yield_analysis_date = models.DateField()
    yield_analysis_sample = models.CharField(max_length=45)
    yield_analysis_file = models.TextField(blank=True, null=True)
    yield_analysis_nitrogen_total = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_phosphorus = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_potassium = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_calcium = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_magnesium = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_sulfur = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_iron = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_manganese = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_boro = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_cobre = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_zinc = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_molybdenum = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_sodium = models.CharField(max_length=45, blank=True, null=True)
    yield_analysis_aluminum = models.CharField(max_length=45, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'yields_analysis'


class Yields(models.Model):
    yield_id     = models.AutoField(primary_key=True)
    farm_id      = models.IntegerField()
    land_id      = models.IntegerField()
    crop_id      = models.IntegerField()
    variety_id   = models.IntegerField(blank=True, null=True)
    yield_name   = models.CharField(max_length=100)
    yield_slug   = models.CharField(max_length=100)
    yield_method = models.CharField(max_length=100)
    yield_plant_numbers        = models.IntegerField(blank=True, null=True)
    yield_plant_beetween_rows  = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    yield_plant_in_rows        = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    yield_size   = models.DecimalField(max_digits=9, decimal_places=3)
    yield_notes  = models.TextField(blank=True, null=True)
    yield_estimated   = models.CharField(max_length=50, blank=True, null=True)
    yield_unit        = models.CharField(max_length=75, blank=True, null=True)
    yield_status      = models.IntegerField(default=1)
    yield_production  = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    yield_graph       = models.IntegerField(default=0)
    created_at  = models.DateTimeField(auto_now_add=True)
    created_by  = models.IntegerField()
    updated_at  = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by  = models.IntegerField(blank=True, null=True)
    deleted_at  = models.DateTimeField(blank=True, null=True)
    deleted_by  = models.IntegerField(blank=True, null=True)

    class Meta:
        managed  = False
        db_table = 'yields'

    def __str__(self):
        return self.yield_name
