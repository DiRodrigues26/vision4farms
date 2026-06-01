-- MySQL dump 10.13  Distrib 8.0.45, for Win64 (x86_64)
--
-- Host: localhost    Database: vision4farms
-- ------------------------------------------------------
-- Server version	8.0.45

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `activities`
--

DROP TABLE IF EXISTS `activities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `activities` (
  `activity_id` int NOT NULL AUTO_INCREMENT,
  `farm_id` int NOT NULL,
  `land_id` int NOT NULL,
  `yield_id` int DEFAULT NULL COMMENT 'Cultura associada (opcional)',
  `user_id` int NOT NULL COMMENT 'Utilizador responsável pela atividade',
  `observation_id` int DEFAULT NULL COMMENT 'Observação que originou esta atividade (opcional)',
  `activity_name` varchar(150) NOT NULL,
  `activity_slug` varchar(150) NOT NULL,
  `activity_type` varchar(50) NOT NULL COMMENT 'treatment | fertilization | pruning | irrigation | harvest | inspection | other',
  `activity_description` text,
  `activity_date_planned` date NOT NULL COMMENT 'Data prevista para execução',
  `activity_date_done` date DEFAULT NULL COMMENT 'Data real de conclusão',
  `activity_status` int NOT NULL DEFAULT '0' COMMENT '0=pendente | 1=concluída | 2=atrasada | 3=cancelada',
  `activity_priority` int NOT NULL DEFAULT '1' COMMENT '1=normal | 2=alta | 3=urgente',
  `activity_anomaly` tinyint(1) NOT NULL DEFAULT '0' COMMENT '1=tem anomalia registada',
  `activity_anomaly_desc` text,
  `activity_notes` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`activity_id`),
  KEY `fk_activities_farms_idx` (`farm_id`),
  KEY `fk_activities_lands_idx` (`land_id`),
  KEY `fk_activities_yields_idx` (`yield_id`),
  KEY `fk_activities_users_idx` (`user_id`),
  KEY `fk_activities_observations_idx` (`observation_id`),
  KEY `idx_activity_status` (`activity_status`),
  KEY `idx_activity_date_planned` (`activity_date_planned`),
  CONSTRAINT `fk_activities_farms1` FOREIGN KEY (`farm_id`) REFERENCES `farms` (`farm_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_activities_lands1` FOREIGN KEY (`land_id`) REFERENCES `lands` (`land_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_activities_observations1` FOREIGN KEY (`observation_id`) REFERENCES `observations` (`observation_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_activities_users1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_activities_yields1` FOREIGN KEY (`yield_id`) REFERENCES `yields` (`yield_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `activities_images`
--

DROP TABLE IF EXISTS `activities_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `activities_images` (
  `image_id` int NOT NULL AUTO_INCREMENT,
  `activity_id` int DEFAULT NULL COMMENT 'Atividade associada (mutuamente exclusivo com observation_id)',
  `observation_id` int DEFAULT NULL COMMENT 'Observação associada (mutuamente exclusivo com activity_id)',
  `image_path` text NOT NULL COMMENT 'Caminho/URL do ficheiro no servidor',
  `image_caption` varchar(200) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`image_id`),
  KEY `fk_activities_images_activities_idx` (`activity_id`),
  KEY `fk_activities_images_observations_idx` (`observation_id`),
  CONSTRAINT `fk_activities_images_activities1` FOREIGN KEY (`activity_id`) REFERENCES `activities` (`activity_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_activities_images_observations1` FOREIGN KEY (`observation_id`) REFERENCES `observations` (`observation_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `agenda`
--

DROP TABLE IF EXISTS `agenda`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `agenda` (
  `agenda_id` int NOT NULL AUTO_INCREMENT,
  `farm_id` int NOT NULL,
  `land_id` int DEFAULT NULL COMMENT 'Terreno associado (opcional)',
  `yield_id` int DEFAULT NULL COMMENT 'Cultura associada (opcional)',
  `activity_id` int DEFAULT NULL COMMENT 'Atividade de campo associada (opcional)',
  `user_id` int NOT NULL COMMENT 'Utilizador responsável',
  `agenda_title` varchar(150) NOT NULL,
  `agenda_description` text,
  `agenda_type` varchar(50) NOT NULL DEFAULT 'task' COMMENT 'task | visit | meeting | reminder | other',
  `agenda_date` date NOT NULL COMMENT 'Data do evento',
  `agenda_time_start` time DEFAULT NULL COMMENT 'Hora de início (opcional)',
  `agenda_time_end` time DEFAULT NULL COMMENT 'Hora de fim (opcional)',
  `agenda_allday` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1=dia inteiro | 0=horas definidas',
  `recurrence` varchar(20) NOT NULL DEFAULT 'none' COMMENT 'none | daily | weekly | monthly | yearly',
  `recurrence_end` date DEFAULT NULL COMMENT 'Data de fim da recorrência',
  `agenda_status` int NOT NULL DEFAULT '0' COMMENT '0=pendente | 1=concluído | 2=cancelado',
  `agenda_notes` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`agenda_id`),
  KEY `fk_agenda_farms_idx` (`farm_id`),
  KEY `fk_agenda_lands_idx` (`land_id`),
  KEY `fk_agenda_yields_idx` (`yield_id`),
  KEY `fk_agenda_activities_idx` (`activity_id`),
  KEY `fk_agenda_users_idx` (`user_id`),
  KEY `idx_agenda_date` (`agenda_date`),
  KEY `idx_agenda_status` (`agenda_status`),
  CONSTRAINT `fk_agenda_activities1` FOREIGN KEY (`activity_id`) REFERENCES `activities` (`activity_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_agenda_farms1` FOREIGN KEY (`farm_id`) REFERENCES `farms` (`farm_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_agenda_lands1` FOREIGN KEY (`land_id`) REFERENCES `lands` (`land_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_agenda_users1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_agenda_yields1` FOREIGN KEY (`yield_id`) REFERENCES `yields` (`yield_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `companies`
--

DROP TABLE IF EXISTS `companies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `companies` (
  `company_id` int NOT NULL AUTO_INCREMENT,
  `company_name` varchar(90) NOT NULL,
  `company_slug` varchar(90) NOT NULL,
  `company_nif` varchar(9) DEFAULT NULL,
  `company_nifap` varchar(45) DEFAULT NULL,
  `company_mobile` int DEFAULT NULL,
  `company_phone` int DEFAULT NULL,
  `company_email` varchar(45) NOT NULL,
  `company_address` varchar(120) DEFAULT NULL,
  `company_zipcode` varchar(8) DEFAULT NULL,
  `company_location` varchar(90) DEFAULT NULL,
  `company_city` varchar(45) DEFAULT NULL,
  `company_district` varchar(45) DEFAULT NULL,
  `company_country` varchar(45) DEFAULT NULL,
  `company_status` int NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`company_id`),
  UNIQUE KEY `company_email_UNIQUE` (`company_email`),
  UNIQUE KEY `company_nif_UNIQUE` (`company_nif`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `crops`
--

DROP TABLE IF EXISTS `crops`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `crops` (
  `crop_id` int NOT NULL AUTO_INCREMENT,
  `crop_name` varchar(100) NOT NULL,
  `crop_type` varchar(50) NOT NULL,
  `production_cycle` varchar(50) DEFAULT NULL,
  `crop_graph` varchar(50) NOT NULL DEFAULT 'NÃ£o',
  `planting_season` varchar(50) DEFAULT NULL,
  `harvest_season` varchar(50) DEFAULT NULL,
  `preferred_climate` varchar(100) DEFAULT NULL,
  `preferred_soil` varchar(50) DEFAULT NULL,
  `water_needs` varchar(100) DEFAULT NULL,
  `common_enemies` text,
  `crop_observations` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`crop_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `crops_varieties`
--

DROP TABLE IF EXISTS `crops_varieties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `crops_varieties` (
  `variety_id` int NOT NULL AUTO_INCREMENT,
  `crop_id` int NOT NULL,
  `variety_name` varchar(100) NOT NULL,
  `variety_description` text,
  `strong_points` text,
  `weak_points` text,
  `variety_observations` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`variety_id`),
  KEY `crop_id` (`crop_id`),
  CONSTRAINT `crops_varieties_ibfk_1` FOREIGN KEY (`crop_id`) REFERENCES `crops` (`crop_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=43 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `farm_invites`
--

DROP TABLE IF EXISTS `farm_invites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `farm_invites` (
  `invite_id` int NOT NULL AUTO_INCREMENT,
  `farm_id` int NOT NULL,
  `invite_code` varchar(8) NOT NULL,
  `invite_status` int NOT NULL DEFAULT '0' COMMENT '0=ativo | 1=usado | 2=expirado | 3=cancelado',
  `expires_at` timestamp NOT NULL,
  `used_at` timestamp NULL DEFAULT NULL,
  `used_by` int DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `invite_email` varchar(90) DEFAULT NULL COMMENT 'Email do convidado (opcional)',
  `invite_role` int NOT NULL DEFAULT '2' COMMENT '1=Gestor 2=Colaborador 3=Consultor',
  PRIMARY KEY (`invite_id`),
  UNIQUE KEY `invite_code` (`invite_code`),
  KEY `fk_farm_invites_farms` (`farm_id`),
  CONSTRAINT `fk_farm_invites_farms1` FOREIGN KEY (`farm_id`) REFERENCES `farms` (`farm_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `farms`
--

DROP TABLE IF EXISTS `farms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `farms` (
  `farm_id` int NOT NULL AUTO_INCREMENT,
  `farm_name` varchar(120) NOT NULL,
  `farm_slug` varchar(120) NOT NULL,
  `farm_address` varchar(120) DEFAULT NULL,
  `farm_zipcode` varchar(45) DEFAULT NULL,
  `farm_location` varchar(45) DEFAULT NULL,
  `farm_city` varchar(45) DEFAULT NULL,
  `farm_district` varchar(45) DEFAULT NULL,
  `farm_country` varchar(45) DEFAULT NULL,
  `farm_gps` varchar(90) DEFAULT NULL,
  `farm_description` text,
  `farm_status` int NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  `current_company` int NOT NULL,
  PRIMARY KEY (`farm_id`),
  KEY `fk_farms_companies1_idx` (`current_company`),
  CONSTRAINT `fk_farms_companies1` FOREIGN KEY (`current_company`) REFERENCES `companies` (`company_id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lands`
--

DROP TABLE IF EXISTS `lands`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lands` (
  `land_id` int NOT NULL AUTO_INCREMENT,
  `current_farm` int DEFAULT NULL,
  `land_name` varchar(90) NOT NULL,
  `land_slug` varchar(90) NOT NULL,
  `land_location` varchar(90) DEFAULT NULL,
  `land_sketch` text,
  `land_gps` varchar(45) DEFAULT NULL,
  `land_size` decimal(5,3) DEFAULT NULL,
  `land_inclination` varchar(45) DEFAULT NULL,
  `land_sun_exposure` varchar(45) DEFAULT NULL,
  `land_elevation` varchar(90) DEFAULT NULL,
  `land_levels` varchar(45) DEFAULT NULL,
  `land_water` int DEFAULT '0',
  `land_notes` text,
  `land_status` int NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`land_id`),
  KEY `fk_lands_farms1_idx` (`current_farm`),
  CONSTRAINT `fk_lands_farms1` FOREIGN KEY (`current_farm`) REFERENCES `farms` (`farm_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lands_soil_analysis`
--

DROP TABLE IF EXISTS `lands_soil_analysis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lands_soil_analysis` (
  `land_id` int NOT NULL,
  `soil_analysis_id` int NOT NULL AUTO_INCREMENT,
  `soil_analysis_date` date NOT NULL,
  `soil_analysis_sample` varchar(90) NOT NULL,
  `soil_analysis_file` text,
  `soil_analysis_ph_h20` varchar(45) DEFAULT NULL,
  `soil_analysis_acidifier` varchar(45) DEFAULT NULL,
  `soil_analysis_ph_cacl2` varchar(45) DEFAULT NULL,
  `soil_analysis_conductivity` varchar(45) DEFAULT NULL,
  `soil_analysis_organic_matter` varchar(45) DEFAULT NULL,
  `soil_analysis_total_nitrogen` varchar(45) DEFAULT NULL,
  `soil_analysis_carbon_nitrogen` varchar(45) DEFAULT NULL,
  `soil_analysis_phosphor` varchar(45) DEFAULT NULL,
  `soil_analysis_potassium` varchar(45) DEFAULT NULL,
  `soil_analysis_calcium` varchar(45) DEFAULT NULL,
  `soil_analysis_magnesium` varchar(45) DEFAULT NULL,
  `soil_analysis_sulfur` varchar(45) DEFAULT NULL,
  `soil_analysis_iron` varchar(45) DEFAULT NULL,
  `soil_analysis_manganese` varchar(45) DEFAULT NULL,
  `soil_analysis_manganese_activity` varchar(45) DEFAULT NULL,
  `soil_analysis_boron` varchar(45) DEFAULT NULL,
  `soil_analysis_copper` varchar(45) DEFAULT NULL,
  `soil_analysis_zinc` varchar(45) DEFAULT NULL,
  `soil_analysis_molybdenum` varchar(45) DEFAULT NULL,
  `soil_analysis_sodium` varchar(45) DEFAULT NULL,
  `soil_analysis_nickel` varchar(45) DEFAULT NULL,
  `soil_analysis_cobalt` varchar(45) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`soil_analysis_id`),
  KEY `fk_lands_soil_analysis_lands2_idx` (`land_id`),
  CONSTRAINT `fk_lands_soil_analysis_lands2` FOREIGN KEY (`land_id`) REFERENCES `lands` (`land_id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `lands_soil_default`
--

DROP TABLE IF EXISTS `lands_soil_default`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lands_soil_default` (
  `lands_soil_default_id` int NOT NULL AUTO_INCREMENT,
  `soil_default_ph_h20_min` varchar(45) DEFAULT NULL,
  `soil_default_ph_h20_max` varchar(45) DEFAULT NULL,
  `soil_default_acidifier_min` varchar(45) DEFAULT NULL,
  `soil_default_acidifier_max` varchar(45) DEFAULT NULL,
  `soil_default_ph_cacl2_min` varchar(45) DEFAULT NULL,
  `soil_default_ph_cacl2_max` varchar(45) DEFAULT NULL,
  `soil_default_conductivity_min` varchar(45) DEFAULT NULL,
  `soil_default_conductivity_max` varchar(45) DEFAULT NULL,
  `soil_default_organic_matter_min` varchar(45) DEFAULT NULL,
  `soil_default_organic_matter_max` varchar(45) DEFAULT NULL,
  `soil_default_total_nitrogen_min` varchar(45) DEFAULT NULL,
  `soil_default_total_nitrogen_max` varchar(45) DEFAULT NULL,
  `soil_default_carbon_nitrogen_min` varchar(45) DEFAULT NULL,
  `soil_default_carbon_nitrogen_max` varchar(45) DEFAULT NULL,
  `soil_default_phosphor_min` varchar(45) DEFAULT NULL,
  `soil_default_phosphor_max` varchar(45) DEFAULT NULL,
  `soil_default_potassium_min` varchar(45) DEFAULT NULL,
  `soil_default_potassium_max` varchar(45) DEFAULT NULL,
  `soil_default_calcium_min` varchar(45) DEFAULT NULL,
  `soil_default_calcium_max` varchar(45) DEFAULT NULL,
  `soil_default_magnesium_min` varchar(45) DEFAULT NULL,
  `soil_default_magnesium_max` varchar(45) DEFAULT NULL,
  `soil_default_sulfur_min` varchar(45) DEFAULT NULL,
  `soil_default_sulfur_max` varchar(45) DEFAULT NULL,
  `soil_default_iron_min` varchar(45) DEFAULT NULL,
  `soil_default_iron_max` varchar(45) DEFAULT NULL,
  `soil_default_manganese_min` varchar(45) DEFAULT NULL,
  `soil_default_manganese_max` varchar(45) DEFAULT NULL,
  `soil_default_manganese_activity_min` varchar(45) DEFAULT NULL,
  `soil_default_manganese_activity_max` varchar(45) DEFAULT NULL,
  `soil_default_boron_min` varchar(45) DEFAULT NULL,
  `soil_default_boron_max` varchar(45) DEFAULT NULL,
  `soil_default_copper_min` varchar(45) DEFAULT NULL,
  `soil_default_copper_max` varchar(45) DEFAULT NULL,
  `soil_default_zinc_min` varchar(45) DEFAULT NULL,
  `soil_default_zinc_max` varchar(45) DEFAULT NULL,
  `soil_default_molybdenum_min` varchar(45) DEFAULT NULL,
  `soil_default_molybdenum_max` varchar(45) DEFAULT NULL,
  `soil_default_sodium_min` varchar(45) DEFAULT NULL,
  `soil_default_sodium_max` varchar(45) DEFAULT NULL,
  `soil_default_nickel_min` varchar(45) DEFAULT NULL,
  `soil_default_nickel_max` varchar(45) DEFAULT NULL,
  `soil_default_cobalt_min` varchar(45) DEFAULT NULL,
  `soil_default_cobalt_max` varchar(45) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  `land_id` int NOT NULL,
  PRIMARY KEY (`lands_soil_default_id`),
  KEY `fk_lands_soil_default_lands2_idx` (`land_id`),
  CONSTRAINT `fk_lands_soil_default_lands2` FOREIGN KEY (`land_id`) REFERENCES `lands` (`land_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `login_history`
--

DROP TABLE IF EXISTS `login_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `login_history` (
  `login_id` int NOT NULL AUTO_INCREMENT,
  `login_ip` varchar(45) NOT NULL,
  `login_device` varchar(45) NOT NULL,
  `login_location` varchar(45) NOT NULL,
  `login_status` varchar(45) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `user_id` int NOT NULL,
  PRIMARY KEY (`login_id`),
  KEY `fk_login_history_users1_idx` (`user_id`),
  CONSTRAINT `fk_login_history_users1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=205 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `logs`
--

DROP TABLE IF EXISTS `logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `logs` (
  `log_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int DEFAULT NULL,
  `log_action` varchar(45) DEFAULT NULL,
  `log_message` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`log_id`),
  KEY `fk_logs_users1_idx` (`user_id`),
  CONSTRAINT `fk_logs_users1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=216 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `notification_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `farm_id` int DEFAULT NULL,
  `land_id` int DEFAULT NULL,
  `activity_id` int DEFAULT NULL,
  `agenda_id` int DEFAULT NULL,
  `observation_id` int DEFAULT NULL COMMENT 'Observação que gerou a notificação (opcional)',
  `crop_id` int DEFAULT NULL COMMENT 'Cultura associada à notificação (opcional)',
  `notification_type` varchar(50) NOT NULL COMMENT 'activity | irrigation | agenda | analysis | observation | system | other',
  `notification_title` varchar(150) NOT NULL,
  `notification_body` text NOT NULL,
  `notification_read` tinyint(1) NOT NULL DEFAULT '0' COMMENT '0=não lida | 1=lida',
  `notification_read_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`notification_id`),
  KEY `fk_notifications_users_idx` (`user_id`),
  KEY `fk_notifications_farms_idx` (`farm_id`),
  KEY `fk_notifications_lands_idx` (`land_id`),
  KEY `fk_notifications_activities_idx` (`activity_id`),
  KEY `fk_notifications_agenda_idx` (`agenda_id`),
  KEY `fk_notifications_observations_idx` (`observation_id`),
  KEY `fk_notifications_crops_idx` (`crop_id`),
  KEY `idx_notification_read` (`notification_read`),
  CONSTRAINT `fk_notifications_activities1` FOREIGN KEY (`activity_id`) REFERENCES `activities` (`activity_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_notifications_agenda1` FOREIGN KEY (`agenda_id`) REFERENCES `agenda` (`agenda_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_notifications_crops1` FOREIGN KEY (`crop_id`) REFERENCES `crops` (`crop_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_notifications_farms1` FOREIGN KEY (`farm_id`) REFERENCES `farms` (`farm_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_notifications_lands1` FOREIGN KEY (`land_id`) REFERENCES `lands` (`land_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_notifications_observations1` FOREIGN KEY (`observation_id`) REFERENCES `observations` (`observation_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_notifications_users1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `observations`
--

DROP TABLE IF EXISTS `observations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `observations` (
  `observation_id` int NOT NULL AUTO_INCREMENT,
  `farm_id` int NOT NULL,
  `land_id` int NOT NULL,
  `yield_id` int DEFAULT NULL COMMENT 'Cultura associada (opcional)',
  `observation_text` text NOT NULL,
  `observation_photo` text COMMENT 'Caminho/URL da foto (opcional)',
  `observation_gps` varchar(45) DEFAULT NULL COMMENT 'Localização GPS da observação',
  `estado_fenologico` varchar(100) DEFAULT NULL COMMENT 'Estado fenológico da planta no momento da observação',
  `numero_armadilha` varchar(50) DEFAULT NULL COMMENT 'Número/identificação da armadilha (opcional)',
  `qt_detetada` decimal(9,2) DEFAULT NULL COMMENT 'Quantidade de praga/fungo detetada',
  `praga_fungo` enum('praga','fungo','virus','bacteria','outro') DEFAULT NULL COMMENT 'Tipo de agente detetado',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`observation_id`),
  KEY `fk_observations_farms_idx` (`farm_id`),
  KEY `fk_observations_lands_idx` (`land_id`),
  KEY `fk_observations_yields_idx` (`yield_id`),
  CONSTRAINT `fk_observations_farms1` FOREIGN KEY (`farm_id`) REFERENCES `farms` (`farm_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_observations_lands1` FOREIGN KEY (`land_id`) REFERENCES `lands` (`land_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_observations_yields1` FOREIGN KEY (`yield_id`) REFERENCES `yields` (`yield_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `profiles`
--

DROP TABLE IF EXISTS `profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `profiles` (
  `profile_id` int NOT NULL AUTO_INCREMENT,
  `profile_name` varchar(150) NOT NULL,
  `profile_nif` varchar(9) DEFAULT NULL,
  `profile_nifap` varchar(9) DEFAULT NULL,
  `profile_cardfit` varchar(9) DEFAULT NULL,
  `profile_picture` text,
  `profile_email` varchar(90) NOT NULL,
  `profile_mobile` varchar(13) DEFAULT NULL,
  `profile_phone` varchar(13) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  `user_id` int NOT NULL,
  PRIMARY KEY (`profile_id`),
  UNIQUE KEY `profile_email_UNIQUE` (`profile_email`),
  UNIQUE KEY `user_id_UNIQUE` (`user_id`),
  UNIQUE KEY `profile_nif_UNIQUE` (`profile_nif`),
  UNIQUE KEY `profile_nifap_UNIQUE` (`profile_nifap`),
  UNIQUE KEY `profile_cardfit` (`profile_cardfit`),
  KEY `fk_profiles_users_idx` (`user_id`),
  CONSTRAINT `fk_profiles_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `profiles_has_companies`
--

DROP TABLE IF EXISTS `profiles_has_companies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `profiles_has_companies` (
  `row_id` int NOT NULL AUTO_INCREMENT,
  `profile_id` int NOT NULL,
  `company_id` int NOT NULL,
  `connection_status` int NOT NULL DEFAULT '1',
  `connection_start_date` date DEFAULT NULL,
  `connection_end_date` date DEFAULT NULL,
  `connection_role` int DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  `default_company` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`row_id`),
  KEY `fk_profiles_has_companies_companies1_idx` (`company_id`),
  KEY `fk_profiles_has_companies_profiles1_idx` (`profile_id`),
  CONSTRAINT `fk_profiles_has_companies_companies1` FOREIGN KEY (`company_id`) REFERENCES `companies` (`company_id`),
  CONSTRAINT `fk_profiles_has_companies_profiles1` FOREIGN KEY (`profile_id`) REFERENCES `profiles` (`profile_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `profiles_has_farms`
--

DROP TABLE IF EXISTS `profiles_has_farms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `profiles_has_farms` (
  `row_id` int NOT NULL AUTO_INCREMENT,
  `farm_id` int NOT NULL,
  `profile_id` int NOT NULL,
  `connection_date` date NOT NULL,
  `connection_role` int NOT NULL,
  `connection_status` int NOT NULL DEFAULT '1',
  `default_farm` int NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`row_id`),
  KEY `fk_profiles_has_farms_farms1_idx` (`farm_id`),
  KEY `fk_profiles_has_farms_profiles1_idx` (`profile_id`),
  CONSTRAINT `fk_profiles_has_farms_farms1` FOREIGN KEY (`farm_id`) REFERENCES `farms` (`farm_id`),
  CONSTRAINT `fk_profiles_has_farms_profiles1` FOREIGN KEY (`profile_id`) REFERENCES `profiles` (`profile_id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `user_id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(90) NOT NULL,
  `password_hash` varchar(120) NOT NULL,
  `reset_token` varchar(120) DEFAULT NULL,
  `reset_expire` timestamp NULL DEFAULT NULL,
  `user_status` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `water_irrigation_method`
--

DROP TABLE IF EXISTS `water_irrigation_method`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `water_irrigation_method` (
  `water_irrigation_id` int NOT NULL AUTO_INCREMENT,
  `water_irrigation_name` varchar(100) NOT NULL,
  PRIMARY KEY (`water_irrigation_id`),
  UNIQUE KEY `water_irrigation_name` (`water_irrigation_name`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `water_irrigation_planned`
--

DROP TABLE IF EXISTS `water_irrigation_planned`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `water_irrigation_planned` (
  `planned_id` int NOT NULL AUTO_INCREMENT,
  `farm_id` int NOT NULL,
  `land_id` int NOT NULL,
  `water_source_id` int DEFAULT NULL,
  `yield_id` int DEFAULT NULL COMMENT 'Cultura a regar (opcional)',
  `planned_date` date NOT NULL COMMENT 'Data prevista da rega',
  `planned_time` time DEFAULT NULL COMMENT 'Hora prevista (opcional)',
  `planned_duration_min` int DEFAULT NULL COMMENT 'Duração prevista em minutos',
  `planned_volume_liters` decimal(10,3) DEFAULT NULL COMMENT 'Volume previsto em litros',
  `irrigation_method` int DEFAULT NULL,
  `irrigation_status` int NOT NULL DEFAULT '0' COMMENT '0=planeada | 1=executada | 2=cancelada',
  `executed_at` timestamp NULL DEFAULT NULL COMMENT 'Preenchido quando executada',
  `water_usage_id` int DEFAULT NULL COMMENT 'FK para o registo real em water_usage_log',
  `planned_notes` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`planned_id`),
  KEY `fk_wip_farms_idx` (`farm_id`),
  KEY `fk_wip_lands_idx` (`land_id`),
  KEY `fk_wip_water_source_idx` (`water_source_id`),
  KEY `fk_wip_yields_idx` (`yield_id`),
  KEY `fk_wip_water_usage_idx` (`water_usage_id`),
  KEY `fk_wip_irrigation_method_idx` (`irrigation_method`),
  KEY `idx_planned_date` (`planned_date`),
  CONSTRAINT `fk_wip_farms1` FOREIGN KEY (`farm_id`) REFERENCES `farms` (`farm_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_wip_irrigation_method1` FOREIGN KEY (`irrigation_method`) REFERENCES `water_irrigation_method` (`water_irrigation_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_wip_lands1` FOREIGN KEY (`land_id`) REFERENCES `lands` (`land_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_wip_water_source1` FOREIGN KEY (`water_source_id`) REFERENCES `water_source` (`water_source_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_wip_water_usage1` FOREIGN KEY (`water_usage_id`) REFERENCES `water_usage_log` (`water_usage_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_wip_yields1` FOREIGN KEY (`yield_id`) REFERENCES `yields` (`yield_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `water_source`
--

DROP TABLE IF EXISTS `water_source`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `water_source` (
  `farm_id` int NOT NULL,
  `water_source_id` int NOT NULL AUTO_INCREMENT,
  `water_source_name` varchar(100) NOT NULL,
  `water_source_slug` varchar(100) NOT NULL,
  `water_type_id` int NOT NULL,
  `water_source_location_description` text,
  `water_source_latitude` decimal(9,6) DEFAULT NULL,
  `water_source_longitude` decimal(9,6) DEFAULT NULL,
  `water_source_depth_meters` decimal(6,3) DEFAULT NULL,
  `water_source_capacity` decimal(9,3) DEFAULT NULL,
  `water_source_notes` text,
  `water_source_ownership` tinyint(1) NOT NULL DEFAULT '1',
  `water_source_has_costs` tinyint(1) NOT NULL DEFAULT '0',
  `water_source_build_date` date DEFAULT NULL,
  `water_source_build_cost` decimal(9,2) DEFAULT NULL,
  `water_source_build_invoice` text NOT NULL,
  `water_source_status` int NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`water_source_id`),
  KEY `type_id` (`water_type_id`),
  KEY `farm_id` (`farm_id`),
  CONSTRAINT `water_source_ibfk_1` FOREIGN KEY (`water_type_id`) REFERENCES `water_source_type` (`water_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `water_source_type`
--

DROP TABLE IF EXISTS `water_source_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `water_source_type` (
  `water_type_id` int NOT NULL AUTO_INCREMENT,
  `water_type_name` varchar(50) NOT NULL,
  PRIMARY KEY (`water_type_id`),
  UNIQUE KEY `water_type_name` (`water_type_name`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `water_usage_log`
--

DROP TABLE IF EXISTS `water_usage_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `water_usage_log` (
  `water_usage_id` int NOT NULL AUTO_INCREMENT,
  `water_source_id` int NOT NULL,
  `land_id` int DEFAULT NULL,
  `water_usage_usage_date` date NOT NULL,
  `water_usage_volume_liters` decimal(10,3) NOT NULL,
  `water_usage_cost` decimal(9,2) DEFAULT NULL,
  `water_usage_method` int DEFAULT NULL,
  `water_usage_purpose` varchar(200) DEFAULT NULL,
  `water_usage_notes` text,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`water_usage_id`),
  KEY `water_source_id` (`water_source_id`),
  KEY `water_usage_method` (`water_usage_method`),
  CONSTRAINT `water_usage_log_ibfk_1` FOREIGN KEY (`water_source_id`) REFERENCES `water_source` (`water_source_id`),
  CONSTRAINT `water_usage_log_ibfk_2` FOREIGN KEY (`water_usage_method`) REFERENCES `water_irrigation_method` (`water_irrigation_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `yields`
--

DROP TABLE IF EXISTS `yields`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `yields` (
  `farm_id` int NOT NULL,
  `land_id` int NOT NULL,
  `yield_id` int NOT NULL AUTO_INCREMENT,
  `crop_id` int NOT NULL,
  `variety_id` int DEFAULT NULL,
  `yield_name` varchar(100) NOT NULL,
  `yield_slug` varchar(100) NOT NULL,
  `yield_method` varchar(100) NOT NULL,
  `yield_plant_numbers` int DEFAULT NULL,
  `yield_plant_beetween_rows` decimal(9,2) DEFAULT NULL,
  `yield_plant_in_rows` decimal(9,2) DEFAULT NULL,
  `yield_size` decimal(9,3) NOT NULL,
  `yield_notes` text,
  `yield_estimated` varchar(50) DEFAULT NULL,
  `yield_unit` varchar(75) DEFAULT NULL,
  `yield_status` int NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  `yield_production` decimal(9,3) DEFAULT NULL,
  `yield_graph` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`yield_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `yields_analysis`
--

DROP TABLE IF EXISTS `yields_analysis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `yields_analysis` (
  `yield_analysis_id` int NOT NULL AUTO_INCREMENT,
  `yield_analysis_date` date NOT NULL,
  `yield_analysis_sample` varchar(45) COLLATE utf8mb4_general_ci NOT NULL,
  `yield_analysis_file` text COLLATE utf8mb4_general_ci NOT NULL,
  `yield_analysis_nitrogen_total` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_phosphorus` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_potassium` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_calcium` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_magnesium` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_sulfur` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_iron` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_manganese` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_boro` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_cobre` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_zinc` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_molybdenum` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_sodium` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_analysis_aluminum` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  `yield_id` int NOT NULL,
  PRIMARY KEY (`yield_analysis_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `yields_analysis_default`
--

DROP TABLE IF EXISTS `yields_analysis_default`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `yields_analysis_default` (
  `yield_default_id` int NOT NULL AUTO_INCREMENT,
  `yield_id` int NOT NULL,
  `yield_default_nitrogen_total_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_nitrogen_total_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_phosphorus_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_phosphorus_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_potassium_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_potassium_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_calcium_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_calcium_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_magnesium_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_magnesium_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_sulfur_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_sulfur_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_iron_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_iron_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_manganese_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_manganese_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_boro_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_boro_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_cobre_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_cobre_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_zinc_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_zinc_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_molybdenum_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_molybdenum_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_sodium_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_sodium_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_aluminum_min` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `yield_default_aluminum_max` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`yield_default_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `yields_harvests`
--

DROP TABLE IF EXISTS `yields_harvests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `yields_harvests` (
  `warehouse_id` int DEFAULT NULL,
  `yield_id` int NOT NULL,
  `harvest_id` int NOT NULL AUTO_INCREMENT,
  `harvest_date` date NOT NULL,
  `harvest_name` varchar(150) NOT NULL,
  `harvest_harvested` decimal(9,3) NOT NULL,
  `unit_measurement` varchar(50) NOT NULL DEFAULT 'KG',
  `harvested_labor_count` int DEFAULT NULL,
  `harvested_labor_hours` decimal(9,2) DEFAULT NULL,
  `harvested_labor_hours_per_operator` decimal(9,2) DEFAULT NULL,
  `harvested_labor_total_cost` decimal(9,3) DEFAULT NULL,
  `harvest_kg_per_operator` decimal(9,3) DEFAULT NULL,
  `harvested_machine_count` int DEFAULT NULL,
  `harvested_machine_hours` decimal(9,2) DEFAULT NULL,
  `harvested_machine_cost` decimal(9,3) DEFAULT NULL,
  `total_harvest_cost` decimal(9,3) DEFAULT NULL,
  `harvest_cost_per_kg` decimal(9,3) DEFAULT NULL,
  `harvest_kg_per_hour` decimal(9,3) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` int NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` int DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` int DEFAULT NULL,
  PRIMARY KEY (`harvest_id`),
  KEY `warehouse_id` (`warehouse_id`),
  KEY `yield_id` (`yield_id`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-03-30 18:20:26
