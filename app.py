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

@app.route('/delete_course/<int:course_id>', methods=['POST'])
def delete_course(course_id):
    try:
        # Your course deletion logic here
        flash('Course successfully dropped.', 'success')
    except Exception as e:
        flash('Error dropping course: ' + str(e), 'error')
    return redirect(url_for('student_dashboard'))


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
    return render_template('trainer_dashboard.html', user=session['user'])

@app.route('/company-dashboard')
def company_dashboard():
    if 'user' not in session or session['user_type'] != 'company':
        return redirect(url_for('index'))
    return render_template('company_dashboard.html', user=session['user'])

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(debug=True)