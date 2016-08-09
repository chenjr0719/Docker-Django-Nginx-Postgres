#!/bin/bash

SETTING_PATH=`find /home/django/ -name settings.py`

if [ -z "$SETTING_PATH" ] ; then

    # Create django project
    mkdir -p /home/django/website/
    django-admin startproject website /home/django/website

    # Create model_example app
    mkdir -p /home/django/website/model_example/
    django-admin startapp model_example /home/django/website/model_example/
    mv /home/django/admin.py /home/django/website/model_example/
    mv /home/django/models.py /home/django/website/model_example/

    SETTING_PATH=`find /home/django/ -name settings.py`

fi

if [ ! -f /home/django/password.txt ] ; then

    # Start Postgres
    /etc/init.d/postgresql start & sleep 10s

    # Set password
    POSTGRES_DJANGO_PASSWORD=`pwgen -c -n -1 12`
    DJANGO_ADMIN_PASSWORD=`pwgen -c -n -1 12`

    # Output password
    echo -e "POSTGRES_DJANGO_PASSWORD = $POSTGRES_DJANGO_PASSWORD\nDJANGO_ADMIN_PASSWORD = $DJANGO_ADMIN_PASSWORD" > /home/django/password.txt

    # Initialize Postgres
    sed -i "s|password|$POSTGRES_DJANGO_PASSWORD|g" /home/django/init.sql
    su - postgres -c 'psql -f /home/django/init.sql'

    # install Postgres adapter for Python
    pip3 install psycopg2

    # Add model_example app
    sed -i "s|'django.contrib.staticfiles'|'django.contrib.staticfiles',\n    'model_example'|g" $SETTING_PATH

    # Modify database setting to Postgres
    sed -i "s|django.db.backends.sqlite3|django.db.backends.postgresql_psycopg2|g" $SETTING_PATH
    sed -i "s|os.path.join(BASE_DIR, 'db.sqlite3')|'django',\n        'HOST': '127.0.0.1',\n        'USER': 'django',\n        'PASSWORD': '$POSTGRES_DJANGO_PASSWORD'|g" $SETTING_PATH

    # Modify static files setting
    sed -i "s|STATIC_URL = '/static/'|STATIC_URL = '/static/'\n\nSTATIC_ROOT = os.path.join(BASE_DIR, 'static')|g" $SETTING_PATH

    # Django setting
    python3 /home/django/website/manage.py makemigrations
    python3 /home/django/website/manage.py migrate
    echo yes | python3 /home/django/website/manage.py collectstatic
    echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@example.com', '$DJANGO_ADMIN_PASSWORD')" | python3 /home/django/website/manage.py shell

    /etc/init.d/postgresql stop

fi

# Start all the services
/usr/bin/supervisord -n
