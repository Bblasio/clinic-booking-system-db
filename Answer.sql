
-- Create the database 
CREATE DATABASE clinic_booking_system
  DEFAULT CHARACTER SET = utf8mb4
  DEFAULT COLLATE = utf8mb4_general_ci;

USE clinic_booking_system;

-- Table for Patients
CREATE TABLE patients (
  patient_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  date_of_birth DATE NOT NULL,
  gender ENUM('Male', 'Female', 'Non-binary', 'Other', 'Prefer not to say') DEFAULT 'Prefer not to say',
  email VARCHAR(191) UNIQUE,
  phone VARCHAR(20) UNIQUE,
  address VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Table for Medical Records (One-to-One with Patients)
CREATE TABLE medical_records (
  patient_id INT UNSIGNED PRIMARY KEY, -- PK is also FK to patients
  blood_type ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') DEFAULT NULL,
  known_allergies TEXT,
  chronic_conditions TEXT,
  notes TEXT,
  last_reviewed DATE,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
    ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table for Clinics (Physical Locations)
CREATE TABLE clinics (
  clinic_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  address VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(191),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Table for Rooms (Rooms within Clinics)
CREATE TABLE rooms (
  room_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  clinic_id INT UNSIGNED NOT NULL,
  room_number VARCHAR(50) NOT NULL CHECK (room_number <> ''),
  room_type ENUM('Consultation','Lab','Surgery','Other') DEFAULT 'Consultation',
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  UNIQUE (clinic_id, room_number) -- Avoid duplicate room numbers per clinic
);

-- Table for Doctors
CREATE TABLE doctors (
  doctor_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  license_number VARCHAR(100) NOT NULL UNIQUE,
  email VARCHAR(191) UNIQUE,
  phone VARCHAR(20) UNIQUE,
  clinic_id INT UNSIGNED NOT NULL, -- Primary clinic affiliation
  hire_date DATE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Table for Specialties
CREATE TABLE specialties (
  specialty_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(255)
);

-- Junction Table: Doctors to Specialties (Many-to-Many)
CREATE TABLE doctor_specialties (
  doctor_id INT UNSIGNED NOT NULL,
  specialty_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (doctor_id, specialty_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (specialty_id) REFERENCES specialties(specialty_id)
    ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table for Schedules (Doctor Availability)
CREATE TABLE schedules (
  schedule_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT UNSIGNED NOT NULL,
  day_of_week ENUM('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday') NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_schedule_time CHECK (end_time > start_time),
  UNIQUE (doctor_id, day_of_week, start_time) -- Prevent duplicate schedules
);

-- Table for Services (e.g., Consultation, Vaccination)
CREATE TABLE services (
  service_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  description VARCHAR(255),
  base_price DECIMAL(10,2) NOT NULL CHECK (base_price >= 0),
  duration_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 30
);

-- Table for Appointments (Links Patients, Doctors, Clinics, Rooms)
CREATE TABLE appointments (
  appointment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,
  doctor_id INT UNSIGNED NOT NULL,
  clinic_id INT UNSIGNED NOT NULL,
  room_id INT UNSIGNED, -- Optional room assignment
  appointment_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  total_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (total_cost >= 0),
  status ENUM('Scheduled','Completed','Cancelled','No-Show') NOT NULL DEFAULT 'Scheduled',
  reason VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_time_positive CHECK (end_time > start_time),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (room_id) REFERENCES rooms(room_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_appointment_patient (patient_id),
  INDEX idx_appointment_doctor_date (doctor_id, appointment_date)
);

-- Junction Table: Appointments to Services (Many-to-Many)
CREATE TABLE appointment_services (
  appointment_id BIGINT UNSIGNED NOT NULL,
  service_id INT UNSIGNED NOT NULL,
  quantity SMALLINT UNSIGNED NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
  PRIMARY KEY (appointment_id, service_id),
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (service_id) REFERENCES services(service_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Table for Prescriptions (Issued During Appointments)
CREATE TABLE prescriptions (
  prescription_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appointment_id BIGINT UNSIGNED NOT NULL,
  medicine_name VARCHAR(150) NOT NULL,
  dosage VARCHAR(100) NOT NULL,
  duration_days INT UNSIGNED NOT NULL CHECK (duration_days > 0),
  notes TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table for Payments (Tracks Appointment Payments)
CREATE TABLE payments (
  payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  appointment_id BIGINT UNSIGNED NOT NULL,
  amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
  method ENUM('Cash','Card','Mobile Money','Insurance','Other') NOT NULL,
  paid_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reference VARCHAR(255),
  processed_by VARCHAR(150),
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_payment_appointment (appointment_id),
  INDEX idx_payment_date (paid_on)
);

-- View: Patient Appointments Summary
CREATE VIEW v_patient_appointments AS
SELECT p.patient_id, p.first_name, p.last_name,
       a.appointment_id, a.appointment_date, a.start_time, a.end_time, a.status,
       d.doctor_id, d.first_name AS doctor_first, d.last_name AS doctor_last,
       c.clinic_id, c.name AS clinic_name,
       r.room_id, r.room_number, r.room_type
FROM appointments a
JOIN patients p USING (patient_id)
JOIN doctors d USING (doctor_id)
JOIN clinics c USING (clinic_id)
LEFT JOIN rooms r USING (room_id);

-- Trigger: Prevent Overlapping Doctor Appointments (Insert)
DELIMITER $$
CREATE TRIGGER trg_check_doctor_overlap_insert
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
  SET @cnt = 0;
  SELECT COUNT(*)
    INTO @cnt
  FROM appointments
  WHERE doctor_id = NEW.doctor_id
    AND appointment_date = NEW.appointment_date
    AND NEW.start_time < end_time
    AND NEW.end_time > start_time;
  IF @cnt > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor has an overlapping appointment at this time';
  END IF;
  -- Check if appointment falls within doctor's schedule
  SET @cnt = 0;
  SELECT COUNT(*)
    INTO @cnt
  FROM schedules
  WHERE doctor_id = NEW.doctor_id
    AND day_of_week = DAYNAME(NEW.appointment_date)
    AND NEW.start_time >= start_time
    AND NEW.end_time <= end_time;
  IF @cnt = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment outside doctor''s schedule';
  END IF;
END$$

-- Trigger: Prevent Overlapping Doctor Appointments (Update)
CREATE TRIGGER trg_check_doctor_overlap_update
BEFORE UPDATE ON appointments
FOR EACH ROW
BEGIN
  SET @cnt = 0;
  SELECT COUNT(*)
    INTO @cnt
  FROM appointments
  WHERE doctor_id = NEW.doctor_id
    AND appointment_date = NEW.appointment_date
    AND appointment_id != OLD.appointment_id
    AND NEW.start_time < end_time
    AND NEW.end_time > start_time;
  IF @cnt > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor has an overlapping appointment at this time';
  END IF;
  -- Check if appointment falls within doctor's schedule
  SET @cnt = 0;
  SELECT COUNT(*)
    INTO @cnt
  FROM schedules
  WHERE doctor_id = NEW.doctor_id
    AND day_of_week = DAYNAME(NEW.appointment_date)
    AND NEW.start_time >= start_time
    AND NEW.end_time <= end_time;
  IF @cnt = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment outside doctor''s schedule';
  END IF;
END$$

-- Trigger: Prevent Overlapping Room Bookings (Insert)
CREATE TRIGGER trg_check_room_overlap_insert
BEFORE INSERT ON appointments
FOR EACH ROW
BEGIN
  SET @cnt = 0;
  IF NEW.room_id IS NOT NULL THEN
    SELECT COUNT(*)
      INTO @cnt
    FROM appointments
    WHERE room_id = NEW.room_id
      AND appointment_date = NEW.appointment_date
      AND NEW.start_time < end_time
      AND NEW.end_time > start_time;
    IF @cnt > 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room is booked at this time';
    END IF;
  END IF;
END$$

-- Trigger: Prevent Overlapping Room Bookings (Update)
CREATE TRIGGER trg_check_room_overlap_update
BEFORE UPDATE ON appointments
FOR EACH ROW
BEGIN
  SET @cnt = 0;
  IF NEW.room_id IS NOT NULL THEN
    SELECT COUNT(*)
      INTO @cnt
    FROM appointments
    WHERE room_id = NEW.room_id
      AND appointment_date = NEW.appointment_date
      AND appointment_id != OLD.appointment_id
      AND NEW.start_time < end_time
      AND NEW.end_time > start_time;
    IF @cnt > 0 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Room is booked at this time';
    END IF;
  END IF;
END$$

-- Trigger: Prevent Overpayment (Insert)
CREATE TRIGGER trg_check_payment_total_insert
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
  SET @total_paid = 0.00;
  SELECT SUM(amount) INTO @total_paid
  FROM payments
  WHERE appointment_id = NEW.appointment_id;
  
  SET @appt_cost = 0.00;
  SELECT total_cost INTO @appt_cost
  FROM appointments
  WHERE appointment_id = NEW.appointment_id;
  
  IF @total_paid > @appt_cost THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total payments exceed appointment cost';
  END IF;
END$$

-- Trigger: Prevent Overpayment (Update)
CREATE TRIGGER trg_check_payment_total_update
AFTER UPDATE ON payments
FOR EACH ROW
BEGIN
  SET @total_paid = 0.00;
  SELECT SUM(amount) INTO @total_paid
  FROM payments
  WHERE appointment_id = NEW.appointment_id;
  
  SET @appt_cost = 0.00;
  SELECT total_cost INTO @appt_cost
  FROM appointments
  WHERE appointment_id = NEW.appointment_id;
  
  IF @total_paid > @appt_cost THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Total payments exceed appointment cost';
  END IF;
END$$
