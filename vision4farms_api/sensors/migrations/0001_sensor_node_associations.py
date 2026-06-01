from django.db import migrations


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.RunSQL(
            sql="""
            CREATE TABLE IF NOT EXISTS sensor_node_associations (
                association_id INT AUTO_INCREMENT PRIMARY KEY,
                farm_id INT NOT NULL,
                land_id INT NOT NULL,
                gateway_code VARCHAR(45) NOT NULL,
                sensor_firebase_id VARCHAR(120) NOT NULL,
                sensor_no_id VARCHAR(45) NULL,
                sensor_nome VARCHAR(120) NOT NULL,
                sensor_tipo VARCHAR(45) NULL,
                sensor_status VARCHAR(45) NULL,
                ultimo_contacto VARCHAR(45) NULL,
                created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
                created_by INT NOT NULL,
                updated_at DATETIME(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
                updated_by INT NULL,
                deleted_at DATETIME(6) NULL,
                deleted_by INT NULL,
                INDEX idx_sna_farm (farm_id),
                INDEX idx_sna_land (land_id),
                INDEX idx_sna_gateway (gateway_code),
                INDEX idx_sna_firebase (sensor_firebase_id),
                INDEX idx_sna_no_id (sensor_no_id),
                CONSTRAINT fk_sna_farm FOREIGN KEY (farm_id) REFERENCES farms (farm_id),
                CONSTRAINT fk_sna_land FOREIGN KEY (land_id) REFERENCES lands (land_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            """,
            reverse_sql="DROP TABLE IF EXISTS sensor_node_associations;",
        ),
    ]
