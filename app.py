from flask import Flask, render_template, request, redirect, url_for, flash, session
import psycopg2
from psycopg2.extras import RealDictCursor

app = Flask(__name__)
app.secret_key = 'your-secret-key'  # Required for flash messages and sessions

def get_db_connection():
    try:
        conn = psycopg2.connect(
            host="localhost",
            database="career_training_system",
            user="postgres",
            password="password"
        )
        return conn
    except Exception as e:
        print(f"Error connecting to database: {e}")
        return None

@app.route('/')
def index():
    return render_template('login.html')

@app.route('/login', methods=['POST'])
def login():
    user_type = request.form.get('userType')
    user_id = request.form.get('userId')
    password = request.form.get('password')
    
    if not all([user_type, user_id, password]):
        flash('Please fill all fields', 'error')
        return redirect(url_for('index'))
    
    if password != 'password':  # Simple password check
        flash('Invalid password', 'error')
        return redirect(url_for('index'))
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                if user_type == 'student':
                    cur.execute("SELECT * FROM student WHERE student_id = %s", (user_id,))
                elif user_type == 'trainer':
                    cur.execute("SELECT * FROM trainer WHERE trainer_id = %s", (user_id,))
                elif user_type == 'company':
                    cur.execute("SELECT * FROM company WHERE company_id = %s", (user_id,))
                else:
                    flash('Invalid user type', 'error')
                    return redirect(url_for('index'))
                
                user = cur.fetchone()
                if user:
                    session['user'] = dict(user)
                    session['user_type'] = user_type
                    return redirect(url_for(f'{user_type}_dashboard'))
                else:
                    flash(f'Invalid {user_type} ID', 'error')
                    return redirect(url_for('index'))
                
        except Exception as e:
            flash(f'Error during login: {str(e)}', 'error')
            return redirect(url_for('index'))
        finally:
            conn.close()
    
    flash('Database connection error', 'error')
    return redirect(url_for('index'))

@app.route('/register', methods=['GET'])
def register():
    return render_template('register.html')

@app.route('/register', methods=['POST'])
def register_submit():
    user_type = request.form.get('userType')
    name = request.form.get('name')
    
    # Additional fields based on user type
    email = request.form.get('email')  # Only for students
    specialization = request.form.get('specialization')  # Only for trainers
    industry = request.form.get('industry')  # Only for companies
    gpa = request.form.get('gpa')  # Only for students
    
    if not user_type or not name:
        flash('Please fill all required fields', 'error')
        return redirect(url_for('register'))
    
    # Validate user type specific fields
    if user_type == 'student' and (not email or not gpa):
        flash('Email and GPA are required for students', 'error')
        return redirect(url_for('register'))
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                if user_type == 'student':
                    # Validate GPA
                    try:
                        gpa_float = float(gpa)
                        if not (0 <= gpa_float <= 4):
                            raise ValueError("GPA must be between 0 and 4")
                    except ValueError as e:
                        flash(str(e), 'error')
                        return redirect(url_for('register'))
                        
                    cur.execute(
                        "INSERT INTO student (name, email, gpa) VALUES (%s, %s, %s) RETURNING student_id",
                        (name, email, gpa)
                    )
                    
                elif user_type == 'trainer':
                    cur.execute(
                        "INSERT INTO trainer (name, specialization) VALUES (%s, %s) RETURNING trainer_id",
                        (name, specialization)
                    )
                    
                elif user_type == 'company':
                    cur.execute(
                        "INSERT INTO company (name, industry) VALUES (%s, %s) RETURNING company_id",
                        (name, industry)
                    )
                    
                else:
                    flash('Invalid user type', 'error')
                    return redirect(url_for('register'))
                
                new_id = cur.fetchone()[f'{user_type}_id']
                conn.commit()
                
                flash(f'Registration successful! Your ID is {new_id}', 'success')
                return redirect(url_for('index'))
                
        except psycopg2.IntegrityError as e:
            conn.rollback()
            if 'email' in str(e):
                flash('Email address already registered', 'error')
            else:
                flash('Registration failed: Duplicate entry', 'error')
            return redirect(url_for('register'))
        except Exception as e:
            conn.rollback()
            flash(f'Error during registration: {str(e)}', 'error')
            return redirect(url_for('register'))
        finally:
            conn.close()
    
    flash('Database connection error', 'error')
    return redirect(url_for('register'))

# Example dashboard routes
"""@app.route('/student-dashboard')
def student_dashboard():
    if 'user' not in session or session['user_type'] != 'student':
        return redirect(url_for('index'))
    return render_template('student_dashboard.html', user=session['user'])
"""

@app.route('/student-dashboard', methods=['GET', 'POST'])
def student_dashboard():
    if 'user' not in session or session['user_type'] != 'student':
        return redirect(url_for('index'))
    
    # Get student data from database
    conn = get_db_connection()
    if conn:
        try:
            # Handle POST request (form submission)
            if request.method == 'POST':
                course_id = request.form.get('course_id')
                student_id = session['user']['student_id']
                
                if not all([course_id]):
                    flash('Please fill all fields', 'error')
                else:
                    with conn.cursor(cursor_factory=RealDictCursor) as cur:
                        # Check if already enrolled
                        cur.execute("""
                            SELECT * FROM enrollment 
                            WHERE student_id = %s AND course_id = %s
                        """, (student_id, course_id))
                        
                        if cur.fetchone():
                            flash('You are already enrolled in this course', 'error')
                        else:
                            # Insert new enrollment
                            try:
                                cur.execute("""
                                    INSERT INTO enrollment (student_id, course_id, status)
                                    VALUES (%s, %s, 'Active')
                                """, (student_id, course_id))
                                conn.commit()
                                flash('Successfully enrolled in the course!', 'success')
                                return redirect(url_for('student_dashboard'))
                            except Exception as e:
                                conn.rollback()
                                flash(f'Enrollment failed: {str(e)}', 'error')

            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Get courses
                cur.execute("""
                    SELECT c.*, e.status, t.name as trainer_name 
                    FROM enrollment e 
                    JOIN course c ON e.course_id = c.course_id 
                    JOIN trainer t ON c.trainer_id = t.trainer_id 
                    WHERE e.student_id = %s
                """, (session['user']['student_id'],))
                courses = cur.fetchall()

                # Get available courses (not enrolled)
                cur.execute("""
                    SELECT c.*, t.name as trainer_name 
                    FROM course c
                    JOIN trainer t ON c.trainer_id = t.trainer_id 
                    WHERE c.course_id NOT IN (
                        SELECT course_id 
                        FROM enrollment 
                        WHERE student_id = %s
                    )
                """, (session['user']['student_id'],))
                available_courses = cur.fetchall()

                # Get job applications
                cur.execute("""
                    SELECT j.*, a.status, c.name as company_name 
                    FROM application a 
                    JOIN job_posting j ON a.job_id = j.job_id 
                    JOIN company c ON j.company_id = c.company_id 
                    WHERE a.student_id = %s
                """, (session['user']['student_id'],))
                applications = cur.fetchall()

                # Get skills
                cur.execute("""
                    SELECT s.name, ss.proficiency 
                    FROM student_skill ss 
                    JOIN skill s ON ss.skill_id = s.skill_id 
                    WHERE ss.student_id = %s
                """, (session['user']['student_id'],))
                skills = cur.fetchall()

                return render_template('student_dashboard.html', 
                                    user=session['user'],
                                    courses=courses,
                                    available_courses=available_courses,
                                    applications=applications,
                                    skills=skills)
        finally:
            conn.close()
    
    flash('Database connection error', 'error')
    return redirect(url_for('index'))

"""
@app.route('/delete_course/<int:course_id>', methods=['POST'])
def delete_course(course_id):
    try:
        # Your course deletion logic here
        flash('Course successfully dropped.', 'success')
    except Exception as e:
        flash('Error dropping course: ' + str(e), 'error')
    return redirect(url_for('student_dashboard'))
"""


@app.route('/drop-course/<int:course_id>', methods=['POST'])
def drop_course(course_id):
    """
    Allow a student to drop a course they're enrolled in.
    Checks for valid enrollment and student authorization before deletion.
    """
    student_id = session['user']['student_id']
    
    conn = get_db_connection()
    if not conn:
        flash('Database connection error', 'error')
        return redirect(url_for('student.dashboard'))
    
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # First verify that the student is actually enrolled in this course
            cur.execute("""
                SELECT status 
                FROM enrollment 
                WHERE student_id = %s AND course_id = %s
            """, (student_id, course_id))
            
            enrollment = cur.fetchone()
            
            if not enrollment:
                flash('You are not enrolled in this course.', 'error')
                return redirect(url_for('student.dashboard'))
            
            # Check if the course can be dropped (you might want to add more conditions)
            # For example, checking if it's past a certain date or if the course has started
            if enrollment['status'] == 'Completed':
                flash('Cannot drop a completed course.', 'error')
                return redirect(url_for('student.dashboard'))
            
            # Proceed with the deletion
            try:
                cur.execute("""
                    DELETE FROM enrollment 
                    WHERE student_id = %s AND course_id = %s
                """, (student_id, course_id))
                
                conn.commit()
                flash('Course successfully dropped.', 'success')
                
            except Exception as e:
                conn.rollback()
                flash(f'Failed to drop course: {str(e)}', 'error')
                
    except Exception as e:
        flash(f'Error processing request: {str(e)}', 'error')
    finally:
        conn.close()
    
    return redirect(url_for('student_dashboard'))


@app.route('/trainer-dashboard')
def trainer_dashboard():
    if 'user' not in session or session['user_type'] != 'trainer':
        return redirect(url_for('index'))
    
    conn = get_db_connection()
    courses = []
    if conn:
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                trainer_id = session['user']['trainer_id']
                cur.execute("""
                    SELECT 
                        c.course_id,
                        c.title, 
                        c.description,
                        COUNT(e.enrollment_id) AS enrollments_count
                    FROM course c
                    LEFT JOIN enrollment e ON c.course_id = e.course_id
                    WHERE c.trainer_id = %s
                    GROUP BY c.course_id
                    ORDER BY c.title;
                """, (trainer_id,))
                courses = cur.fetchall()
        finally:
            conn.close()
    
    return render_template('trainer_dashboard.html', user=session['user'], courses=courses)


@app.route('/add-course', methods=['GET', 'POST'])
def add_course():
    if 'user' not in session or session['user_type'] != 'trainer':
        return redirect(url_for('index'))
    
    conn = get_db_connection()
    if conn:
        try:
            if request.method == 'POST':
                title = request.form.get('title')
                description = request.form.get('description')
                trainer_id = session['user']['trainer_id']

                if not all([title, description]):
                    flash('Please fill in all fields', 'error')
                else:
                    with conn.cursor(cursor_factory=RealDictCursor) as cur:
                        cur.execute("""
                            INSERT INTO course (trainer_id, title, description)
                            VALUES (%s, %s, %s)
                        """, (trainer_id, title, description))
                        conn.commit()
                        flash('Course added successfully!', 'success')
                        return redirect(url_for('trainer_dashboard'))

            return render_template('add_course.html', user=session['user'])
        finally:
            conn.close()
    
    flash('Database connection error', 'error')
    return redirect(url_for('index'))


@app.route('/view-enrollments/<int:course_id>', methods=['GET'])
def view_enrollments(course_id):
    if 'user' not in session or session['user_type'] != 'trainer':
        return redirect(url_for('index'))
    
    conn = get_db_connection()
    enrollments = []
    course = {}
    if conn:
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Fetch course details
                cur.execute("""
                    SELECT title, description 
                    FROM course 
                    WHERE course_id = %s AND trainer_id = %s
                """, (course_id, session['user']['trainer_id']))
                course = cur.fetchone()
                if not course:
                    flash('Course not found or not authorized to view.', 'error')
                    return redirect(url_for('trainer_dashboard'))
                
                # Fetch enrollments for the specific course
                cur.execute("""
                    SELECT 
                        s.student_id, 
                        s.name, 
                        s.email, 
                        e.status 
                    FROM enrollment e
                    JOIN student s ON e.student_id = s.student_id
                    WHERE e.course_id = %s
                    ORDER BY s.name;
                """, (course_id,))
                enrollments = cur.fetchall()
        finally:
            conn.close()
    
    return render_template('view_enrollments.html', user=session['user'], course=course, enrollments=enrollments)



# Add these routes to your Flask application

@app.route('/add-job', methods=['POST'])
def add_job():
    if 'user' not in session or session['user_type'] != 'company':
        return redirect(url_for('index'))
    
    title = request.form.get('title')
    description = request.form.get('description')
    company_id = session['user']['company_id']
    
    if not all([title, description]):
        flash('Please fill in all fields', 'error')
        return redirect(url_for('company_dashboard'))
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    INSERT INTO job_posting (company_id, title, description)
                    VALUES (%s, %s, %s)
                    RETURNING job_id
                """, (company_id, title, description))
                conn.commit()
                flash('Job posting added successfully!', 'success')
        except Exception as e:
            conn.rollback()
            flash(f'Error adding job posting: {str(e)}', 'error')
        finally:
            conn.close()
    
    return redirect(url_for('company_dashboard'))

@app.route('/view-applications/<int:job_id>')
def view_applications(job_id):
    if 'user' not in session or session['user_type'] != 'company':
        return redirect(url_for('index'))
    
    conn = get_db_connection()
    applications = []
    job = None
    if conn:
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Verify the job belongs to this company
                cur.execute("""
                    SELECT * FROM job_posting 
                    WHERE job_id = %s AND company_id = %s
                """, (job_id, session['user']['company_id']))
                job = cur.fetchone()
                
                if not job:
                    flash('Job posting not found or unauthorized access', 'error')
                    return redirect(url_for('company_dashboard'))
                
                # Fetch applications with student details
                cur.execute("""
                    SELECT 
                        a.application_id,
                        a.apply_date,
                        a.status,
                        s.student_id,
                        s.name as student_name,
                        s.email,
                        s.gpa
                    FROM application a
                    JOIN student s ON a.student_id = s.student_id
                    WHERE a.job_id = %s
                    ORDER BY a.apply_date DESC
                """, (job_id,))
                applications = cur.fetchall()
        finally:
            conn.close()
    
    return render_template('view_applications.html', 
                         user=session['user'],
                         job=job,
                         applications=applications)

@app.route('/update-application-status/<int:application_id>', methods=['POST'])
def update_application_status(application_id):
    if 'user' not in session or session['user_type'] != 'company':
        return redirect(url_for('index'))
    
    new_status = request.form.get('status')
    if not new_status:
        flash('Please provide a status', 'error')
        return redirect(request.referrer)
    
    conn = get_db_connection()
    if conn:
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Verify the application belongs to a job posted by this company
                cur.execute("""
                    SELECT j.job_id 
                    FROM application a
                    JOIN job_posting j ON a.job_id = j.job_id
                    WHERE a.application_id = %s AND j.company_id = %s
                """, (application_id, session['user']['company_id']))
                
                if not cur.fetchone():
                    flash('Application not found or unauthorized access', 'error')
                    return redirect(url_for('company_dashboard'))
                
                cur.execute("""
                    UPDATE application 
                    SET status = %s 
                    WHERE application_id = %s
                """, (new_status, application_id))
                conn.commit()
                flash('Application status updated successfully!', 'success')
        except Exception as e:
            conn.rollback()
            flash(f'Error updating application status: {str(e)}', 'error')
        finally:
            conn.close()
    
    return redirect(request.referrer)

# Update the company_dashboard route to include jobs
@app.route('/company-dashboard')
def company_dashboard():
    if 'user' not in session or session['user_type'] != 'company':
        return redirect(url_for('index'))
    
    conn = get_db_connection()
    jobs = []
    if conn:
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT 
                        j.*,
                        COUNT(a.application_id) as application_count
                    FROM job_posting j
                    LEFT JOIN application a ON j.job_id = a.job_id
                    WHERE j.company_id = %s
                    GROUP BY j.job_id
                    ORDER BY j.posting_date DESC
                """, (session['user']['company_id'],))
                jobs = cur.fetchall()
        finally:
            conn.close()
    
    return render_template('company_dashboard.html', 
                         user=session['user'],
                         jobs=jobs)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(debug=True)