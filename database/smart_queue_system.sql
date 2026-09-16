-- Smart Queue System: initial schema for a NEW database.
-- Import this file using phpMyAdmin > Import, or paste it into the SQL tab.
-- Existing tables are not dropped or overwritten. This is not an upgrade script.
-- Uses MySQL/MariaDB InnoDB and utf8mb4.
CREATE DATABASE IF NOT EXISTS smart_queue_system
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE smart_queue_system;

CREATE TABLE roles (
  role_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role_name VARCHAR(50) NOT NULL,
  UNIQUE KEY uq_roles_name (role_name)
) ENGINE=InnoDB;

CREATE TABLE users (
  user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role_id INT UNSIGNED NOT NULL,
  user_identifier VARCHAR(50) NOT NULL,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL,
  password VARCHAR(255) NOT NULL COMMENT 'Laravel password hash, never plaintext',
  phone_no VARCHAR(20) NULL,
  status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
  remember_token VARCHAR(100) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_identifier (user_identifier),
  UNIQUE KEY uq_users_email (email),
  CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(role_id)
) ENGINE=InnoDB;

CREATE TABLE departments (
  department_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  department_name VARCHAR(100) NOT NULL,
  description VARCHAR(255) NULL,
  status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_departments_name (department_name)
) ENGINE=InnoDB;

CREATE TABLE rooms (
  room_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  department_id INT UNSIGNED NOT NULL,
  room_name VARCHAR(100) NOT NULL,
  status ENUM('available', 'unavailable', 'inactive') NOT NULL DEFAULT 'available',
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_room_department_name (department_id, room_name),
  CONSTRAINT fk_rooms_department FOREIGN KEY (department_id) REFERENCES departments(department_id)
) ENGINE=InnoDB;

CREATE TABLE appointments (
  appointment_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL COMMENT 'Patient',
  department_id INT UNSIGNED NOT NULL,
  doctor_id INT UNSIGNED NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  appointment_status ENUM('pending', 'confirmed', 'cancelled', 'completed', 'absent') NOT NULL DEFAULT 'pending',
  reason_for_visit VARCHAR(255) NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_appointments_schedule (department_id, appointment_date, appointment_status),
  KEY idx_appointments_doctor_time (doctor_id, appointment_date, appointment_time),
  CONSTRAINT fk_appointments_patient FOREIGN KEY (user_id) REFERENCES users(user_id),
  CONSTRAINT fk_appointments_department FOREIGN KEY (department_id) REFERENCES departments(department_id),
  CONSTRAINT fk_appointments_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE TABLE queues (
  queue_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL COMMENT 'Patient',
  department_id INT UNSIGNED NOT NULL,
  room_id INT UNSIGNED NULL,
  doctor_id INT UNSIGNED NULL,
  appointment_id INT UNSIGNED NULL,
  verified_by INT UNSIGNED NULL COMMENT 'Registration staff user',
  verified_at DATETIME NULL,
  queue_number VARCHAR(20) NOT NULL COMMENT 'Globally unique; include date e.g. 20260917-PH-001',
  queue_type ENUM('qr_walk_in', 'appointment') NOT NULL DEFAULT 'qr_walk_in',
  queue_status ENUM('waiting', 'verified', 'assigned', 'called', 'in_consultation', 'completed', 'skipped', 'absent', 'cancelled') NOT NULL DEFAULT 'waiting',
  reason_for_visit VARCHAR(255) NOT NULL,
  registered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  called_at DATETIME NULL,
  completed_at DATETIME NULL,
  estimated_waiting_time INT UNSIGNED NULL COMMENT 'Minutes; NULL means unknown',
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_queues_number (queue_number),
  UNIQUE KEY uq_queues_appointment (appointment_id),
  KEY idx_queues_department_status_time (department_id, queue_status, registered_at),
  KEY idx_queues_patient_status (user_id, queue_status),
  KEY idx_queues_doctor_status (doctor_id, queue_status),
  CONSTRAINT fk_queues_patient FOREIGN KEY (user_id) REFERENCES users(user_id),
  CONSTRAINT fk_queues_department FOREIGN KEY (department_id) REFERENCES departments(department_id),
  CONSTRAINT fk_queues_room FOREIGN KEY (room_id) REFERENCES rooms(room_id),
  CONSTRAINT fk_queues_doctor FOREIGN KEY (doctor_id) REFERENCES users(user_id),
  CONSTRAINT fk_queues_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id),
  CONSTRAINT fk_queues_verifier FOREIGN KEY (verified_by) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE TABLE consultations (
  consultation_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  queue_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL COMMENT 'Doctor',
  room_id INT UNSIGNED NOT NULL,
  consultation_status ENUM('called', 'in_consultation', 'completed', 'skipped', 'absent') NOT NULL DEFAULT 'called',
  started_at DATETIME NULL,
  ended_at DATETIME NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_consultations_queue (queue_id),
  CONSTRAINT fk_consultations_queue FOREIGN KEY (queue_id) REFERENCES queues(queue_id),
  CONSTRAINT fk_consultations_doctor FOREIGN KEY (user_id) REFERENCES users(user_id),
  CONSTRAINT fk_consultations_room FOREIGN KEY (room_id) REFERENCES rooms(room_id)
) ENGINE=InnoDB;

CREATE TABLE notifications (
  notification_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  queue_id INT UNSIGNED NULL,
  notification_title VARCHAR(100) NOT NULL,
  notification_message TEXT NOT NULL,
  notification_status ENUM('pending', 'sent', 'read', 'failed') NOT NULL DEFAULT 'pending',
  sent_at DATETIME NULL,
  read_at DATETIME NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_notifications_user_status (user_id, notification_status),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(user_id),
  CONSTRAINT fk_notifications_queue FOREIGN KEY (queue_id) REFERENCES queues(queue_id)
) ENGINE=InnoDB;

START TRANSACTION;
INSERT INTO roles (role_id, role_name) VALUES
  (1, 'patient'),
  (2, 'staff'),
  (3, 'doctor'),
  (4, 'administrator');

INSERT INTO departments (department_name, description) VALUES
  ('Dental Clinic', 'Dental services'),
  ('General Consultation', 'General consultation services'),
  ('Health Screening', 'Health screening services'),
  ('Pharmacy', 'Pharmacy services');
COMMIT;

-- No user accounts or room assignments are invented here.
-- Create accounts via Laravel using Hash::make() for passwords.
-- Laravel must enforce role permissions, doctor/room/department consistency,
-- valid status transitions, booking availability and one active queue per patient.
-- Allocate queue numbers and check booking/queue availability inside transactions.
-- Laravel models must declare their custom primary keys (e.g. user_id).
-- Queue/appointment/consultation status changes must be kept consistent by the API.

