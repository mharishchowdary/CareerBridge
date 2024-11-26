/*
Career Training System - Complete Database Script
==============================================
Organization:
1. Database Creation
2. Domains
3. Tables
4. Indexes
5. Views
6. Roles and Permissions
7. Assertions
8. Cursors
9. Functions
10. Triggers
11. Sample Data
*/

-- 1. Database Creation
CREATE DATABASE career_training_system;
\c career_training_system;

-- 2. Domains
CREATE DOMAIN enrollment_status AS VARCHAR(20) CHECK (VALUE IN ('Active', 'Completed', 'Dropped'));
CREATE DOMAIN interview_type AS VARCHAR(20) CHECK (VALUE IN ('Technical', 'HR', 'Management'));
CREATE DOMAIN interview_result AS VARCHAR(20) CHECK (VALUE IN ('Passed', 'Failed', 'Pending'));
CREATE DOMAIN placement_status AS VARCHAR(20) CHECK (VALUE IN ('Offered', 'Accepted', 'Rejected'));
CREATE DOMAIN application_status AS VARCHAR(20) CHECK (VALUE IN ('Applied', 'Interviewed', 'Offered', 'Rejected'));

-- 3. Tables
-- TRAINER table
CREATE TABLE TRAINER (
    trainer_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    specialization VARCHAR(100)
);

-- COURSE table
CREATE TABLE COURSE (
    course_id SERIAL PRIMARY KEY,
    trainer_id INT REFERENCES TRAINER(trainer_id) ON DELETE CASCADE ON UPDATE CASCADE,
    title VARCHAR(100) NOT NULL,
    description TEXT
);

-- STUDENT table
CREATE TABLE STUDENT (
    student_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    gpa NUMERIC(3, 2) CHECK (gpa BETWEEN 0 AND 4)
);

-- COMPANY table
CREATE TABLE COMPANY (
    company_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    industry VARCHAR(100)
);

-- ENROLLMENT table
CREATE TABLE ENROLLMENT (
    enrollment_id SERIAL PRIMARY KEY,
    course_id INT REFERENCES COURSE(course_id) ON DELETE CASCADE ON UPDATE CASCADE,
    student_id INT REFERENCES STUDENT(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
    status enrollment_status DEFAULT 'Active'
);

-- INTERVIEW table
CREATE TABLE INTERVIEW (
    interview_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES STUDENT(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
    company_id INT REFERENCES COMPANY(company_id) ON DELETE CASCADE ON UPDATE CASCADE,
    interview_date DATE,
    type interview_type,
    result interview_result DEFAULT 'Pending'
);

-- PLACEMENT table
CREATE TABLE PLACEMENT (
    placement_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES STUDENT(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
    company_id INT REFERENCES COMPANY(company_id) ON DELETE CASCADE ON UPDATE CASCADE,
    offer_date DATE,
    package NUMERIC(10, 2),
    status placement_status DEFAULT 'Offered'
);

-- JOB_POSTING table
CREATE TABLE JOB_POSTING (
    job_id SERIAL PRIMARY KEY,
    company_id INT REFERENCES COMPANY(company_id) ON DELETE CASCADE ON UPDATE CASCADE,
    title VARCHAR(100),
    description TEXT,
    posting_date DATE DEFAULT CURRENT_DATE
);

-- APPLICATION table
CREATE TABLE APPLICATION (
    application_id SERIAL PRIMARY KEY,
    job_id INT REFERENCES JOB_POSTING(job_id) ON DELETE CASCADE ON UPDATE CASCADE,
    student_id INT REFERENCES STUDENT(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
    apply_date DATE DEFAULT CURRENT_DATE,
    status application_status DEFAULT 'Applied'
);

-- SKILL table
CREATE TABLE SKILL (
    skill_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(100)
);

-- STUDENT_SKILL table
CREATE TABLE STUDENT_SKILL (
    student_id INT REFERENCES STUDENT(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
    skill_id INT REFERENCES SKILL(skill_id) ON DELETE CASCADE ON UPDATE CASCADE,
    proficiency INT CHECK (proficiency BETWEEN 1 AND 10),
    PRIMARY KEY (student_id, skill_id)
);

-- JOB_SKILL table
CREATE TABLE JOB_SKILL (
    job_id INT REFERENCES JOB_POSTING(job_id) ON DELETE CASCADE ON UPDATE CASCADE,
    skill_id INT REFERENCES SKILL(skill_id) ON DELETE CASCADE ON UPDATE CASCADE,
    importance INT CHECK (importance BETWEEN 1 AND 10),
    PRIMARY KEY (job_id, skill_id)
);

-- 4. Indexes
CREATE INDEX idx_student_email ON STUDENT(email);
CREATE INDEX idx_course_trainer ON COURSE(trainer_id);
CREATE INDEX idx_enrollment_course ON ENROLLMENT(course_id);
CREATE INDEX idx_enrollment_student ON ENROLLMENT(student_id);
CREATE INDEX idx_interview_student ON INTERVIEW(student_id);
CREATE INDEX idx_interview_company ON INTERVIEW(company_id);
CREATE INDEX idx_placement_student ON PLACEMENT(student_id);
CREATE INDEX idx_placement_company ON PLACEMENT(company_id);
CREATE INDEX idx_job_company ON JOB_POSTING(company_id);
CREATE INDEX idx_application_job ON APPLICATION(job_id);
CREATE INDEX idx_application_student ON APPLICATION(student_id);

-- 5. Views
-- Student course summary
CREATE VIEW student_course_summary AS
SELECT 
    s.student_id,
    s.name as student_name,
    COUNT(DISTINCT e.course_id) as total_courses,
    COUNT(DISTINCT CASE WHEN e.status = 'Completed' THEN e.course_id END) as completed_courses
FROM STUDENT s
LEFT JOIN ENROLLMENT e ON s.student_id = e.student_id
GROUP BY s.student_id, s.name;

-- Company hiring summary
CREATE VIEW company_hiring_summary AS
SELECT 
    c.company_id,
    c.name as company_name,
    COUNT(DISTINCT j.job_id) as total_job_postings,
    COUNT(DISTINCT p.placement_id) as total_placements
FROM COMPANY c
LEFT JOIN JOB_POSTING j ON c.company_id = j.company_id
LEFT JOIN PLACEMENT p ON c.company_id = p.company_id
GROUP BY c.company_id, c.name;

-- Student skill summary
CREATE VIEW student_skill_summary AS
SELECT 
    s.student_id,
    s.name as student_name,
    string_agg(sk.name, ', ') as skills,
    ROUND(AVG(ss.proficiency), 2) as avg_proficiency
FROM STUDENT s
LEFT JOIN STUDENT_SKILL ss ON s.student_id = ss.student_id
LEFT JOIN SKILL sk ON ss.skill_id = sk.skill_id
GROUP BY s.student_id, s.name;

-- Job skill match
CREATE VIEW job_skill_match AS
SELECT 
    j.job_id,
    j.title as job_title,
    s.student_id,
    s.name as student_name,
    COUNT(DISTINCT js.skill_id) as required_skills,
    COUNT(DISTINCT ss.skill_id) as matching_skills,
    ROUND(COUNT(DISTINCT ss.skill_id)::DECIMAL / COUNT(DISTINCT js.skill_id) * 100, 2) as match_percentage
FROM JOB_POSTING j
CROSS JOIN STUDENT s
LEFT JOIN JOB_SKILL js ON j.job_id = js.job_id
LEFT JOIN STUDENT_SKILL ss ON s.student_id = ss.student_id AND js.skill_id = ss.skill_id
GROUP BY j.job_id, j.title, s.student_id, s.name;

-- Student placement statistics
CREATE VIEW student_placement_stats AS
SELECT 
    s.student_id,
    s.name,
    s.gpa,
    COUNT(DISTINCT a.application_id) as total_applications,
    COUNT(DISTINCT CASE WHEN a.status = 'Offered' THEN a.application_id END) as offers_received,
    COUNT(DISTINCT CASE WHEN p.status = 'Accepted' THEN p.placement_id END) as placements_accepted,
    MAX(p.package) as highest_package
FROM STUDENT s
LEFT JOIN APPLICATION a ON s.student_id = a.student_id
LEFT JOIN PLACEMENT p ON s.student_id = p.student_id
GROUP BY s.student_id, s.name, s.gpa;

-- Company recruitment analytics
CREATE VIEW company_recruitment_analytics AS
SELECT 
    c.company_id,
    c.name as company_name,
    COUNT(DISTINCT j.job_id) as total_positions,
    COUNT(DISTINCT a.application_id) as total_applications,
    COUNT(DISTINCT i.interview_id) as total_interviews,
    COUNT(DISTINCT CASE WHEN i.result = 'Passed' THEN i.interview_id END) as successful_interviews,
    COUNT(DISTINCT CASE WHEN p.status = 'Accepted' THEN p.placement_id END) as successful_placements,
    ROUND(AVG(p.package), 2) as avg_package_offered
FROM COMPANY c
LEFT JOIN JOB_POSTING j ON c.company_id = j.company_id
LEFT JOIN APPLICATION a ON j.job_id = a.job_id
LEFT JOIN INTERVIEW i ON c.company_id = i.company_id
LEFT JOIN PLACEMENT p ON c.company_id = p.company_id
GROUP BY c.company_id, c.name;

-- 6. Roles and Permissions
CREATE ROLE admin_role;
CREATE ROLE trainer_role;
CREATE ROLE student_role;
CREATE ROLE company_role;

-- Grant permissions to admin_role
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO admin_role;

-- Grant permissions to trainer_role
GRANT SELECT, INSERT, UPDATE ON 
    COURSE, ENROLLMENT, STUDENT_SKILL 
TO trainer_role;
GRANT SELECT ON 
    STUDENT, SKILL, STUDENT_COURSE_SUMMARY, STUDENT_SKILL_SUMMARY 
TO trainer_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO trainer_role;

-- Grant permissions to student_role
GRANT SELECT, INSERT, UPDATE ON 
    APPLICATION, STUDENT_SKILL 
TO student_role;
GRANT SELECT ON 
    COURSE, JOB_POSTING, COMPANY, SKILL, 
    STUDENT_COURSE_SUMMARY, STUDENT_SKILL_SUMMARY 
TO student_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO student_role;

-- Grant permissions to company_role
GRANT SELECT, INSERT, UPDATE ON 
    JOB_POSTING, JOB_SKILL, INTERVIEW, PLACEMENT 
TO company_role;
GRANT SELECT ON 
    STUDENT, SKILL, COMPANY_HIRING_SUMMARY, STUDENT_SKILL_SUMMARY 
TO company_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO company_role;

-- -- 7. Assertions
-- -- Maximum active enrollments per student
-- CREATE ASSERTION max_active_enrollments CHECK (
--     NOT EXISTS (
--         SELECT student_id 
--         FROM ENROLLMENT 
--         WHERE status = 'Active' 
--         GROUP BY student_id 
--         HAVING COUNT(*) > 5
--     )
-- );
-- 
-- -- Valid interview date
-- CREATE ASSERTION valid_interview_date CHECK (
--     NOT EXISTS (
--         SELECT 1 
--         FROM INTERVIEW 
--         WHERE interview_date < CURRENT_DATE
--     )
-- );
-- 
-- -- Minimum placement package
-- CREATE ASSERTION minimum_package CHECK (
--     NOT EXISTS (
--         SELECT 1 
--         FROM PLACEMENT 
--         WHERE package < 35000.00
--     )
-- );

-- 8. Cursors
-- Process pending interviews
CREATE OR REPLACE FUNCTION process_pending_interviews()
RETURNS void AS $$
DECLARE
    interview_cursor CURSOR FOR 
        SELECT i.interview_id, i.student_id, i.company_id, i.interview_date
        FROM INTERVIEW i
        WHERE i.result = 'Pending'
        AND i.interview_date <= CURRENT_DATE
        ORDER BY i.interview_date;
    
    interview_record RECORD;
BEGIN
    OPEN interview_cursor;
    
    LOOP
        FETCH interview_cursor INTO interview_record;
        EXIT WHEN NOT FOUND;
        
        -- Process each pending interview
        RAISE NOTICE 'Processing interview ID: %, Student: %, Company: %',
            interview_record.interview_id,
            interview_record.student_id,
            interview_record.company_id;
    END LOOP;
    
    CLOSE interview_cursor;
END;
$$ LANGUAGE plpgsql;

-- Archive old job postings
CREATE OR REPLACE FUNCTION archive_old_job_postings()
RETURNS void AS $$
DECLARE
    job_cursor CURSOR FOR 
        SELECT job_id, title, posting_date
        FROM JOB_POSTING
        WHERE posting_date < (CURRENT_DATE - INTERVAL '30 days')
        FOR UPDATE;
    
    job_record RECORD;
BEGIN
    OPEN job_cursor;
    
    LOOP
        FETCH job_cursor INTO job_record;
        EXIT WHEN NOT FOUND;
        
        -- Archive old job postings
        RAISE NOTICE 'Archiving job ID: %, Title: %, Posted: %',
            job_record.job_id,
            job_record.title,
            job_record.posting_date;
    END LOOP;
    
    CLOSE job_cursor;
END;
$$ LANGUAGE plpgsql;

-- 9. Functions
-- Get student skills
CREATE OR REPLACE FUNCTION get_student_skills(p_student_id INT)
RETURNS TABLE (
    skill_name VARCHAR(100),
    category VARCHAR(100),
    proficiency INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sk.name,
        sk.category,
        ss.proficiency
    FROM STUDENT_SKILL ss
    JOIN SKILL sk ON ss.skill_id = sk.skill_id
    WHERE ss.student_id = p_student_id;
END;
$$ LANGUAGE plpgsql;

-- Get job matches for student
CREATE OR REPLACE FUNCTION get_student_job_matches(p_student_id INT)
RETURNS TABLE (
    job_title VARCHAR(100),
    company_name VARCHAR(100),
    match_percentage NUMERIC,
    required_skills TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        j.title,
        c.name,
        ROUND(COUNT(DISTINCT ss.skill_id)::DECIMAL / NULLIF(COUNT(DISTINCT js.skill_id), 0) * 100, 2),
        string_agg(DISTINCT sk.name, ', ')
    FROM JOB_POSTING j
    JOIN COMPANY c ON j.company_id = c.company_id
    LEFT JOIN JOB_SKILL js ON j.job_id = js.job_id
    LEFT JOIN SKILL sk ON js.skill_id = sk.skill_id
    LEFT JOIN STUDENT_SKILL ss ON js.skill_id = ss.skill_id AND ss.student_id = p_student_id
    GROUP BY j.job_id, j.title, c.name;
END;
$$ LANGUAGE plpgsql;

-- 10. Triggers
-- Update application status on interview
CREATE OR REPLACE FUNCTION update_application_status()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE APPLICATION
    SET status = 'Interviewed'
    WHERE student_id = NEW.student_id
    AND job_id IN (
        SELECT job_id 
        FROM JOB_POSTING 
        WHERE company_id = NEW.company_id
    )
    AND status = 'Applied';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER interview_status_trigger
AFTER INSERT ON INTERVIEW
FOR EACH ROW
EXECUTE FUNCTION update_application_status();


-- Step 11: Insert Sample Data

-- Insert Trainers
INSERT INTO TRAINER (name, specialization) VALUES
('John Smith', 'Web Development'),
('Maria Garcia', 'Data Science'),
('James Wilson', 'Cloud Computing'),
('Sarah Johnson', 'Mobile Development'),
('Michael Brown', 'Artificial Intelligence'),
('Lisa Chen', 'Cybersecurity'),
('David Kim', 'DevOps'),
('Emma Davis', 'UI/UX Design'),
('Robert Taylor', 'Blockchain'),
('Anna Martinez', 'Business Intelligence');

-- Insert Courses
INSERT INTO COURSE (trainer_id, title, description) VALUES
(1, 'Full Stack Web Development', 'Comprehensive web development course'),
(2, 'Python for Data Science', 'Data analysis and machine learning'),
(3, 'AWS Cloud Fundamentals', 'Cloud computing basics'),
(4, 'iOS App Development', 'Mobile app development for Apple devices'),
(5, 'Machine Learning Basics', 'Introduction to AI and ML concepts'),
(6, 'Network Security', 'Fundamentals of cybersecurity'),
(7, 'DevOps Engineering', 'CI/CD and automation'),
(8, 'User Experience Design', 'Principles of UX design'),
(9, 'Blockchain Development', 'Smart contracts and DApps'),
(10, 'Data Visualization', 'Creating effective data presentations');

-- Insert Students
INSERT INTO STUDENT (name, email, gpa) VALUES
('Alice Cooper', 'alice@email.com', 3.8),
('Bob Wilson', 'bob@email.com', 3.5),
('Charlie Brown', 'charlie@email.com', 3.9),
('Diana Prince', 'diana@email.com', 3.7),
('Edward Smith', 'edward@email.com', 3.6),
('Frank Miller', 'frank@email.com', 3.4),
('Grace Lee', 'grace@email.com', 3.9),
('Henry Ford', 'henry@email.com', 3.2),
('Iris West', 'iris@email.com', 3.8),
('Jack Ryan', 'jack@email.com', 3.5),
('Karen Chen', 'karen@email.com', 3.7),
('Leo Wong', 'leo@email.com', 3.6);

-- Insert Companies
INSERT INTO COMPANY (name, industry) VALUES
('TechCorp', 'Software Development'),
('DataMinds', 'Data Analytics'),
('CloudTech', 'Cloud Services'),
('MobileFirst', 'Mobile Applications'),
('AILabs', 'Artificial Intelligence'),
('CyberGuard', 'Cybersecurity'),
('DevOpsFlow', 'DevOps Services'),
('DesignMaster', 'Design Services'),
('BlockChain Solutions', 'Blockchain'),
('DataViz', 'Business Intelligence');

-- Insert Skills
INSERT INTO SKILL (name, category) VALUES
('JavaScript', 'Programming'),
('Python', 'Programming'),
('AWS', 'Cloud'),
('Swift', 'Programming'),
('Machine Learning', 'AI'),
('SQL', 'Database'),
('React', 'Web Development'),
('Docker', 'DevOps'),
('Git', 'Version Control'),
('Agile', 'Methodology'),
('Cybersecurity', 'Security'),
('UI Design', 'Design');

-- Insert Enrollments
INSERT INTO ENROLLMENT (course_id, student_id, status) VALUES
(1, 1, 'Active'),
(2, 1, 'Active'),
(1, 2, 'Completed'),
(3, 3, 'Active'),
(4, 4, 'Active'),
(5, 5, 'Completed'),
(2, 6, 'Active'),
(3, 7, 'Active'),
(4, 8, 'Dropped'),
(5, 9, 'Active'),
(6, 10, 'Active'),
(7, 11, 'Completed'),
(8, 12, 'Active');

-- Insert Job Postings
INSERT INTO JOB_POSTING (company_id, title, description) VALUES
(1, 'Full Stack Developer', 'Looking for a full stack developer'),
(2, 'Data Scientist', 'Experience with Python and ML required'),
(3, 'Cloud Engineer', 'AWS certification preferred'),
(4, 'iOS Developer', 'Swift experience required'),
(5, 'ML Engineer', 'AI/ML background needed'),
(6, 'Security Engineer', 'Cybersecurity expertise required'),
(7, 'DevOps Engineer', 'Experience with CI/CD'),
(8, 'UX Designer', 'Portfolio required'),
(9, 'Blockchain Developer', 'Smart contract experience'),
(10, 'Data Analyst', 'SQL and visualization skills');

-- Insert Student Skills
INSERT INTO STUDENT_SKILL (student_id, skill_id, proficiency) VALUES
(1, 1, 8),
(1, 2, 7),
(2, 3, 9),
(3, 4, 8),
(4, 5, 7),
(5, 1, 6),
(6, 2, 8),
(7, 3, 7),
(8, 4, 9),
(9, 5, 8),
(10, 6, 7),
(11, 7, 8),
(12, 8, 9);

-- Insert Job Skills
INSERT INTO JOB_SKILL (job_id, skill_id, importance) VALUES
(1, 1, 9),
(1, 7, 8),
(2, 2, 9),
(2, 5, 8),
(3, 3, 9),
(3, 8, 7),
(4, 4, 9),
(5, 5, 9),
(5, 2, 8),
(6, 11, 9),
(7, 8, 9),
(8, 12, 8),
(9, 1, 7),
(10, 6, 9);

-- Insert Applications
INSERT INTO APPLICATION (job_id, student_id, status) VALUES
(1, 1, 'Applied'),
(2, 2, 'Interviewed'),
(3, 3, 'Applied'),
(4, 4, 'Offered'),
(5, 5, 'Rejected'),
(6, 6, 'Applied'),
(7, 7, 'Interviewed'),
(8, 8, 'Offered'),
(9, 9, 'Applied'),
(10, 10, 'Rejected');

-- Insert Interviews
INSERT INTO INTERVIEW (student_id, company_id, interview_date, type, result) VALUES
(1, 1, '2024-03-15', 'Technical', 'Pending'),
(2, 2, '2024-03-14', 'HR', 'Passed'),
(3, 3, '2024-03-13', 'Technical', 'Failed'),
(4, 4, '2024-03-12', 'Management', 'Passed'),
(5, 5, '2024-03-11', 'Technical', 'Failed'),
(6, 6, '2024-03-10', 'HR', 'Passed'),
(7, 7, '2024-03-09', 'Technical', 'Pending'),
(8, 8, '2024-03-08', 'Management', 'Passed'),
(9, 9, '2024-03-07', 'Technical', 'Failed'),
(10, 10, '2024-03-06', 'HR', 'Passed');

-- Insert Placements
INSERT INTO PLACEMENT (student_id, company_id, offer_date, package, status) VALUES
(1, 1, '2024-03-20', 85000.00, 'Offered'),
(2, 2, '2024-03-19', 90000.00, 'Accepted'),
(4, 4, '2024-03-18', 95000.00, 'Offered'),
(6, 5, '2024-03-17', 88000.00, 'Rejected'),
(8, 3, '2024-03-16', 92000.00, 'Accepted'),
(3, 6, '2024-03-15', 87000.00, 'Offered'),
(5, 7, '2024-03-14', 93000.00, 'Accepted'),
(7, 8, '2024-03-13', 89000.00, 'Rejected'),
(9, 9, '2024-03-12', 91000.00, 'Offered'),
(10, 10, '2024-03-11', 86000.00, 'Accepted');





-- Step 12: Password Encryption

ALTER TABLE STUDENT 
ADD COLUMN password_hash VARCHAR(255),
ADD COLUMN password_salt VARCHAR(255);

ALTER TABLE TRAINER 
ADD COLUMN password_hash VARCHAR(255),
ADD COLUMN password_salt VARCHAR(255);

ALTER TABLE COMPANY 
ADD COLUMN password_hash VARCHAR(255),
ADD COLUMN password_salt VARCHAR(255);




-- New Triggers


CREATE OR REPLACE FUNCTION assign_default_skills()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert default skills for the new student
    INSERT INTO STUDENT_SKILL (student_id, skill_id, proficiency)
    SELECT NEW.student_id, skill_id, NEW.gpa * 2.5  -- Default proficiency
    FROM SKILL
    WHERE name IN ('Communication', 'Teamwork');  -- Add your default skill names here
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_assign_default_skills
AFTER INSERT ON STUDENT
FOR EACH ROW
EXECUTE FUNCTION assign_default_skills();




CREATE OR REPLACE FUNCTION update_trainer_specialization()
RETURNS TRIGGER AS $$
BEGIN
    -- Concatenate the new course title with the trainer's existing specialization
    UPDATE TRAINER
    SET specialization = 
        COALESCE(specialization || ', ', '') || NEW.title
    WHERE trainer_id = NEW.trainer_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trigger_update_trainer_specialization
AFTER INSERT ON COURSE
FOR EACH ROW
EXECUTE FUNCTION update_trainer_specialization();



--- New View

-- Student course and skill summary
CREATE OR REPLACE VIEW student_course_skill_summary AS
SELECT 
    s.student_id,
    s.name AS student_name,
    COUNT(DISTINCT e.course_id) AS total_courses,
    COUNT(DISTINCT ss.skill_id) AS total_skills,
    ROUND(AVG(ss.proficiency),2) AS avg_skill_score
FROM STUDENT s
LEFT JOIN ENROLLMENT e ON s.student_id = e.student_id
LEFT JOIN STUDENT_SKILL ss ON s.student_id = ss.student_id
GROUP BY s.student_id, s.name;