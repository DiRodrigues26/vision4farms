CREATE TABLE `notification_preferences` (
  `pref_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `notify_activity` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1=ativo | 0=desativado',
  `notify_agenda` tinyint(1) NOT NULL DEFAULT '1',
  `notify_observation` tinyint(1) NOT NULL DEFAULT '1',
  `notify_irrigation` tinyint(1) NOT NULL DEFAULT '1',
  `notify_system` tinyint(1) NOT NULL DEFAULT '1',
  `reminder_hours` decimal(6,2) NOT NULL DEFAULT '24.00' COMMENT 'Horas antes do evento para enviar lembrete',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`pref_id`),
  UNIQUE KEY `uq_notification_preferences_user` (`user_id`),
  CONSTRAINT `fk_notification_preferences_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
