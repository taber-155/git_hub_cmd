-- =============================================
-- Birth Health Network (BHN) Database Schema
-- PostgreSQL 15+ Compatible
-- =============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- =============================================
-- ENUMS
-- =============================================
CREATE TYPE user_type AS ENUM ('patient', 'doctor', 'nurse', 'admin', 'hospital_staff', 'provider');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'pending_verification');
CREATE TYPE gender AS ENUM ('male', 'female', 'other', 'prefer_not_to_say');
CREATE TYPE blood_type AS ENUM ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown');
CREATE TYPE appointment_status AS ENUM ('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show');
CREATE TYPE record_type AS ENUM ('vital_signs', 'lab_results', 'vaccination', 'prenatal', 'consultation', 'mental_health', 'physical_therapy', 'nutrition', 'birth_record', 'emergency');
CREATE TYPE urgency_level AS ENUM ('low', 'normal', 'high', 'urgent', 'critical');
CREATE TYPE document_type AS ENUM ('birth_certificate', 'medical_record', 'lab_result', 'prescription', 'insurance_card', 'id_document', 'consent_form', 'image', 'other');
CREATE TYPE notification_type AS ENUM ('appointment_reminder', 'test_result', 'prescription_refill', 'system_alert', 'birth_registration', 'document_upload');
CREATE TYPE birth_status AS ENUM ('pending', 'approved', 'rejected', 'requires_review');
CREATE TYPE session_status AS ENUM ('active', 'expired', 'revoked');

-- =============================================
-- CORE USER TABLES
-- =============================================

-- Users table (main authentication table)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  user_type user_type NOT NULL,
  status user_status DEFAULT 'pending_verification',
  email_verified BOOLEAN DEFAULT FALSE,
  email_verification_token VARCHAR(255),
  password_reset_token VARCHAR(255),
  password_reset_expires TIMESTAMP,
  last_login TIMESTAMP,
  login_attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMP,
  two_factor_enabled BOOLEAN DEFAULT FALSE,
  two_factor_secret VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User profiles table
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  middle_name VARCHAR(100),
  date_of_birth DATE,
  gender gender,
  phone VARCHAR(20),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(50),
  zip_code VARCHAR(20),
  country VARCHAR(100) DEFAULT 'Canada',
  emergency_contact_name VARCHAR(200),
  emergency_contact_phone VARCHAR(20),
  emergency_contact_relationship VARCHAR(100),
  profile_image_url TEXT,
  timezone VARCHAR(50) DEFAULT 'America/Toronto',
  language_preference VARCHAR(10) DEFAULT 'en',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Doctor-specific information
CREATE TABLE doctors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  license_number VARCHAR(50) UNIQUE NOT NULL,
  specialization VARCHAR(200) NOT NULL,
  sub_specialties TEXT[],
  years_of_experience INTEGER,
  education TEXT,
  certifications TEXT,
  bio TEXT,
  hospital_affiliations JSONB,
  office_hours JSONB,
  accepting_new_patients BOOLEAN DEFAULT TRUE,
  consultation_fee DECIMAL(10,2),
  languages_spoken TEXT[],
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Patient-specific information
CREATE TABLE patients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bhn_id VARCHAR(20) UNIQUE NOT NULL, -- Birth Health Network ID
  blood_type blood_type DEFAULT 'unknown',
  allergies TEXT,
  current_medications TEXT,
  medical_conditions TEXT,
  insurance_provider VARCHAR(200),
  insurance_number VARCHAR(100),
  insurance_group_number VARCHAR(100),
  primary_doctor_id UUID REFERENCES doctors(id),
  preferred_pharmacy TEXT,
  medical_history JSONB,
  family_history JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Healthcare facilities/organizations
CREATE TABLE healthcare_facilities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  facility_type VARCHAR(100),
  address TEXT NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(50) NOT NULL,
  zip_code VARCHAR(20) NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(255),
  website TEXT,
  emergency_services BOOLEAN DEFAULT FALSE,
  services_offered TEXT[],
  operating_hours JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- BIRTH REGISTRATION SYSTEM
-- =============================================

CREATE TABLE birth_registrations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bhn_id VARCHAR(20) UNIQUE NOT NULL,
  -- Child information
  child_first_name VARCHAR(100) NOT NULL,
  child_last_name VARCHAR(100) NOT NULL,
  child_middle_name VARCHAR(100),
  child_gender gender,
  birth_date DATE NOT NULL,
  birth_time TIME,
  birth_weight DECIMAL(5,2),
  birth_length DECIMAL(5,2),
  birth_location VARCHAR(255),
  birth_hospital_id UUID REFERENCES healthcare_facilities(id),
  -- Mother information
  mother_first_name VARCHAR(100) NOT NULL,
  mother_last_name VARCHAR(100) NOT NULL,
  mother_maiden_name VARCHAR(100),
  mother_date_of_birth DATE,
  mother_place_of_birth VARCHAR(255),
  mother_occupation VARCHAR(100),
  mother_address TEXT,
  -- Father information
  father_first_name VARCHAR(100),
  father_last_name VARCHAR(100),
  father_date_of_birth DATE,
  father_place_of_birth VARCHAR(255),
  father_occupation VARCHAR(100),
  father_address TEXT,
  -- Registration details
  registration_status birth_status DEFAULT 'pending',
  registered_by_user_id UUID NOT NULL REFERENCES users(id),
  reviewed_by_user_id UUID REFERENCES users(id),
  approval_date TIMESTAMP,
  rejection_reason TEXT,
  registration_number VARCHAR(50),
  -- Medical information
  delivery_type VARCHAR(100),
  complications TEXT,
  apgar_score_1min INTEGER CHECK (apgar_score_1min BETWEEN 0 AND 10),
  apgar_score_5min INTEGER CHECK (apgar_score_5min BETWEEN 0 AND 10),
  attending_physician_id UUID REFERENCES doctors(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- HEALTH RECORDS SYSTEM
-- =============================================

CREATE TABLE health_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id UUID REFERENCES doctors(id),
  facility_id UUID REFERENCES healthcare_facilities(id),
  record_type record_type NOT NULL,
  urgency_level urgency_level DEFAULT 'normal',
  title VARCHAR(255) NOT NULL,
  description TEXT,
  diagnosis TEXT,
  treatment_plan TEXT,
  notes TEXT,
  vital_signs JSONB,
  visit_date DATE NOT NULL,
  visit_time TIME,
  follow_up_date DATE,
  follow_up_instructions TEXT,
  record_status VARCHAR(50) DEFAULT 'active',
  is_confidential BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE medications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  prescribed_by_doctor_id UUID REFERENCES doctors(id),
  health_record_id UUID REFERENCES health_records(id),
  medication_name VARCHAR(255) NOT NULL,
  dosage VARCHAR(100) NOT NULL,
  frequency VARCHAR(100) NOT NULL,
  duration VARCHAR(100),
  instructions TEXT,
  side_effects TEXT,
  start_date DATE NOT NULL,
  end_date DATE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE lab_results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  health_record_id UUID REFERENCES health_records(id),
  ordered_by_doctor_id UUID REFERENCES doctors(id),
  test_name VARCHAR(255) NOT NULL,
  test_type VARCHAR(100),
  test_date DATE NOT NULL,
  results JSONB NOT NULL,
  reference_ranges JSONB,
  status VARCHAR(50) DEFAULT 'completed',
  lab_facility VARCHAR(255),
  technician_notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- APPOINTMENTS SYSTEM
-- =============================================

CREATE TABLE appointments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  doctor_id UUID NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
  facility_id UUID REFERENCES healthcare_facilities(id),
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  duration_minutes INTEGER DEFAULT 30,
  appointment_type VARCHAR(100),
  reason TEXT,
  status appointment_status DEFAULT 'scheduled',
  chief_complaint TEXT,
  visit_notes TEXT,
  prescription_notes TEXT,
  next_appointment_recommended BOOLEAN DEFAULT FALSE,
  scheduled_by_user_id UUID REFERENCES users(id),
  confirmed_at TIMESTAMP,
  cancelled_at TIMESTAMP,
  cancellation_reason TEXT,
  fee_amount DECIMAL(10,2),
  payment_status VARCHAR(50) DEFAULT 'pending',
  insurance_claim_number VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- DOCUMENT MANAGEMENT
-- =============================================

CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  uploaded_by_user_id UUID NOT NULL REFERENCES users(id),
  patient_id UUID REFERENCES patients(id),
  health_record_id UUID REFERENCES health_records(id),
  birth_registration_id UUID REFERENCES birth_registrations(id),
  filename VARCHAR(255) NOT NULL,
  original_filename VARCHAR(255) NOT NULL,
  file_path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  document_type document_type NOT NULL,
  title VARCHAR(255),
  description TEXT,
  is_encrypted BOOLEAN DEFAULT TRUE,
  encryption_key_id VARCHAR(255),
  s3_bucket VARCHAR(100),
  s3_key TEXT,
  s3_version_id VARCHAR(100),
  is_public BOOLEAN DEFAULT FALSE,
  access_level VARCHAR(50) DEFAULT 'private',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- COMMUNICATION & NOTIFICATIONS
-- =============================================

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_type notification_type NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  action_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP,
  related_appointment_id UUID REFERENCES appointments(id),
  related_health_record_id UUID REFERENCES health_records(id),
  related_birth_registration_id UUID REFERENCES birth_registrations(id),
  email_sent BOOLEAN DEFAULT FALSE,
  sms_sent BOOLEAN DEFAULT FALSE,
  push_sent BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- SECURITY & AUDIT
-- =============================================

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  action VARCHAR(100) NOT NULL,
  resource_type VARCHAR(100) NOT NULL,
  resource_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  success BOOLEAN DEFAULT TRUE,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_token VARCHAR(255) UNIQUE NOT NULL,
  refresh_token VARCHAR(255) UNIQUE,
  device_info JSONB,
  ip_address INET,
  user_agent TEXT,
  status session_status DEFAULT 'active',
  expires_at TIMESTAMP NOT NULL,
  last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- SYSTEM CONFIGURATION
-- =============================================

CREATE TABLE system_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  setting_key VARCHAR(100) UNIQUE NOT NULL,
  setting_value TEXT,
  setting_type VARCHAR(50) DEFAULT 'string',
  description TEXT,
  is_public BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- User and authentication indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_type ON users(user_type);
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_profiles_name ON user_profiles(first_name, last_name);

-- Patient indexes
CREATE INDEX idx_patients_user_id ON patients(user_id);
CREATE INDEX idx_patients_bhn_id ON patients(bhn_id);
CREATE INDEX idx_patients_primary_doctor ON patients(primary_doctor_id);

-- Doctor indexes
CREATE INDEX idx_doctors_user_id ON doctors(user_id);
CREATE INDEX idx_doctors_license ON doctors(license_number);
CREATE INDEX idx_doctors_specialization ON doctors(specialization);

-- Birth registration indexes
CREATE INDEX idx_birth_registrations_bhn_id ON birth_registrations(bhn_id);
CREATE INDEX idx_birth_registrations_status ON birth_registrations(registration_status);
CREATE INDEX idx_birth_registrations_date ON birth_registrations(birth_date);
CREATE INDEX idx_birth_registrations_hospital ON birth_registrations(birth_hospital_id);

-- Health records indexes
CREATE INDEX idx_health_records_patient ON health_records(patient_id);
CREATE INDEX idx_health_records_doctor ON health_records(doctor_id);
CREATE INDEX idx_health_records_date ON health_records(visit_date);
CREATE INDEX idx_health_records_type ON health_records(record_type);
CREATE INDEX idx_health_records_urgency ON health_records(urgency_level);

-- Appointment indexes
CREATE INDEX idx_appointments_patient ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor ON appointments(doctor_id);
CREATE INDEX idx_appointments_date ON appointments(appointment_date);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_appointments_datetime ON appointments(appointment_date, appointment_time);

-- Document indexes
CREATE INDEX idx_documents_patient ON documents(patient_id);
CREATE INDEX idx_documents_type ON documents(document_type);
CREATE INDEX idx_documents_uploaded_by ON documents(uploaded_by_user_id);

-- Notification indexes
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(notification_type);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- Audit and security indexes
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(created_at);

CREATE INDEX idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_status ON user_sessions(status);

-- Text search indexes
CREATE INDEX idx_user_profiles_search ON user_profiles USING gin(to_tsvector('english', first_name || ' ' || last_name));
CREATE INDEX idx_health_records_search ON health_records USING gin(to_tsvector('english', title || ' ' || description));

-- =============================================
-- TRIGGERS FOR UPDATED_AT
-- =============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to all tables with updated_at column
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON patients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_doctors_updated_at BEFORE UPDATE ON doctors FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_healthcare_facilities_updated_at BEFORE UPDATE ON healthcare_facilities FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_birth_registrations_updated_at BEFORE UPDATE ON birth_registrations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_health_records_updated_at BEFORE UPDATE ON health_records FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_medications_updated_at BEFORE UPDATE ON medications FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_lab_results_updated_at BEFORE UPDATE ON lab_results FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_appointments_updated_at BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_documents_updated_at BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_notifications_updated_at BEFORE UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- INITIAL DATA SETUP
-- =============================================

-- Insert default system settings
INSERT INTO system_settings (setting_key, setting_value, setting_type, description, is_public) VALUES
('app_name', 'Birth Health Network', 'string', 'Application name', true),
('app_version', '1.0.0', 'string', 'Current application version', true),
('maintenance_mode', 'false', 'boolean', 'System maintenance mode flag', false),
('max_file_upload_size', '10485760', 'integer', 'Maximum file upload size in bytes (10MB)', false),
('session_timeout_minutes', '120', 'integer', 'User session timeout in minutes', false),
('password_min_length', '8', 'integer', 'Minimum password length requirement', false),
('email_verification_required', 'true', 'boolean', 'Whether email verification is required', false),
('two_factor_auth_enabled', 'true', 'boolean', 'Whether 2FA is enabled system-wide', false);

-- =============================================
-- SECURITY POLICIES (Row Level Security)
-- =============================================

-- Enable RLS on sensitive tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

-- Function to get current user ID (to be implemented based on authentication system)
CREATE OR REPLACE FUNCTION current_user_id() RETURNS UUID AS $$
BEGIN
  -- This should return the current authenticated user's ID
  -- Implementation depends on your authentication system
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is admin
CREATE OR REPLACE FUNCTION is_admin() RETURNS BOOLEAN AS $$
BEGIN
  -- Implementation to check if current user has admin role
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is healthcare provider
CREATE OR REPLACE FUNCTION is_healthcare_provider() RETURNS BOOLEAN AS $$
BEGIN
  -- Implementation to check if current user is a healthcare provider
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- TEST DATA FOR DEVELOPMENT
-- =============================================

-- Insert test admin user
INSERT INTO users (email, password_hash, user_type, status, email_verified)
VALUES ('admin@bhn.ca', '$2b$12$dummyhash', 'admin', 'active', true);

-- Insert test healthcare facility
INSERT INTO healthcare_facilities (name, facility_type, address, city, state, zip_code, phone)
VALUES ('Central General Hospital', 'Hospital', '100 Health Ave', 'Toronto', 'ON', 'M1A 1A1', '+1-416-555-1000');

-- =============================================
-- END OF SCHEMA
-- =============================================
