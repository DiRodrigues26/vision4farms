from django.db import models


class Companies(models.Model):
    company_id = models.AutoField(primary_key=True)
    company_name = models.CharField(max_length=90)
    company_slug = models.CharField(max_length=90)
    company_nif = models.CharField(max_length=9, unique=True, blank=True, null=True)
    company_nifap = models.CharField(max_length=45, blank=True, null=True)
    company_mobile = models.IntegerField(blank=True, null=True)
    company_phone = models.IntegerField(blank=True, null=True)
    company_email = models.CharField(max_length=45, unique=True)
    company_address = models.CharField(max_length=120, blank=True, null=True)
    company_zipcode = models.CharField(max_length=8, blank=True, null=True)
    company_location = models.CharField(max_length=90, blank=True, null=True)
    company_city = models.CharField(max_length=45, blank=True, null=True)
    company_district = models.CharField(max_length=45, blank=True, null=True)
    company_country = models.CharField(max_length=45, blank=True, null=True)
    company_status = models.IntegerField(default=1)
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


class ProfilesHasCompanies(models.Model):
    row_id = models.AutoField(primary_key=True)
    profile_id = models.IntegerField()
    company = models.ForeignKey(Companies, models.DO_NOTHING, db_column='company_id')
    connection_status = models.IntegerField(default=1)
    connection_start_date = models.DateField(blank=True, null=True)
    connection_end_date = models.DateField(blank=True, null=True)
    connection_role = models.IntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)
    default_company = models.IntegerField(default=0)

    class Meta:
        managed = False
        db_table = 'profiles_has_companies'


class Farms(models.Model):
    farm_id = models.AutoField(primary_key=True)
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
    farm_status = models.IntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)
    current_company = models.ForeignKey(
        Companies, models.DO_NOTHING, db_column='current_company'
    )

    class Meta:
        managed = False
        db_table = 'farms'

    def __str__(self):
        return self.farm_name


class ProfilesHasFarms(models.Model):
    row_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.DO_NOTHING)
    profile_id = models.IntegerField()
    connection_date = models.DateField()
    connection_role = models.IntegerField(default=2)  # 1=Gestor, 2=Colaborador, 3=Consultor
    connection_status = models.IntegerField(default=1)  # 0=pendente, 1=ativo, 2=recusado
    default_farm = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'profiles_has_farms'


class FarmInvites(models.Model):
    invite_id = models.AutoField(primary_key=True)
    farm = models.ForeignKey(Farms, models.CASCADE, db_column='farm_id')
    invite_code = models.CharField(max_length=8, unique=True)
    invite_email = models.CharField(max_length=90, blank=True, null=True)
    invite_role = models.IntegerField(default=2)  # 1=Gestor, 2=Colaborador, 3=Consultor
    invite_status = models.IntegerField(default=0)  # 0=ativo, 1=usado, 2=expirado, 3=cancelado
    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(blank=True, null=True)
    used_by = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()

    class Meta:
        managed = False
        db_table = 'farm_invites'