# ============================================================
# Vision4Farms — Django Models (Opção B)
# A BD é gerida externamente (MySQL). O Django só lê/escreve.
# managed = False em todos os modelos.
# ============================================================

from django.db import models


# ============================================================
# MÓDULO 1 — Autenticação
# ============================================================

class Users(models.Model):
    user_id = models.AutoField(primary_key=True)
    username = models.CharField(unique=True, max_length=90)
    password_hash = models.CharField(max_length=120)
    reset_token = models.CharField(max_length=120, blank=True, null=True)
    reset_expire = models.DateTimeField(blank=True, null=True)
    user_status = models.IntegerField(default=0)  # 0=inativo, 1=ativo

    class Meta:
        managed = False
        db_table = 'users'

    def __str__(self):
        return self.username


class Profiles(models.Model):
    profile_id = models.AutoField(primary_key=True)
    user = models.OneToOneField(Users, models.DO_NOTHING, db_column='user_id')
    profile_name = models.CharField(max_length=150)
    profile_nif = models.CharField(unique=True, max_length=9, blank=True, null=True)
    profile_nifap = models.CharField(unique=True, max_length=9, blank=True, null=True)
    profile_cardfit = models.CharField(unique=True, max_length=9, blank=True, null=True)
    profile_picture = models.TextField(blank=True, null=True)
    profile_email = models.CharField(unique=True, max_length=90)
    profile_mobile = models.CharField(max_length=13, blank=True, null=True)
    profile_phone = models.CharField(max_length=13, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'profiles'

    def __str__(self):
        return self.profile_name


class LoginHistory(models.Model):
    login_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(Users, models.DO_NOTHING, db_column='user_id')
    login_ip = models.CharField(max_length=45)
    login_device = models.CharField(max_length=45)
    login_location = models.CharField(max_length=45)
    login_status = models.CharField(max_length=45)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'login_history'

    def __str__(self):
        return f'{self.user} — {self.created_at}'


class Logs(models.Model):
    log_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(Users, models.DO_NOTHING, db_column='user_id', blank=True, null=True)
    log_action = models.CharField(max_length=45, blank=True, null=True)
    log_message = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'logs'

    def __str__(self):
        return f'{self.log_action} — {self.created_at}'


# ============================================================
# MÓDULO 2 — Empresas & Explorações
# ============================================================

class Companies(models.Model):
    company_id = models.AutoField(primary_key=True)
    company_name = models.CharField(max_length=90)
    company_slug = models.CharField(max_length=90)
    company_nif = models.CharField(unique=True, max_length=9, blank=True, null=True)
    company_nifap = models.CharField(max_length=45, blank=True, null=True)
    company_mobile = models.IntegerField(blank=True, null=True)
    company_phone = models.IntegerField(blank=True, null=True)
    company_email = models.CharField(unique=True, max_length=45)
    company_address = models.CharField(max_length=120, blank=True, null=True)
    company_zipcode = models.CharField(max_length=8, blank=True, null=True)
    company_location = models.CharField(max_length=90, blank=True, null=True)
    company_city = models.CharField(max_length=45, blank=True, null=True)
    company_district = models.CharField(max_length=45, blank=True, null=True)
    company_country = models.CharField(max_length=45, blank=True, null=True)
    company_status = models.IntegerField(default=1)  # 1=ativa
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'companies'

    def __str__(self):
        return self.company_name


class Farms(models.Model):
    farm_id = models.AutoField(primary_key=True)
    current_company = models.ForeignKey(Companies, models.DO_NOTHING, db_column='current_company')
    farm_name = models.CharField(max_length=120)
    farm_slug = models.CharField(max_length=120)
    farm_address = models.CharField(max_length=120, blank=True, null=True)
    farm_zipcode = models.CharField(max_length=45, blank=True, null=True)
    farm_location = models.CharField(max_length=45, blank=True, null=True)
    farm_city = models.CharField(max_length=45, blank=True, null=True)
    farm_district = models.CharField(max_length=45, blank=True, null=True)
    farm_country = models.CharField(max_length=45, blank=True, null=True)
    farm_gps = models.CharField(max_length=90, blank=True, null=True)
    farm_description = models.TextField(blank=True, null=True)
    farm_status = models.IntegerField(default=1)  # 1=ativa
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'farms'

    def __str__(self):
        return self.farm_name


class ProfilesHasCompanies(models.Model):
    row_id = models.AutoField(primary_key=True)
    profile = models.ForeignKey(Profiles, models.DO_NOTHING, db_column='profile_id')
    company = models.ForeignKey(Companies, models.DO_NOTHING, db_column='company_id')
    connection_status = models.IntegerField(default=1)
    connection_start_date = models.DateField(blank=True, null=True)
    connection_end_date = models.DateField(blank=True, null=True)
    connection_role = models.IntegerField(blank=True, null=True, default=1)
    default_company = models.IntegerField(default=0)  # 1=empresa padrão
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'profiles_has_companies'

    def __str__(self):
        return f'{self.profile} → {self.company}'


class ProfilesHasFarms(models.Model):
    row_id = models.AutoField(primary_key=True)
    profile = models.ForeignKey(Profiles, models.DO_NOTHING, db_column='profile_id')
    farm = models.ForeignKey(Farms, models.DO_NOTHING, db_column='farm_id')
    connection_date = models.DateField()
    connection_role = models.IntegerField()
    connection_status = models.IntegerField(default=1)
    default_farm = models.IntegerField(default=1)  # 1=exploração padrão
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'profiles_has_farms'

    def __str__(self):
        return f'{self.profile} → {self.farm}'


# ============================================================
# MÓDULO 3 — Culturas & Variedades
# ============================================================

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
    crop = models.ForeignKey(Crops, models.DO_NOTHING, db_column='crop_id')
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
        return f'{self.crop} — {self.variety_name}'


# ============================================================
# MÓDULO 4 — Terrenos
# ============================================================

class Lands(models.Model):
    land_id = models.AutoField(primary_key=True)
    current_farm = models.ForeignKey(Farms, models.DO_NOTHING, db_column='current_farm', blank=True, null=True)
    land_name = models.CharField(max_length=90)
    land_slug = models.CharField(max_length=90)
    land_location = models.CharField(max_length=90, blank=True, null=True)
    land_sketch = models.TextField(blank=True, null=True)  # GeoJSON para Mapbox
    land_gps = models.CharField(max_length=45, blank=True, null=True)
    land_size = models.DecimalField(max_digits=5, decimal_places=3, blank=True, null=True)
    land_inclination = models.CharField(max_length=45, blank=True, null=True)
    land_sun_exposure = models.CharField(max_length=45, blank=True, null=True)
    land_elevation = models.CharField(max_length=90, blank=True, null=True)
    land_levels = models.CharField(max_length=45, blank=True, null=True)
    land_water = models.IntegerField(blank=True, null=True, default=0)  # 0=não, 1=sim
    land_notes = models.TextField(blank=True, null=True)
    land_status = models.IntegerField(default=1)  # 1=ativo
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
    land = models.ForeignKey(Lands, models.DO_NOTHING, db_column='land_id')
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

    def __str__(self):
        return f'{self.land} — {self.soil_analysis_date}'


class LandsSoilDefault(models.Model):
    lands_soil_default_id = models.AutoField(primary_key=True)
    land = models.ForeignKey(Lands, models.DO_NOTHING, db_column='land_id')
    soil_default_ph_h20_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_ph_h20_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_acidifier_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_acidifier_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_ph_cacl2_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_ph_cacl2_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_conductivity_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_conductivity_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_organic_matter_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_organic_matter_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_total_nitrogen_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_total_nitrogen_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_carbon_nitrogen_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_carbon_nitrogen_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_phosphor_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_phosphor_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_potassium_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_potassium_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_calcium_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_calcium_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_magnesium_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_magnesium_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_sulfur_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_sulfur_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_iron_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_iron_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_manganese_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_manganese_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_manganese_activity_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_manganese_activity_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_boron_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_boron_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_copper_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_copper_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_zinc_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_zinc_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_molybdenum_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_molybdenum_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_sodium_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_sodium_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_nickel_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_nickel_max = models.CharField(max_length=45, blank=True, null=True)
    soil_default_cobalt_min = models.CharField(max_length=45, blank=True, null=True)
    soil_default_cobalt_max = models.CharField(max_length=45, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'lands_soil_default'

    def __str__(self):
        return f'Valores referência — {self.land}'


# ============================================================
# MÓDULO 5 — Cultivo (Yields)
# ============================================================

class Yields(models.Model):
    yield_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING, db_column='farm_id')
    land = models.ForeignKey(Lands, models.DO_NOTHING, db_column='land_id')
    crop = models.ForeignKey(Crops, models.DO_NOTHING, db_column='crop_id')
    variety = models.ForeignKey(CropsVarieties, models.DO_NOTHING, db_column='variety_id', blank=True, null=True)
    yield_name = models.CharField(max_length=100)
    yield_slug = models.CharField(max_length=100)
    yield_method = models.CharField(max_length=100)
    yield_plant_numbers = models.IntegerField(blank=True, null=True)
    yield_plant_beetween_rows = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    yield_plant_in_rows = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    yield_size = models.DecimalField(max_digits=9, decimal_places=3)
    yield_notes = models.TextField(blank=True, null=True)
    yield_estimated = models.CharField(max_length=50, blank=True, null=True)
    yield_unit = models.CharField(max_length=75, blank=True, null=True)
    yield_status = models.IntegerField(default=1)  # 1=ativa
    yield_production = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    yield_graph = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'yields'

    def __str__(self):
        return self.yield_name


class YieldsHarvests(models.Model):
    harvest_id = models.AutoField(primary_key=True)
    yield_field = models.ForeignKey(Yields, models.DO_NOTHING, db_column='yield_id')
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
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'yields_harvests'

    def __str__(self):
        return f'{self.yield_field} — {self.harvest_date}'


class YieldsAnalysis(models.Model):
    yield_analysis_id = models.AutoField(primary_key=True)
    yield_field = models.ForeignKey(Yields, models.DO_NOTHING, db_column='yield_id')
    yield_analysis_date = models.DateField()
    yield_analysis_sample = models.CharField(max_length=45)
    yield_analysis_file = models.TextField()
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

    def __str__(self):
        return f'{self.yield_field} — {self.yield_analysis_date}'


class YieldsAnalysisDefault(models.Model):
    yield_default_id = models.AutoField(primary_key=True)
    yield_field = models.ForeignKey(Yields, models.DO_NOTHING, db_column='yield_id')
    yield_default_nitrogen_total_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_nitrogen_total_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_phosphorus_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_phosphorus_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_potassium_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_potassium_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_calcium_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_calcium_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_magnesium_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_magnesium_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_sulfur_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_sulfur_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_iron_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_iron_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_manganese_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_manganese_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_boro_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_boro_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_cobre_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_cobre_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_zinc_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_zinc_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_molybdenum_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_molybdenum_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_sodium_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_sodium_max = models.CharField(max_length=45, blank=True, null=True)
    yield_default_aluminum_min = models.CharField(max_length=45, blank=True, null=True)
    yield_default_aluminum_max = models.CharField(max_length=45, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'yields_analysis_default'

    def __str__(self):
        return f'Valores referência — {self.yield_field}'


# ============================================================
# MÓDULO 6 — Água & Rega
# ============================================================

class WaterSourceType(models.Model):
    water_type_id = models.AutoField(primary_key=True)
    water_type_name = models.CharField(unique=True, max_length=50)

    class Meta:
        managed = False
        db_table = 'water_source_type'

    def __str__(self):
        return self.water_type_name


class WaterSource(models.Model):
    water_source_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING, db_column='farm_id')
    water_type = models.ForeignKey(WaterSourceType, models.DO_NOTHING, db_column='water_type_id')
    water_source_name = models.CharField(max_length=100)
    water_source_slug = models.CharField(max_length=100)
    water_source_location_description = models.TextField(blank=True, null=True)
    water_source_latitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    water_source_longitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    water_source_depth_meters = models.DecimalField(max_digits=6, decimal_places=3, blank=True, null=True)
    water_source_capacity = models.DecimalField(max_digits=9, decimal_places=3, blank=True, null=True)
    water_source_notes = models.TextField(blank=True, null=True)
    water_source_ownership = models.IntegerField(default=1)
    water_source_has_costs = models.IntegerField(default=0)
    water_source_build_date = models.DateField(blank=True, null=True)
    water_source_build_cost = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    water_source_build_invoice = models.TextField(blank=True, null=True)
    water_source_status = models.IntegerField(default=1)  # 1=ativa
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'water_source'

    def __str__(self):
        return self.water_source_name


class WaterIrrigationMethod(models.Model):
    water_irrigation_id = models.AutoField(primary_key=True)
    water_irrigation_name = models.CharField(unique=True, max_length=100)

    class Meta:
        managed = False
        db_table = 'water_irrigation_method'

    def __str__(self):
        return self.water_irrigation_name


class WaterUsageLog(models.Model):
    water_usage_id = models.AutoField(primary_key=True)
    water_source = models.ForeignKey(WaterSource, models.DO_NOTHING, db_column='water_source_id')
    land = models.ForeignKey(Lands, models.DO_NOTHING, db_column='land_id', blank=True, null=True)
    water_usage_usage_date = models.DateField()
    water_usage_volume_liters = models.DecimalField(max_digits=10, decimal_places=3)
    water_usage_cost = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    water_usage_method = models.ForeignKey(WaterIrrigationMethod, models.DO_NOTHING, db_column='water_usage_method', blank=True, null=True)
    water_usage_purpose = models.CharField(max_length=200, blank=True, null=True)
    water_usage_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'water_usage_log'

    def __str__(self):
        return f'{self.water_source} — {self.water_usage_usage_date}'


class WaterIrrigationPlanned(models.Model):
    planned_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING, db_column='farm_id')
    land = models.ForeignKey(Lands, models.DO_NOTHING, db_column='land_id')
    water_source = models.ForeignKey(WaterSource, models.DO_NOTHING, db_column='water_source_id', blank=True, null=True)
    yield_field = models.ForeignKey(Yields, models.DO_NOTHING, db_column='yield_id', blank=True, null=True)
    planned_date = models.DateField()
    planned_time = models.TimeField(blank=True, null=True)
    planned_duration_min = models.IntegerField(blank=True, null=True)
    planned_volume_liters = models.DecimalField(max_digits=10, decimal_places=3, blank=True, null=True)
    irrigation_method = models.ForeignKey(WaterIrrigationMethod, models.DO_NOTHING, db_column='irrigation_method', blank=True, null=True)
    irrigation_status = models.IntegerField(default=0)  # 0=planeada, 1=executada, 2=cancelada
    executed_at = models.DateTimeField(blank=True, null=True)
    water_usage = models.ForeignKey(WaterUsageLog, models.DO_NOTHING, db_column='water_usage_id', blank=True, null=True)
    planned_notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'water_irrigation_planned'

    def __str__(self):
        return f'{self.land} — {self.planned_date}'


# ============================================================
# MÓDULO 7 — Observações, Atividades & Agenda
# ============================================================

class Observations(models.Model):
    observation_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING, db_column='farm_id')
    land = models.ForeignKey(Lands, models.DO_NOTHING, db_column='land_id')
    yield_field = models.ForeignKey(Yields, models.DO_NOTHING, db_column='yield_id', blank=True, null=True)
    observation_text = models.TextField()
    observation_photo = models.TextField(blank=True, null=True)
    observation_gps = models.CharField(max_length=45, blank=True, null=True)
    estado_fenologico = models.CharField(max_length=100, blank=True, null=True)
    numero_armadilha = models.CharField(max_length=50, blank=True, null=True)
    qt_detetada = models.DecimalField(max_digits=9, decimal_places=2, blank=True, null=True)
    praga_fungo = models.CharField(max_length=8, blank=True, null=True)  # ENUM: praga|fungo|virus|bacteria|outro
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'observations'

    def __str__(self):
        return f'{self.land} — {self.created_at}'


class Activities(models.Model):
    activity_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING, db_column='farm_id')
    land = models.ForeignKey(Lands, models.DO_NOTHING, db_column='land_id')
    yield_field = models.ForeignKey(Yields, models.DO_NOTHING, db_column='yield_id', blank=True, null=True)
    user = models.ForeignKey(Users, models.DO_NOTHING, db_column='user_id')
    observation = models.ForeignKey(Observations, models.DO_NOTHING, db_column='observation_id', blank=True, null=True)
    activity_name = models.CharField(max_length=150)
    activity_slug = models.CharField(max_length=150)
    activity_type = models.CharField(max_length=50)  # treatment|fertilization|pruning|irrigation|harvest|inspection|other
    activity_description = models.TextField(blank=True, null=True)
    activity_date_planned = models.DateTimeField()
    activity_date_done = models.DateTimeField(blank=True, null=True)
    activity_status = models.IntegerField(default=0)  # 0=pendente|1=concluída|2=atrasada|3=cancelada
    activity_priority = models.IntegerField(default=1)  # 1=normal|2=alta|3=urgente
    activity_anomaly = models.IntegerField(default=0)  # 1=tem anomalia
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

    def __str__(self):
        return self.activity_name


class ActivitiesImages(models.Model):
    image_id = models.AutoField(primary_key=True)
    activity = models.ForeignKey(Activities, models.DO_NOTHING, db_column='activity_id', blank=True, null=True)
    observation = models.ForeignKey(Observations, models.DO_NOTHING, db_column='observation_id', blank=True, null=True)
    image_path = models.TextField()
    image_caption = models.CharField(max_length=200, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'activities_images'

    def __str__(self):
        return f'Imagem #{self.image_id}'


class Agenda(models.Model):
    agenda_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING, db_column='farm_id')
    land = models.ForeignKey(Lands, models.DO_NOTHING, db_column='land_id', blank=True, null=True)
    yield_field = models.ForeignKey(Yields, models.DO_NOTHING, db_column='yield_id', blank=True, null=True)
    activity = models.ForeignKey(Activities, models.DO_NOTHING, db_column='activity_id', blank=True, null=True)
    user = models.ForeignKey(Users, models.DO_NOTHING, db_column='user_id')
    agenda_title = models.CharField(max_length=150)
    agenda_description = models.TextField(blank=True, null=True)
    agenda_type = models.CharField(max_length=50, default='task')  # task|visit|meeting|reminder|other
    agenda_date = models.DateField()
    agenda_time_start = models.TimeField(blank=True, null=True)
    agenda_time_end = models.TimeField(blank=True, null=True)
    agenda_allday = models.IntegerField(default=1)  # 1=dia inteiro
    recurrence = models.CharField(max_length=20, default='none')  # none|daily|weekly|monthly|yearly
    recurrence_end = models.DateField(blank=True, null=True)
    agenda_status = models.IntegerField(default=0)  # 0=pendente|1=concluído|2=cancelado
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

    def __str__(self):
        return self.agenda_title


# ============================================================
# MÓDULO 8 — Notificações
# ============================================================

class Notifications(models.Model):
    notification_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(Users, models.DO_NOTHING, db_column='user_id')
    farm = models.ForeignKey(Farms, models.DO_NOTHING, db_column='farm_id', blank=True, null=True)
    land = models.ForeignKey(Lands, models.DO_NOTHING, db_column='land_id', blank=True, null=True)
    activity = models.ForeignKey(Activities, models.DO_NOTHING, db_column='activity_id', blank=True, null=True)
    agenda = models.ForeignKey(Agenda, models.DO_NOTHING, db_column='agenda_id', blank=True, null=True)
    observation = models.ForeignKey(Observations, models.DO_NOTHING, db_column='observation_id', blank=True, null=True)
    crop = models.ForeignKey(Crops, models.DO_NOTHING, db_column='crop_id', blank=True, null=True)
    notification_type = models.CharField(max_length=50)  # activity|irrigation|agenda|analysis|observation|system|other
    notification_title = models.CharField(max_length=150)
    notification_body = models.TextField()
    notification_read = models.IntegerField(default=0)  # 0=não lida, 1=lida
    notification_read_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'notifications'

    def __str__(self):
        return self.notification_title
